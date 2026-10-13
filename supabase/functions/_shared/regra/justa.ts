// A justa inteira como regra pura. Porte de game/scripts/rules/justa.gd;
// referências em tests/shared/justa_referencia.json (sem IA) e
// justa_referencia_ia.json (com IA). Junta as fases, a largada e o galope dos
// dois lados, a mira, o impacto e os sorteios. O servidor refaz a justa com a
// mesma semente e as mesmas entradas nos mesmos instantes e confere o
// resultado antes de entregar qualquer recompensa.
//
// Ordem num mesmo ms: bandeira, rival, jogador. Eventos (todos com "t"):
// bandeira, largada, toque, corrida_fim, soltou, golpe, habilidade,
// largada_rival, toque_rival, impacto (além dos de JustaFases).

import { Galope } from "./galope.ts";
import { Fase, JustaFases, Lado } from "./justa_fases.ts";
import type { Evento } from "./justa_fases.ts";
import { Aleatorio } from "./aleatorio.ts";
import * as Impacto from "./impacto.ts";
import * as Mira from "./mira.ts";
import type { Ponto } from "./mira.ts";
import { IaRival, semente_da_justa } from "./ia_rival.ts";
import { copiar, tem } from "./util.ts";

// deno-lint-ignore no-explicit-any
type Dados = Record<string, any>;

/** Lado afetado: o jogador, o rival, os dois ou nenhum. */
function _lado_de(jogador_afetado: boolean, rival_afetado: boolean): number {
  if (jogador_afetado && rival_afetado) return Lado.AMBOS;
  if (jogador_afetado) return Lado.JOGADOR;
  if (rival_afetado) return Lado.RIVAL;
  return Lado.NENHUM;
}

/** Habilidades do lado (lista "habilidades", ou a antiga "habilidade"). */
function _habilidades_de(lado: Dados): string[] {
  const res: string[] = [];
  if (Array.isArray(lado["habilidades"])) {
    for (const h of lado["habilidades"]) {
      if (typeof h === "string" && h !== "") res.push(h);
    }
  } else if (typeof lado["habilidade"] === "string" && lado["habilidade"] !== "") {
    res.push(lado["habilidade"]);
  }
  return res;
}

/** Tira o dano da durabilidade das peças (nunca abaixo de 0). */
function _gastar(lado: Dados, dano: Dados): void {
  const equip = lado["equipamento"];
  if (typeof equip !== "object" || equip === null) return;
  for (const peca of Object.keys(dano).sort()) {
    if (tem(equip, peca)) {
      const p = equip[peca];
      p["durabilidade"] = Math.max(Math.trunc(p["durabilidade"] ?? 0) - Math.trunc(dano[peca]), 0);
    }
  }
}

export function validar(cfg: Dados): string {
  for (const nome of ["justa", "galope", "mira", "impacto"]) {
    if (typeof cfg[nome] !== "object" || cfg[nome] === null) return `falta a configuração "${nome}"`;
  }
  let erro = JustaFases.validar(cfg["justa"]);
  if (erro !== "") return "justa.json: " + erro;
  erro = Galope.validar(cfg["galope"]);
  if (erro !== "") return "galope.json: " + erro;
  erro = Mira.validar(cfg["mira"]);
  if (erro !== "") return "mira.json: " + erro;
  erro = Impacto.validar(cfg["impacto"]);
  if (erro !== "") return "impacto.json: " + erro;
  const l = cfg["galope"]["largada"];
  if (Math.trunc(l["bandeira_ms"]) + Math.trunc(l["bandeira_variacao_ms"]) >= Math.trunc(cfg["justa"]["fases_ms"]["largada"])) {
    return "a bandeira precisa baixar antes do fim da Largada";
  }
  return "";
}

