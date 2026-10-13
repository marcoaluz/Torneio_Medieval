// Sequência de fases de uma justa. Porte de game/scripts/rules/justa_fases.gd;
// casos em tests/shared/justa_fases.json.
// Uma passada: Apresentação → Largada → Corrida → Mira → Impacto. Tempo em
// milissegundos inteiros passado de fora; cada chamada devolve os eventos.

export const Fase = { APRESENTACAO: 0, LARGADA: 1, CORRIDA: 2, MIRA: 3, IMPACTO: 4, FIM: 5 } as const;
export const Lado = { NENHUM: 0, JOGADOR: 1, RIVAL: 2, AMBOS: 3 } as const;

export const NOMES_FASE = ["apresentacao", "largada", "corrida", "mira", "impacto", "fim"];
export const NOMES_LADO = ["nenhum", "jogador", "rival", "ambos"];

// deno-lint-ignore no-explicit-any
export type Evento = Record<string, any>;

function inteiro_valido(v: unknown, minimo: number): boolean {
  if (typeof v !== "number") return false;
  return v === Math.floor(v) && v >= minimo;
}

export class JustaFases {
  fase: number = Fase.FIM;
  passada = 0;
  tempo_total_ms = 0;
  tempo_na_fase_ms = 0;
  placar_jogador = 0;
  placar_rival = 0;
  vencedor: number = Lado.NENHUM;
  /** "pontos", "derrubada", "desclassificacao" ou "empate"; vazio enquanto não termina. */
  motivo = "";

  private _passadas = 0;
  private _extras_max = 0;
  private _duracao_ms: number[] = [];
  private _pontos_passada_jogador = 0;
  private _pontos_passada_rival = 0;
  private _derrubado: number = Lado.NENHUM;
  private _desclassificado: number = Lado.NENHUM;

  /** "" se a configuração está completa, senão a descrição do problema. */
  // deno-lint-ignore no-explicit-any
  static validar(config: Record<string, any>): string {
    for (const chave of ["passadas", "passadas_extras_max", "fases_ms"]) {
      if (!(chave in config)) return `falta "${chave}"`;
    }
    if (!inteiro_valido(config["passadas"], 1)) return '"passadas" deve ser inteiro >= 1';
    if (!inteiro_valido(config["passadas_extras_max"], 0)) return '"passadas_extras_max" deve ser inteiro >= 0';
    const fases = config["fases_ms"];
    if (typeof fases !== "object" || fases === null || Array.isArray(fases)) return '"fases_ms" deve ser objeto';
    for (let i = 0; i < Fase.FIM; i++) {
      const nome = NOMES_FASE[i];
      if (!(nome in fases)) return `falta "fases_ms.${nome}"`;
      if (!inteiro_valido(fases[nome], 1)) return `"fases_ms.${nome}" deve ser inteiro >= 1`;
    }
    return "";
  }

  // deno-lint-ignore no-explicit-any
  constructor(config: Record<string, any>) {
    this._passadas = Math.trunc(config["passadas"]);
    this._extras_max = Math.trunc(config["passadas_extras_max"]);
    for (let i = 0; i < Fase.FIM; i++) this._duracao_ms.push(Math.trunc(config["fases_ms"][NOMES_FASE[i]]));
  }

  total_passadas(): number {
    return this._passadas;
  }

  duracao_ms(f: number): number {
    return f < Fase.FIM ? this._duracao_ms[f] : 0;
  }

  /** Começa a justa na Apresentação da primeira passada. */
  iniciar(): Evento[] {
    this.passada = 0;
    this.tempo_total_ms = 0;
    this.placar_jogador = 0;
    this.placar_rival = 0;
    this.vencedor = Lado.NENHUM;
    this.motivo = "";
    const eventos: Evento[] = [];
    this._nova_passada(eventos);
    return eventos;
  }

  terminou(): boolean {
    return this.fase === Fase.FIM;
  }

