// Ligas e PvP assíncrono (GDD PvP, ligas e temporadas), puro. Porte de
// game/scripts/rules/liga.gd; casos em tests/shared/liga.json.

import { div } from "./util.ts";

// deno-lint-ignore no-explicit-any
type Dados = Record<string, any>;

export interface Pecas {
  raridade?: string;
  nivel?: number;
}

/** Poder do cavaleiro: média dos atributos / 2 + poder das peças (raridade + nível). */
export function poder(atributos: number[], pecas: Pecas[], eco: Dados): number {
  let soma = 0;
  for (const a of atributos) soma += Math.trunc(a);
  let p = div(div(soma, Math.max(atributos.length, 1)), 2);
  for (const pc of pecas) {
    p += Math.trunc(eco["poder_raridade"][pc.raridade ?? "comum"] ?? 0) + Math.trunc(pc.nivel ?? 0) * Math.trunc(eco["poder_por_melhoria"]);
  }
  return p;
}

/** Liga e divisão pelos pontos: {liga, nome, divisao, pontos_na_divisao, para_subir (-1 no topo)}. */
export function posicao(pontos: number, cfg: Dados): Dados {
  const por_div = Math.trunc(cfg["pontos_por_divisao"]);
  const divs: string[] = cfg["divisoes"];
  const nomes: string[] = cfg["nomes"];
  const p = Math.max(pontos, 0);
  const total_div = Math.min(div(p, por_div), nomes.length * divs.length - 1);
  const liga = div(total_div, divs.length);
  const d = total_div % divs.length;
  const topo = total_div === nomes.length * divs.length - 1;
  return {
    liga, nome: nomes[liga], divisao: divs[d], pontos_na_divisao: p - total_div * por_div,
    para_subir: topo ? -1 : (total_div + 1) * por_div - p,
  };
}

/** Pontos depois de uma partida do atacante (nunca abaixo de zero). */
export function depois_da_partida(pontos: number, venceu: boolean, cfg: Dados): number {
  return Math.max(0, pontos + Math.trunc(venceu ? cfg["vitoria"] : cfg["derrota"]));
}

/** Pontos do defensor quando a defesa vence (perder a defesa não tira pontos). */
export function depois_da_defesa(pontos: number, defendeu: boolean, cfg: Dados): number {
  return pontos + (defendeu ? Math.trunc(cfg["defesa_vencida"]) : 0);
}

export interface Candidato {
  id: string;
  pontos: number;
  poder: number;
}

/** Pareamento: o candidato na faixa de poder e mais perto em pontos; empate pelo id. "" se nenhum. */
export function parear(pontos: number, poder_jogador: number, candidatos: Candidato[], cfg: Dados): string {
  const faixa = Math.trunc(cfg["faixa_poder"]);
  let melhor = "";
  let dist = -1;
  for (const c of candidatos) {
    if (Math.abs(Math.trunc(c.poder) - poder_jogador) > faixa) continue;
    const d = Math.abs(Math.trunc(c.pontos) - pontos);
    if (dist < 0 || d < dist || (d === dist && String(c.id) < melhor)) {
      melhor = String(c.id);
      dist = d;
    }
  }
  return melhor;
}

/** Fim da temporada: reinício parcial dos pontos. */
export function reinicio(pontos: number, cfg: Dados): number {
  return div(pontos * Math.trunc(cfg["reinicio_pct"]), 100);
}

/** Ouro de uma vitória de PvP na liga `liga` (índice). */
export function ouro_vitoria(liga: number, cfg: Dados): number {
  return Math.trunc(cfg["ouro_vitoria"]) + liga * Math.trunc(cfg["ouro_por_liga"]);
}
