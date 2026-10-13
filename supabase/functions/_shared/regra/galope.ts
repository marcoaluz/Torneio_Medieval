// Largada e galope de um cavaleiro. Porte de game/scripts/rules/galope.gd;
// casos em tests/shared/galope.json. Distância em milésimos, tempo em ms.

import { clampi, div, tem } from "./util.ts";

// deno-lint-ignore no-explicit-any
type Cfg = Record<string, any>;

export const QUALIDADES = ["perfeita", "boa", "ruim"];

export interface ResultadoToque {
  resultado: string;
  batida: number;
  desvio_ms: number;
}

export class Galope {
  automatico = false;
  velocidade = 0;
  velocidade_nominal = 0;
  distancia_mil = 0;
  folego = 0;
  folego_max = 0;
  janela_ms = 0;
  t_ms = 0;
  acertos = 0;
  compassos = 0;

  private _c: Cfg;
  private _usadas = new Set<number>();

  static validar(cfg: Cfg): string {
    const exigidas: Record<string, string[]> = {
      largada: ["bandeira_ms", "bandeira_variacao_ms", "perfeita_ms", "boa_ms", "velocidade_inicial_pct", "bonus_precisao_pct"],
      pista: ["distancia_total", "distancia_mira"],
      galope: ["compasso_ms", "janela_base_ms", "janela_por_temperamento_milesimos", "janela_max_ms",
        "velocidade_base", "velocidade_por_ponto_milesimos", "velocidade_min_pct", "velocidade_max_pct",
        "ganho_pct", "perda_perdido_pct", "perda_sem_folego_pct", "velocidade_max_cansado_pct"],
      folego: ["base", "por_ponto_milesimos", "custo_por_passada", "custo_erro"],
    };
    for (const grupo of Object.keys(exigidas)) {
      const g = cfg[grupo];
      if (typeof g !== "object" || g === null || Array.isArray(g)) return `falta o grupo "${grupo}"`;
      for (const chave of exigidas[grupo]) {
        if (!(chave in g)) return `falta "${grupo}.${chave}"`;
      }
    }
    for (const q of QUALIDADES) {
      if (!tem(cfg["largada"]["velocidade_inicial_pct"], q) || !tem(cfg["largada"]["bonus_precisao_pct"], q)) {
        return `falta a qualidade "${q}" na largada`;
      }
    }
    if (cfg["galope"]["janela_max_ms"] * 2 >= cfg["galope"]["compasso_ms"]) return "janela_max_ms precisa ser menor que metade do compasso";
    if (cfg["pista"]["distancia_mira"] >= cfg["pista"]["distancia_total"]) return "distancia_mira precisa ser menor que distancia_total";
    return "";
  }

  /** Qualidade da largada pela reação em ms (negativa = queimada; tocou false = não tocou). */
  static avaliar_largada(cfg: Cfg, tocou: boolean, reacao_ms: number): string {
    if (!tocou || reacao_ms < 0) return "ruim";
    if (reacao_ms <= cfg["largada"]["perfeita_ms"]) return "perfeita";
    if (reacao_ms <= cfg["largada"]["boa_ms"]) return "boa";
    return "ruim";
  }

  /** `cavalo`: {velocidade, folego, temperamento} (0 a 100). */
  constructor(cfg: Cfg, cavalo: Cfg) {
    this._c = cfg;
    const g = cfg["galope"];
    this.velocidade_nominal = Math.trunc(g["velocidade_base"]) +
      div(Math.trunc(cavalo["velocidade"]) * Math.trunc(g["velocidade_por_ponto_milesimos"]), 1000);
    this.janela_ms = Math.min(
      Math.trunc(g["janela_base_ms"]) + div(Math.trunc(cavalo["temperamento"]) * Math.trunc(g["janela_por_temperamento_milesimos"]), 1000),
      Math.trunc(g["janela_max_ms"]));
    const f = cfg["folego"];
    this.folego_max = Math.trunc(f["base"]) + div(Math.trunc(cavalo["folego"]) * Math.trunc(f["por_ponto_milesimos"]), 1000);
    this.folego = this.folego_max;
    this.velocidade = this.velocidade_nominal;
  }