export class Justa {
  fases: JustaFases;
  jogador: Galope;
  rival: Galope;
  bandeira_ms = 0;
  bandeira_baixou = false;
  qualidade_largada = "";
  tocou_largada = false;
  reacao_largada_ms = 0;
  ponta: Ponto = { x: 0, y: 0 };
  segurando = false;
  solto = false;
  t_soltou_ms = 0;
  precisao_jogador = 0;
  precisao_rival = 0;
  ponta_rival: Ponto = { x: 0, y: 0 };
  rival_mirou = false;
  lado_jogador: Dados;
  lado_rival: Dados;
  faltas_jogador = 0;
  faltas_rival = 0;
  habilidade_usada_jogador = false;
  habilidade_usada_rival = false;
  habilidade_na_passada_jogador = false;
  habilidade_na_passada_rival = false;
  ultimo_impacto: Dados = {};
  qualidade_largada_rival = "";
  ia: IaRival | null = null;
  ia_jogador: IaRival | null = null;

  private _rival_largada_ms = -1;
  private _rival_largou = false;
  private _plano_rival: number[] = [];
  private _plano_ix = 0;
  private _jog_largada_ms = -1;
  private _plano_jogador: number[] = [];
  private _plano_jog_ix = 0;
  private _cfg: Dados;
  private _rng: Aleatorio;

  /** cfg: {justa, galope, mira, impacto}. perfil_ia / perfil_ia_jogador: {} = sem IA. */
  constructor(cfg: Dados, lado_j: Dados, lado_r: Dados, semente: number, perfil_ia: Dados = {}, perfil_ia_jogador: Dados = {}) {
    this._cfg = cfg;
    this.lado_jogador = copiar(lado_j);
    this.lado_rival = copiar(lado_r);
    this.fases = new JustaFases(cfg["justa"]);
    this.jogador = new Galope(cfg["galope"], this.lado_jogador["cavalo"]);
    this.rival = new Galope(cfg["galope"], this.lado_rival["cavalo"]);
    this.rival.automatico = Object.keys(perfil_ia).length === 0;
    if (Object.keys(perfil_ia).length > 0) {
      this.ia = new IaRival(perfil_ia, semente_da_justa(semente));
    }
    if (Object.keys(perfil_ia_jogador).length > 0) {
      this.ia_jogador = new IaRival(perfil_ia_jogador, semente_da_justa(semente ^ 0x2545F491));
    }
    this._rng = new Aleatorio(semente);
    this.precisao_jogador = Impacto.precisao_efetiva(this.lado_jogador);
    this.precisao_rival = Impacto.precisao_efetiva(this.lado_rival);
  }

  iniciar(): Evento[] {
    return this._observar(this.fases.iniciar());
  }

  terminou(): boolean {
    return this.fases.terminou();
  }

  /** Distância (milésimos) em que a Corrida acaba. */
  distancia_corrida_mil(): number {
    const p = this._cfg["galope"]["pista"];
    return (Math.trunc(p["distancia_total"]) - Math.trunc(p["distancia_mira"])) * 1000;
  }

  /** Bônus de precisão (%) desta passada, pela largada. */
  bonus_precisao_pct(): number {
    if (this.qualidade_largada === "") return 0;
    return Math.trunc(this._cfg["galope"]["largada"]["bonus_precisao_pct"][this.qualidade_largada]);
  }

  habilidade_carregada(do_jogador: boolean): boolean {
    return (do_jogador ? this.jogador : this.rival).t_ms >= Math.trunc(this._cfg["impacto"]["habilidade_carga_ms"]);
  }

  /** Liga a habilidade ativa do jogador nesta passada (só na Corrida, uma vez por justa). */
  ativar_habilidade(): Evento[] {
    if (this.fases.fase !== Fase.CORRIDA || this.habilidade_usada_jogador || !this.habilidade_carregada(true)) return [];
    const nome = this._ativa_de(this.lado_jogador);
    if (nome === "") return [];
    this.habilidade_usada_jogador = true;
    this.habilidade_na_passada_jogador = true;
    return [{ tipo: "habilidade", passada: this.fases.passada, lado: "jogador", nome, t: this.fases.tempo_total_ms }];
  }

  /** O mesmo para o rival (chamado pela IA). */
  rival_ativar_habilidade(): Evento[] {
    if (this.fases.fase !== Fase.CORRIDA || this.habilidade_usada_rival || !this.habilidade_carregada(false)) return [];
    const nome = this._ativa_de(this.lado_rival);
    if (nome === "") return [];
    this.habilidade_usada_rival = true;
    this.habilidade_na_passada_rival = true;
    return [{ tipo: "habilidade", passada: this.fases.passada, lado: "rival", nome, t: this.fases.tempo_total_ms }];
  }

