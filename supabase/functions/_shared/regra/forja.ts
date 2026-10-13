// Forja (GDD Forja: criar e melhorar), pura e determinística. Porte de
// game/scripts/rules/forja.gd; casos em tests/shared/forja.json.
// Divisões inteiras truncam em direção ao zero (Math.trunc).

import { Aleatorio } from "./aleatorio.ts";

// deno-lint-ignore no-explicit-any
type Dados = Record<string, any>;

function _div(a: number, b: number): number {
  return Math.trunc(a / b);
}

/** Peça criada: cada status (em ordem alfabética das chaves) varia inteiro(-pct, pct) por cento. */
export function variar_status(status: Dados, pct: number, semente: number): Record<string, number> {
  const rng = new Aleatorio(semente);
  const chaves = Object.keys(status).sort();
  const res: Record<string, number> = {};
  for (const k of chaves) {
    const v = Math.trunc(status[k]);
    if (v === 0) {
      res[k] = 0;
      continue;
    }
    const d = rng.inteiro(-pct, pct);
    res[k] = Math.max(0, v + _div(v * d, 100));
  }
  return res;
}

/** Status com o nível de melhoria: v + v * nivel * pct / 100. */
export function status_com_nivel(status: Dados, nivel: number, pct: number): Record<string, number> {
  const res: Record<string, number> = {};
  for (const k of Object.keys(status)) {
    const v = Math.trunc(status[k]);
    res[k] = v + _div(v * nivel * pct, 100);
  }
  return res;
}

/** Tentativa de melhoria do nível `nivel` para o seguinte (chance_sucesso_pct[nivel], 100 = garantido). Um sorteio. */
export function melhoria_deu_certo(nivel: number, cfg_melhoria: Dados, semente: number): boolean {
  const chance = Math.trunc(cfg_melhoria["chance_sucesso_pct"][nivel]);
  return new Aleatorio(semente).chance_milesimos(chance * 10);
}