  /** Avança o relógio da justa em `ms` (>= 0), atravessando quantas fases couberem. */
  avancar(ms: number): Evento[] {
    const eventos: Evento[] = [];
    while (ms > 0 && this.fase !== Fase.FIM) {
      const restante = this._duracao_ms[this.fase] - this.tempo_na_fase_ms;
      if (ms < restante) {
        this.tempo_na_fase_ms += ms;
        this.tempo_total_ms += ms;
        break;
      }
      ms -= restante;
      this.tempo_total_ms += restante;
      this._fim_da_fase(eventos);
    }
    return eventos;
  }

  /** Pula a Apresentação. Fora dela, não faz nada. */
  pular(): Evento[] {
    const eventos: Evento[] = [];
    if (this.fase === Fase.APRESENTACAO) this._fim_da_fase(eventos);
    return eventos;
  }

  /** Termina a Corrida antes do teto de tempo. Fora da Corrida, não faz nada. */
  encerrar_corrida(): Evento[] {
    const eventos: Evento[] = [];
    if (this.fase === Fase.CORRIDA) this._fim_da_fase(eventos);
    return eventos;
  }

  /** Resultado da passada atual; só vale na Mira ou no Impacto. */
  registrar_resultado(pontos_jogador: number, pontos_rival: number, derrubado: number = Lado.NENHUM,
    desclassificado: number = Lado.NENHUM): boolean {
    if (this.fase !== Fase.MIRA && this.fase !== Fase.IMPACTO) return false;
    this._pontos_passada_jogador = pontos_jogador;
    this._pontos_passada_rival = pontos_rival;
    this._derrubado = derrubado;
    this._desclassificado = desclassificado;
    return true;
  }

  private _nova_passada(eventos: Evento[]): void {
    this.passada += 1;
    this._pontos_passada_jogador = 0;
    this._pontos_passada_rival = 0;
    this._derrubado = Lado.NENHUM;
    this._desclassificado = Lado.NENHUM;
    this._entrar(Fase.APRESENTACAO, eventos);
  }

  private _entrar(nova: number, eventos: Evento[]): void {
    const anterior = this.fase;
    this.fase = nova;
    this.tempo_na_fase_ms = 0;
    eventos.push({ tipo: "fase", fase: nova, anterior, passada: this.passada, t: this.tempo_total_ms });
  }

  private _fim_da_fase(eventos: Evento[]): void {
    if (this.fase !== Fase.IMPACTO) {
      this._entrar(this.fase + 1, eventos);
      return;
    }
    this.placar_jogador += this._pontos_passada_jogador;
    this.placar_rival += this._pontos_passada_rival;
    eventos.push({
      tipo: "passada", passada: this.passada,
      pontos_jogador: this._pontos_passada_jogador, pontos_rival: this._pontos_passada_rival,
      derrubado: this._derrubado, desclassificado: this._desclassificado, t: this.tempo_total_ms,
    });
    if (this._desclassificado === Lado.AMBOS) {
      this._encerrar(Lado.NENHUM, "desclassificacao", eventos);
    } else if (this._desclassificado === Lado.JOGADOR) {
      this._encerrar(Lado.RIVAL, "desclassificacao", eventos);
    } else if (this._desclassificado === Lado.RIVAL) {
      this._encerrar(Lado.JOGADOR, "desclassificacao", eventos);
    } else if (this._derrubado === Lado.RIVAL) {
      this._encerrar(Lado.JOGADOR, "derrubada", eventos);
    } else if (this._derrubado === Lado.JOGADOR) {
      this._encerrar(Lado.RIVAL, "derrubada", eventos);
    } else if (this.passada >= this._passadas && this.placar_jogador !== this.placar_rival) {
      this._encerrar(this.placar_jogador > this.placar_rival ? Lado.JOGADOR : Lado.RIVAL, "pontos", eventos);
    } else if (this.passada >= this._passadas + this._extras_max) {
      this._encerrar(Lado.NENHUM, "empate", eventos);
    } else {
      this._nova_passada(eventos);
    }
  }

  private _encerrar(quem: number, por: string, eventos: Evento[]): void {
    this.vencedor = quem;
    this.motivo = por;
    this._entrar(Fase.FIM, eventos);
    eventos.push({
      tipo: "fim", vencedor: quem, motivo: por,
      placar_jogador: this.placar_jogador, placar_rival: this.placar_rival, t: this.tempo_total_ms,
    });
  }
}