  /** Golpe do rival (IA): ponto no quadro do jogador. Só na Mira; o último antes do choque vale. */
  rival_mirar(ponto: Ponto): void {
    if (this.fases.fase !== Fase.MIRA) return;
    this.ponta_rival = Mira.limitar(this._cfg["mira"], ponto);
    this.rival_mirou = true;
  }

  /** Equipamento de um lado depois do desgaste desta justa. */
  equipamento_final(do_jogador: boolean): Dados {
    return copiar((do_jogador ? this.lado_jogador : this.lado_rival)["equipamento"] ?? {});
  }

  /** A habilidade ativa (botão) do lado; "" se não tem. */
  private _ativa_de(lado: Dados): string {
    for (const h of _habilidades_de(lado)) {
      if (tem(this._cfg["impacto"]["habilidades"], h) && this._cfg["impacto"]["habilidades"][h]["tipo"] === "ativa") return h;
    }
    return "";
  }

  avancar(ms: number): Evento[] {
    const eventos: Evento[] = [];
    while (ms > 0 && !this.fases.terminou()) {
      if (this.fases.fase === Fase.CORRIDA) {
        ms -= 1;
        eventos.push(...this._corrida_1ms());
      } else if (this.fases.fase === Fase.LARGADA) {
        const ate_fase = this.fases.duracao_ms(this.fases.fase) - this.fases.tempo_na_fase_ms;
        let passo = Math.min(ms, ate_fase);
        if (!this.bandeira_baixou) passo = Math.min(passo, this.bandeira_ms - this.fases.tempo_na_fase_ms);
        if (!this._rival_largou && this._rival_largada_ms >= 0) passo = Math.min(passo, this._rival_largada_ms - this.fases.tempo_na_fase_ms);
        if (this.ia_jogador && !this.tocou_largada && this._jog_largada_ms >= 0) passo = Math.min(passo, this._jog_largada_ms - this.fases.tempo_na_fase_ms);
        if (passo > 0) {
          ms -= passo;
          eventos.push(...this._observar(this.fases.avancar(passo)));
        }
        if (this.fases.fase === Fase.LARGADA) {
          if (!this.bandeira_baixou && this.fases.tempo_na_fase_ms >= this.bandeira_ms) {
            this.bandeira_baixou = true;
            eventos.push({ tipo: "bandeira", passada: this.fases.passada, t: this.fases.tempo_total_ms });
          }
          if (!this._rival_largou && this._rival_largada_ms >= 0 && this.fases.tempo_na_fase_ms >= this._rival_largada_ms) {
            eventos.push(this._rival_larga());
          }
          if (this.ia_jogador && !this.tocou_largada && this._jog_largada_ms >= 0 && this.fases.tempo_na_fase_ms >= this._jog_largada_ms) {
            eventos.push(...this.tocar());
          }
        }
      } else {
        const ate_fase = this.fases.duracao_ms(this.fases.fase) - this.fases.tempo_na_fase_ms;
        const passo = Math.min(ms, ate_fase);
        ms -= passo;
        eventos.push(...this._observar(this.fases.avancar(passo)));
      }
    }
    return eventos;
  }

  /** Toque do jogador no instante atual. */
  tocar(): Evento[] {
    const eventos: Evento[] = [];
    switch (this.fases.fase) {
      case Fase.APRESENTACAO:
        eventos.push(...this._observar(this.fases.pular()));
        break;
      case Fase.LARGADA:
        if (!this.tocou_largada) {
          this.tocou_largada = true;
          this.reacao_largada_ms = this.fases.tempo_na_fase_ms - this.bandeira_ms;
          this.qualidade_largada = Galope.avaliar_largada(this._cfg["galope"], true, this.reacao_largada_ms);
          eventos.push(this._evento_largada());
        }
        break;
      case Fase.CORRIDA: {
        const r = this.jogador.tocar();
        eventos.push(this._evento_toque(r, this.jogador));
        break;
      }
    }
    return eventos;
  }

