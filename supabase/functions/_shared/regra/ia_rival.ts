// IA do rival (pura e determinística). Porte de game/scripts/ai/ia_rival.gd;
// casos em tests/shared/ia_rival.json. Usa o próprio gerador (Aleatorio) com a
// semente derivada da justa, para as decisões da IA não mudarem os sorteios
// da bandeira e do impacto.
// Ordem dos sorteios por passada: largada (2: a qualidade pelo perfil e o
// instante dentro da faixa dela), galope (por batida: perder? 1; se toca,
// desvio 2), mira (4). Variação "triangular": média de dois sorteios
// uniformes, com divisão só de número não negativo.

import { Aleatorio, MASCARA } from "./aleatorio.ts";
import type { Ponto } from "./mira.ts";

// deno-lint-ignore no-explicit-any
type Dados = Record<string, any>;

export const MASCARA_SEMENTE = 0x5DEECE66;

export function validar_perfil(p: Dados): string {
  for (const k of ["largada_perfeita_milesimos", "largada_boa_milesimos", "largada_ruim_atraso_ms", "desvio_medio_ms", "desvio_variacao_ms",
    "perder_batida_milesimos", "acelera", "metade_batidas", "zona_preferida", "erro_mira_px",
    "deslocamento_mira_px", "habilidade_batida"]) {
    if (!(k in p)) return `falta "${k}"`;
  }
  if (p["acelera"] !== "cedo" && p["acelera"] !== "tarde") return '"acelera" deve ser cedo ou tarde';
  return "";
}

export function validar(cfg: Dados): string {
  if (typeof cfg["perfis"] !== "object" || cfg["perfis"] === null || Object.keys(cfg["perfis"]).length === 0) return 'falta "perfis"';
  if (typeof cfg["ajuste_campeao"] !== "object" || cfg["ajuste_campeao"] === null) return 'falta "ajuste_campeao"';
  for (const nome of Object.keys(cfg["perfis"])) {
    const erro = validar_perfil(cfg["perfis"][nome]);
    if (erro !== "") return `perfil ${nome}: ${erro}`;
  }
  return "";
}

/** Semente da IA a partir da semente da justa. */
export function semente_da_justa(semente: number): number {
  return ((semente ^ MASCARA_SEMENTE) & MASCARA) >>> 0;
}

/** Centro do primeiro retângulo da zona, em décimos de px. */
export function centro_da_zona(cfg_mira: Dados, zona: string): Ponto {
  for (const z of cfg_mira["zonas"]) {
    if (z["nome"] === zona) {
      const r = z["retangulos"][0];
      return { x: Math.trunc(r[0]) * 10 + Math.trunc(r[2]) * 5, y: Math.trunc(r[1]) * 10 + Math.trunc(r[3]) * 5 };
    }
  }
  return { x: 0, y: 0 };
}

export class IaRival {
  perfil: Dados;
  private _rng: Aleatorio;

  constructor(p: Dados, semente: number) {
    this.perfil = p;
    this._rng = new Aleatorio(semente);
  }

  /** Variação em [-v, v], média de dois sorteios (mais perto do centro). */
  private _variacao(v: number): number {
    if (v <= 0) return 0;
    const soma = this._rng.inteiro(0, 2 * v) + this._rng.inteiro(0, 2 * v);
    return Math.trunc(soma / 2) - v;
  }

  /** Reação à bandeira em ms: qualidade sorteada pelo perfil e instante dentro da faixa dela (`cfg_largada` = galope.json > largada). */
  reacao_largada_ms(cfg_largada: Dados): number {
    const perfeita_ms = Math.trunc(cfg_largada["perfeita_ms"]);
    const boa_ms = Math.trunc(cfg_largada["boa_ms"]);
    const q = this._rng.inteiro(0, 999);
    const p = Math.trunc(this.perfil["largada_perfeita_milesimos"]);
    if (q < p) return this._rng.inteiro(0, perfeita_ms);
    if (q < p + Math.trunc(this.perfil["largada_boa_milesimos"])) return this._rng.inteiro(perfeita_ms + 1, boa_ms);
    return this._rng.inteiro(boa_ms + 1, boa_ms + Math.max(Math.trunc(this.perfil["largada_ruim_atraso_ms"]), 1));
  }

  /** Instantes (ms desde o começo da Corrida, crescentes, >= 1) em que o rival toca, até `duracao_max_ms`. */
  plano_galope(compasso_ms: number, duracao_max_ms: number): number[] {
    const plano: number[] = [];
    const batidas = Math.trunc(duracao_max_ms / compasso_ms);
    const metade = Math.trunc(this.perfil["metade_batidas"]);
    const cedo = this.perfil["acelera"] === "cedo";
    for (let k = 1; k <= batidas; k++) {
      const acelerando = cedo ? k <= metade : k > metade;
      if (!acelerando && k % 2 === 1) continue; // no ritmo de cruzeiro, toca uma batida sim, outra não
      if (this._rng.chance_milesimos(Math.trunc(this.perfil["perder_batida_milesimos"]))) continue;
      const t = k * compasso_ms + Math.trunc(this.perfil["desvio_medio_ms"]) + this._variacao(Math.trunc(this.perfil["desvio_variacao_ms"]));
      if (t >= 1 && (plano.length === 0 || t > plano[plano.length - 1])) plano.push(t);
    }
    return plano;
  }

  /** Ponto da mira (décimos de px do quadro do alvo): centro da zona preferida + deslocamento + erro. */
  ponto_mira(cfg_mira: Dados): Ponto {
    const desl: number[] = this.perfil["deslocamento_mira_px"];
    const c = centro_da_zona(cfg_mira, this.perfil["zona_preferida"]);
    const centro = { x: c.x + Math.trunc(desl[0]) * 10, y: c.y + Math.trunc(desl[1]) * 10 };
    const erro = Math.trunc(this.perfil["erro_mira_px"]) * 10;
    const dx = this._variacao(erro);
    const dy = this._variacao(erro);
    return { x: centro.x + dx, y: centro.y + dy };
  }

  /** Batida da Corrida em que aciona a habilidade ativa (0 = nunca). */
  batida_habilidade(): number {
    return Math.trunc(this.perfil["habilidade_batida"]);
  }

  /** Primeira passada em que tenta acionar a ativa (opcional, padrão 1). */
  passada_habilidade(): number {
    return Math.max(Math.trunc(this.perfil["habilidade_passada"] ?? 1), 1);
  }
}
