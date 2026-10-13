// Abertura de baú (GDD Baús e itens), pura e determinística. Porte de
// game/scripts/rules/bau.gd; casos em tests/shared/baus.json.
//
// Ordem dos sorteios: 1. ouro; 2. fragmentos; 3. para cada item: raridade
// pelos pesos (ordem fixa ORDEM), depois o modelo entre os da raridade em
// ordem alfabética. Garantia de raro a cada N baús que contam.

import { Aleatorio } from "./aleatorio.ts";

// deno-lint-ignore no-explicit-any
type Dados = Record<string, any>;

export const ORDEM = ["comum", "incomum", "raro", "epico", "lendario"];

export interface ItemDoBau {
  modelo: string;
  raridade: string;
  repetida: boolean;
}

export interface ResultadoBau {
  ouro: number;
  fragmentos: number;
  itens: ItemDoBau[];
  garantia: number;
}

export function abrir(tipo: string, cfg: Dados, modelos: Dados, possui: string[], garantia: number, semente: number): ResultadoBau {
  const rng = new Aleatorio(semente);
  const b = cfg["tipos"][tipo];
  const ouro = rng.inteiro(Math.trunc(b["ouro"][0]), Math.trunc(b["ouro"][1]));
  let fragmentos = rng.inteiro(Math.trunc(b["fragmentos"][0]), Math.trunc(b["fragmentos"][1]));
  const conta = (cfg["garantia_conta"] as string[]).includes(tipo);
  if (conta) garantia += 1;
  const ja = [...possui];
  const itens: ItemDoBau[] = [];
  for (let i = 0; i < Math.trunc(b["itens"]); i++) {
    let rar = _sortear_raridade(b["raridade"], rng);
    if (ORDEM.indexOf(rar) >= 2) {
      garantia = 0;
    } else if (conta && garantia >= Math.trunc(cfg["garantia_raro_a_cada"])) {
      rar = "raro";
      garantia = 0;
    }
    const pool = modelos_da_raridade(modelos, rar);
    const modelo = pool[rng.inteiro(0, pool.length - 1)];
    const repetida = ja.includes(modelo);
    if (repetida) {
      fragmentos += Math.trunc(cfg["fragmentos_por_repetida"]);
    } else {
      ja.push(modelo);
    }
    itens.push({ modelo, raridade: rar, repetida });
  }
  return { ouro, fragmentos, itens, garantia };
}

/** Modelos de uma raridade em ordem alfabética; sem nenhum, desce de raridade. */
export function modelos_da_raridade(modelos: Dados, raridade: string): string[] {
  let r = ORDEM.indexOf(raridade);
  while (r >= 0) {
    const pool: string[] = [];
    for (const m of Object.keys(modelos)) {
      if (modelos[m]["raridade"] === ORDEM[r]) pool.push(m);
    }
    if (pool.length > 0) {
      pool.sort();
      return pool;
    }
    r -= 1;
  }
  return [];
}

/** Chance de cada raridade em % com uma casa (para a tela de probabilidades). */
export function probabilidades(tipo: string, cfg: Dados): Record<string, number> {
  const pesos: Dados = cfg["tipos"][tipo]["raridade"];
  let total = 0;
  for (const r of ORDEM) total += Math.trunc(pesos[r] ?? 0);
  const res: Record<string, number> = {};
  for (const r of ORDEM) {
    if (Math.trunc(pesos[r] ?? 0) > 0) res[r] = Math.round((100.0 * Math.trunc(pesos[r]) / total) * 10) / 10;
  }
  return res;
}

function _sortear_raridade(pesos: Dados, rng: Aleatorio): string {
  let total = 0;
  for (const r of ORDEM) total += Math.trunc(pesos[r] ?? 0);
  let x = rng.inteiro(0, total - 1);
  for (const r of ORDEM) {
    x -= Math.trunc(pesos[r] ?? 0);
    if (x < 0) return r;
  }
  return ORDEM[0];
}