  /** Segura e move a ponta da lança (décimos de px do quadro do rival). Só na Mira e antes de soltar. */
  mirar(ponto: Ponto): void {
    if (this.fases.fase !== Fase.MIRA || this.solto) return;
    this.ponta = Mira.limitar(this._cfg["mira"], ponto);
    this.segurando = true;
  }

  /** Solta o dedo: trava o golpe no ponto atual. Só na Mira, segurando. */
  soltar(): Evento[] {
    if (this.fases.fase !== Fase.MIRA || this.solto || !this.segurando) return [];
    this.solto = true;
    this.segurando = false;
    this.t_soltou_ms = this.fases.tempo_na_fase_ms;
    return [{ tipo: "soltou", passada: this.fases.passada, x: this.ponta.x, y: this.ponta.y, t_mira_ms: this.t_soltou_ms, t: this.fases.tempo_total_ms }];
  }

  private _corrida_1ms(): Evento[] {
    const eventos: Evento[] = [];
    if (this.ia) {
      // Toques da IA no instante planejado (mesma regra do toque do jogador).
      while (this._plano_ix < this._plano_rival.length && this._plano_rival[this._plano_ix] <= this.rival.t_ms) {
        if (this._plano_rival[this._plano_ix] === this.rival.t_ms) {
          const r = this.rival.tocar();
          const ev = this._evento_toque(r, this.rival);
          ev["tipo"] = "toque_rival";
          eventos.push(ev);
        }
        this._plano_ix += 1;
      }
      const hb = this.ia.batida_habilidade();
      if (hb > 0 && this.rival.t_ms === hb * this.rival.compasso_ms()) eventos.push(...this.rival_ativar_habilidade());
    }
    if (this.ia_jogador) {
      while (this._plano_jog_ix < this._plano_jogador.length && this._plano_jogador[this._plano_jog_ix] <= this.jogador.t_ms) {
        if (this._plano_jogador[this._plano_jog_ix] === this.jogador.t_ms) eventos.push(...this.tocar());
        this._plano_jog_ix += 1;
      }
      const hbj = this.ia_jogador.batida_habilidade();
      if (hbj > 0 && this.jogador.t_ms === hbj * this.jogador.compasso_ms()) eventos.push(...this.ativar_habilidade());
    }
    const perdido = this.jogador.avancar_1ms();
    const perdido_rival = this.rival.avancar_1ms();
    if (perdido) eventos.push(this._evento_toque(perdido, this.jogador));
    if (perdido_rival) {
      const ev = this._evento_toque(perdido_rival, this.rival);
      ev["tipo"] = "toque_rival";
      eventos.push(ev);
    }
    // Primeiro o relógio (pode bater o teto); depois a chegada.
    eventos.push(...this._observar(this.fases.avancar(1)));
    if (this.fases.fase === Fase.CORRIDA && this.jogador.distancia_mil + this.rival.distancia_mil >= this.distancia_corrida_mil()) {
      eventos.push(...this._observar(this.fases.encerrar_corrida()));
    }
    return eventos;
  }

