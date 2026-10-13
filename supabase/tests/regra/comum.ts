// Auxiliares dos testes da regra em TypeScript (Node 24 roda .ts direto):
// leitura dos casos compartilhados de tests/shared/ e formatação dos eventos
// no mesmo formato das gravações do GDScript.

import { readFileSync } from "node:fs";

// deno-lint-ignore no-explicit-any
export type Dados = Record<string, any>;

const RAIZ = new URL("../../../", import.meta.url);

/** Lê tests/shared/<nome>.json (o mesmo arquivo que os testes do GDScript). */
export function carregar_casos(nome: string): Dados {
  return JSON.parse(readFileSync(new URL(`tests/shared/${nome}.json`, RAIZ), "utf-8"));
}

/** Lê um JSON de balanceamento do jogo (game/data/...). */
export function carregar_dados(caminho: string): Dados {
  return JSON.parse(readFileSync(new URL(`game/data/${caminho}`, RAIZ), "utf-8"));
}

/** Texto de um valor no formato do str() do GDScript (usado nas gravações da justa). */
export function texto_godot(v: unknown): string {
  if (typeof v === "string") return v;
  if (typeof v === "boolean") return v ? "true" : "false";
  if (typeof v === "number") return Number.isInteger(v) ? String(v) : String(v);
  if (Array.isArray(v)) return "[" + v.map(item_godot).join(", ") + "]";
  if (typeof v === "object" && v !== null) {
    const chaves = Object.keys(v);
    if (chaves.length === 0) return "{  }";
    return "{ " + chaves.map((k) => `${JSON.stringify(k)}: ${item_godot((v as Dados)[k])}`).join(", ") + " }";
  }
  return String(v);
}

/** Valor dentro de um array ou dicionário: texto entre aspas. */
function item_godot(v: unknown): string {
  if (typeof v === "string") return JSON.stringify(v);
  return texto_godot(v);
}

/** "tipo|chave=valor|..." com as chaves em ordem alfabética (como as gravações do GDScript). */
export function evento_para_texto(e: Dados): string {
  const partes = [String(e["tipo"])];
  for (const k of Object.keys(e).sort()) {
    if (k !== "tipo") partes.push(`${k}=${texto_godot(e[k])}`);
  }
  return partes.join("|");
}

/** JSON com chaves ordenadas e inteiros iguais a floats (para comparar resultados). */
export function normalizar(v: unknown): string {
  return JSON.stringify(ordenar(v));
}

function ordenar(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(ordenar);
  if (typeof v === "object" && v !== null) {
    const r: Dados = {};
    for (const k of Object.keys(v).sort()) r[k] = ordenar((v as Dados)[k]);
    return r;
  }
  return v;
}
