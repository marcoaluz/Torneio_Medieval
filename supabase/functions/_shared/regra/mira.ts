// Zonas do alvo e avaliação do ponto da lança. Porte de game/scripts/rules/mira.gd;
// casos em tests/shared/mira.json. Coordenadas em décimos de px do quadro do alvo.

import { suave } from "./impacto.ts";
import { clampi, div } from "./util.ts";

// deno-lint-ignore no-explicit-any
type Cfg = Record<string, any>;

export const ERRO = "erro";

export interface Ponto {
  x: number;
  y: number;
}

/** Retângulo no estilo Rect2i: posição e tamanho; `end` = posição + tamanho. */
export interface Ret {
  px: number;
  py: number;
  sx: number;
  sy: number;
}

export function validar(cfg: Cfg): string {
  for (const chave of ["zonas", "precisao", "ponta_inicial", "limites_ponta", "oscilacao"]) {
    if (!(chave in cfg)) return `falta "${chave}"`;
  }
  if (!Array.isArray(cfg["zonas"]) || cfg["zonas"].length === 0) return '"zonas" deve ser lista não vazia';
  for (const z of cfg["zonas"]) {
    if (typeof z !== "object" || z === null || !("nome" in z) || !("retangulos" in z) || !("cresce" in z)) {
      return "zona sem nome, retangulos ou cresce";
    }
    for (const r of z["retangulos"]) {
      if (!Array.isArray(r) || r.length !== 4) return `retângulo da zona ${z["nome"]} deve ter 4 números`;
    }
  }
  for (const chave of ["crescimento_por_ponto_milesimos", "crescimento_max_pct"]) {
    if (!(chave in cfg["precisao"])) return `falta "precisao.${chave}"`;
  }
  return "";
}

/** Crescimento das zonas em % (Precisão e bônus somados, com teto suave). */
export function crescimento_pct(cfg: Cfg, precisao: number, bonus_pct: number): number {
  const p = cfg["precisao"];
  const g = div(Math.max(precisao, 0) * Math.trunc(p["crescimento_por_ponto_milesimos"]), 1000) + Math.max(bonus_pct, 0);
  return suave(g, Math.trunc(p["crescimento_max_pct"]), Math.trunc(p["joelho_pct"] ?? 100));
}

/** Retângulos efetivos (décimos de px) por zona, na ordem de prioridade. */
export function zonas_efetivas(cfg: Cfg, precisao: number, bonus_pct: number): { nome: string; retangulos: Ret[] }[] {
  const g = crescimento_pct(cfg, precisao, bonus_pct);
  const saida: { nome: string; retangulos: Ret[] }[] = [];
  for (const z of cfg["zonas"]) {
    const rets: Ret[] = [];
    for (const r of z["retangulos"]) {
      let ret: Ret = { px: Math.trunc(r[0]) * 10, py: Math.trunc(r[1]) * 10, sx: Math.trunc(r[2]) * 10, sy: Math.trunc(r[3]) * 10 };
      if (z["cresce"]) {
        // Cresce g% em cada eixo, metade para cada lado (inteiros não negativos).
        const gx = div(ret.sx * g, 200);
        const gy = div(ret.sy * g, 200);
        ret = { px: ret.px - gx, py: ret.py - gy, sx: ret.sx + gx + gx, sy: ret.sy + gy + gy };
      }
      rets.push(ret);
    }
    saida.push({ nome: z["nome"], retangulos: rets });
  }
  return saida;
}

/** Zona atingida pelo ponto (décimos de px): nome da zona ou "erro". Borda inclusiva. */
export function zona_no_ponto(cfg: Cfg, ponto: Ponto, precisao: number, bonus_pct: number): string {
  for (const z of zonas_efetivas(cfg, precisao, bonus_pct)) {
    for (const ret of z.retangulos) {
      if (ponto.x >= ret.px && ponto.x <= ret.px + ret.sx && ponto.y >= ret.py && ponto.y <= ret.py + ret.sy) {
        return z.nome;
      }
    }
  }
  return ERRO;
}

export function ponta_inicial(cfg: Cfg): Ponto {
  return { x: Math.trunc(cfg["ponta_inicial"][0]) * 10, y: Math.trunc(cfg["ponta_inicial"][1]) * 10 };
}

/** Prende o ponto dentro dos limites da mira (décimos de px). */
export function limitar(cfg: Cfg, ponto: Ponto): Ponto {
  const l = cfg["limites_ponta"];
  const x0 = Math.trunc(l[0]) * 10;
  const y0 = Math.trunc(l[1]) * 10;
  return { x: clampi(ponto.x, x0, x0 + Math.trunc(l[2]) * 10), y: clampi(ponto.y, y0, y0 + Math.trunc(l[3]) * 10) };
}