  /** Reage às trocas de fase da regra (largada, galope, mira, choque). */
  private _observar(eventos: Evento[]): Evento[] {
    const saida: Evento[] = [];
    for (const e of eventos) {
      if (e["tipo"] === "fase" && e["anterior"] === Fase.CORRIDA) {
        saida.push({
          tipo: "corrida_fim", passada: this.fases.passada,
          velocidade_jogador: this.jogador.velocidade, velocidade_rival: this.rival.velocidade,
          ritmo_jogador_milesimos: this.jogador.ritmo_milesimos(),
          distancia_jogador_mil: this.jogador.distancia_mil, distancia_rival_mil: this.rival.distancia_mil,
          t: e["t"],
        });
      }
      if (e["tipo"] === "fase" && e["anterior"] === Fase.MIRA) {
        const golpe = this._avaliar_golpe(e["t"]);
        saida.push(golpe);
        saida.push(this._resolver_impacto(golpe, e["t"]));
      }
      saida.push(e);
      if (e["tipo"] !== "fase") continue;
      switch (e["fase"]) {
        case Fase.APRESENTACAO:
          this.habilidade_na_passada_jogador = false;
          this.habilidade_na_passada_rival = false;
          break;
        case Fase.LARGADA: {
          const l = this._cfg["galope"]["largada"];
          this.bandeira_ms = Math.trunc(l["bandeira_ms"]) + this._rng.inteiro(0, Math.trunc(l["bandeira_variacao_ms"]));
          this.bandeira_baixou = false;
          this.tocou_largada = false;
          this.qualidade_largada = "";
          this.reacao_largada_ms = 0;
          this._rival_largou = false;
          this.qualidade_largada_rival = "";
          this._rival_largada_ms = -1;
          if (this.ia) {
            // Reação antes da bandeira = toque antes dela (queimada); nunca antes do 0.
            const tr = Math.max(this.bandeira_ms + this.ia.reacao_largada_ms(), 0);
            if (tr < this.fases.duracao_ms(Fase.LARGADA)) this._rival_largada_ms = tr;
          }
          this._jog_largada_ms = -1;
          if (this.ia_jogador) {
            const tj = Math.max(this.bandeira_ms + this.ia_jogador.reacao_largada_ms(), 0);
            if (tj < this.fases.duracao_ms(Fase.LARGADA)) this._jog_largada_ms = tj;
          }
          break;
        }
        case Fase.CORRIDA:
          if (!this.tocou_largada) {
            this.qualidade_largada = Galope.avaliar_largada(this._cfg["galope"], false, 0);
            saida.push(this._evento_largada());
          }
          this.jogador.nova_passada(this.qualidade_largada);
          if (this.ia) {
            if (!this._rival_largou) {
              this.qualidade_largada_rival = Galope.avaliar_largada(this._cfg["galope"], false, 0);
              saida.push({ tipo: "largada_rival", passada: this.fases.passada, qualidade: this.qualidade_largada_rival, reacao_ms: 0, t: this.fases.tempo_total_ms });
              this._rival_largou = true;
            }
            this.rival.nova_passada(this.qualidade_largada_rival);
            this._plano_rival = this.ia.plano_galope(this.rival.compasso_ms(), this.fases.duracao_ms(Fase.CORRIDA));
            this._plano_ix = 0;
          } else {
            this.rival.nova_passada("boa");
          }
          if (this.ia_jogador) {
            this._plano_jogador = this.ia_jogador.plano_galope(this.jogador.compasso_ms(), this.fases.duracao_ms(Fase.CORRIDA));
            this._plano_jog_ix = 0;
          }
          break;
        case Fase.MIRA:
          this.ponta = Mira.ponta_inicial(this._cfg["mira"]);
          this.segurando = false;
          this.solto = false;
          this.t_soltou_ms = 0;
          this.rival_mirou = false;
          this.precisao_jogador = Impacto.precisao_efetiva(this.lado_jogador);
          this.precisao_rival = Impacto.precisao_efetiva(this.lado_rival);
          if (this.ia) this.rival_mirar(this.ia.ponto_mira(this._cfg["mira"]));
          if (this.ia_jogador) {
            this.mirar(this.ia_jogador.ponto_mira(this._cfg["mira"]));
            saida.push(...this.soltar());
          }
          break;
      }
    }
    return saida;
  }

  private _avaliar_golpe(t: number): Evento {
    const sem_golpe = !this.solto && !this.segurando;
    const automatico = !this.solto && this.segurando;
    const zona = sem_golpe ? Mira.ERRO : Mira.zona_no_ponto(this._cfg["mira"], this.ponta, this.precisao_jogador, this.bonus_precisao_pct());
    const t_mira = this.solto ? this.t_soltou_ms : this.fases.duracao_ms(Fase.MIRA);
    this.solto = true;
    this.segurando = false;
    return { tipo: "golpe", passada: this.fases.passada, zona, x: this.ponta.x, y: this.ponta.y, t_mira_ms: t_mira, automatico, sem_golpe, t };
  }