  compasso_ms(): number {
    return Math.trunc(this._c["galope"]["compasso_ms"]);
  }

  /** Começo da Corrida de uma passada: zera a distância e as batidas, aplica a largada e cobra o fôlego. */
  nova_passada(qualidade_largada: string): void {
    this.distancia_mil = 0;
    this.t_ms = 0;
    this.acertos = 0;
    this.compassos = 0;
    this._usadas.clear();
    this.folego = Math.max(this.folego - Math.trunc(this._c["folego"]["custo_por_passada"]), 0);
    if (this.automatico) {
      this.velocidade = this.velocidade_nominal;
    } else {
      this.velocidade = this._limitar(div(this.velocidade_nominal * Math.trunc(this._c["largada"]["velocidade_inicial_pct"][qualidade_largada]), 100));
    }
  }

  ritmo_milesimos(): number {
    return this.compassos === 0 ? 0 : div(this.acertos * 1000, this.compassos);
  }

  /** Toque no instante atual (t_ms). */
  tocar(): ResultadoToque {
    const p = this.compasso_ms();
    const k = div(this.t_ms + div(p, 2), p);
    const desvio = this.t_ms - k * p;
    let resultado: string;
    if (k >= 1 && this._usadas.has(k)) {
      resultado = "rapido_demais";
    } else if (k >= 1 && Math.abs(desvio) <= this.janela_ms) {
      resultado = "no_tempo";
      this._usadas.add(k);
      this.acertos += 1;
      this.compassos += 1;
      this._mudar_velocidade(Math.trunc(this._c["galope"]["ganho_pct"]));
    } else {
      resultado = "fora_do_tempo";
    }
    if (resultado !== "no_tempo") this._errar();
    return { resultado, batida: k, desvio_ms: desvio };
  }

  /** Avança 1 ms da Corrida. Devolve o evento de batida perdida, se houver. */
  avancar_1ms(): ResultadoToque | null {
    this.t_ms += 1;
    this.distancia_mil += this.velocidade;
    if (this.automatico) return null;
    const p = this.compasso_ms();
    // A janela da batida k vai até k*p + janela, inclusive; perdida no ms seguinte.
    const fim_janela = this.t_ms - this.janela_ms - 1;
    if (fim_janela >= p && fim_janela % p === 0) {
      const k = div(fim_janela, p);
      if (!this._usadas.has(k)) {
        this.compassos += 1;
        this._mudar_velocidade(-Math.trunc(this._c["galope"]["perda_perdido_pct"]));
        return { resultado: "perdido", batida: k, desvio_ms: 0 };
      }
    }
    return null;
  }

  private _errar(): void {
    if (this.folego > 0) {
      this.folego = Math.max(this.folego - Math.trunc(this._c["folego"]["custo_erro"]), 0);
    } else {
      this._mudar_velocidade(-Math.trunc(this._c["galope"]["perda_sem_folego_pct"]));
    }
  }

  /** Divisão só com números não negativos; o sinal é aplicado depois. */
  private _mudar_velocidade(pct: number): void {
    const delta = div(this.velocidade_nominal * Math.abs(pct), 100);
    this.velocidade = this._limitar(this.velocidade + (pct >= 0 ? delta : -delta));
  }

  private _limitar(v: number): number {
    const g = this._c["galope"];
    const teto_pct = this.folego > 0 ? Math.trunc(g["velocidade_max_pct"]) : Math.trunc(g["velocidade_max_cansado_pct"]);
    const minimo = div(this.velocidade_nominal * Math.trunc(g["velocidade_min_pct"]), 100);
    const maximo = div(this.velocidade_nominal * teto_pct, 100);
    return clampi(v, minimo, maximo);
  }
}