  /** Resolve o choque com a regra do impacto, conta faltas, gasta o equipamento e registra o resultado da passada. */
  private _resolver_impacto(golpe: Evento, t: number): Evento {
    let zona_rival = Mira.ERRO;
    if (this.rival_mirou) {
      let bonus_rival = 0;
      if (this.qualidade_largada_rival !== "") {
        bonus_rival = Math.trunc(this._cfg["galope"]["largada"]["bonus_precisao_pct"][this.qualidade_largada_rival]);
      }
      zona_rival = Mira.zona_no_ponto(this._cfg["mira"], this.ponta_rival, this.precisao_rival, bonus_rival);
    }
    const entrada = {
      jogador: this._golpeador(this.lado_jogador, golpe["zona"], this.jogador, this.habilidade_na_passada_jogador),
      rival: this._golpeador(this.lado_rival, zona_rival, this.rival, this.habilidade_na_passada_rival),
    };
    const res = Impacto.resolver(this._cfg["impacto"], entrada, this._rng);
    this.ultimo_impacto = res;
    const rj = res["jogador"];
    const rr = res["rival"];
    if (rj["falta"]) this.faltas_jogador += 1;
    if (rr["falta"]) this.faltas_rival += 1;
    // O golpe do jogador gasta as peças do rival, e vice-versa; cada lança gasta no contato.
    _gastar(this.lado_rival, rj["dano"]);
    _gastar(this.lado_jogador, rr["dano"]);
    _gastar(this.lado_jogador, { lanca: rj["dano_lanca"] });
    _gastar(this.lado_rival, { lanca: rr["dano_lanca"] });
    const limite = Math.trunc(this._cfg["impacto"]["falta"]["faltas_para_desclassificar"]);
    const dq = _lado_de(this.faltas_jogador >= limite, this.faltas_rival >= limite);
    const derrubado = _lado_de(rr["derrubou"], rj["derrubou"]);
    this.fases.registrar_resultado(Math.trunc(rj["pontos"]), Math.trunc(rr["pontos"]), derrubado, dq);
    return {
      tipo: "impacto", passada: this.fases.passada, jogador: rj, rival: rr,
      faltas_jogador: this.faltas_jogador, faltas_rival: this.faltas_rival,
      derrubado, desclassificado: dq, t,
    };
  }

  /** Passivas valem em toda passada; a ativa, só na passada em que foi acionada. */
  private _golpeador(lado: Dados, zona: string, g: Galope, ativa_na_passada: boolean): Dados {
    const habs: Dados[] = [];
    for (const nome of _habilidades_de(lado)) {
      let em_efeito = false;
      if (tem(this._cfg["impacto"]["habilidades"], nome)) {
        em_efeito = this._cfg["impacto"]["habilidades"][nome]["tipo"] === "passiva" || ativa_na_passada;
      }
      habs.push({ nome, ativa: em_efeito });
    }
    return {
      cavaleiro: lado["cavaleiro"], equipamento: lado["equipamento"] ?? {}, habilidades: habs, zona,
      velocidade: g.velocidade, velocidade_nominal: g.velocidade_nominal, ritmo_milesimos: g.ritmo_milesimos(),
    };
  }

  private _rival_larga(): Evento {
    this._rival_largou = true;
    const reacao = this._rival_largada_ms - this.bandeira_ms;
    this.qualidade_largada_rival = Galope.avaliar_largada(this._cfg["galope"], true, reacao);
    return { tipo: "largada_rival", passada: this.fases.passada, qualidade: this.qualidade_largada_rival, reacao_ms: reacao, t: this.fases.tempo_total_ms };
  }

  private _evento_largada(): Evento {
    return {
      tipo: "largada", passada: this.fases.passada, qualidade: this.qualidade_largada,
      tocou: this.tocou_largada, reacao_ms: this.reacao_largada_ms,
      queimada: this.tocou_largada && this.reacao_largada_ms < 0, t: this.fases.tempo_total_ms,
    };
  }

  private _evento_toque(r: { resultado: string; batida: number; desvio_ms: number }, g: Galope): Evento {
    return {
      tipo: "toque", passada: this.fases.passada, resultado: r.resultado, batida: r.batida,
      desvio_ms: r.desvio_ms, velocidade: g.velocidade, folego: g.folego, t: this.fases.tempo_total_ms,
    };
  }
}
