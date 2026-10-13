// Bônus de conjunto (GDD Conjuntos), puro. Porte de game/scripts/rules/conjuntos.gd;
// casos em tests/shared/conjuntos.json.

// deno-lint-ignore no-explicit-any
type Dados = Record<string, any>;

/** Efeito dos conjuntos: {atributos, habilidades (ordem alfabética do conjunto), contagem, total}. */
export function efeito(modelos_equipados: string[], itens: Dados): Dados {
  const modelos: Dados = itens["modelos"];
  const cfg: Dados = itens["conjuntos"] ?? {};
  const total: Record<string, number> = {};
  for (const m of Object.keys(modelos)) {
    const c: string = modelos[m]["conjunto"] ?? "";
    if (c !== "") total[c] = (total[c] ?? 0) + 1;
  }
  const contagem: Record<string, number> = {};
  for (const m of modelos_equipados) {
    if (Object.hasOwn(modelos, m)) {
      const c: string = modelos[m]["conjunto"] ?? "";
      if (c !== "") contagem[c] = (contagem[c] ?? 0) + 1;
    }
  }
  const nomes = Object.keys(contagem).sort();
  const atributos: Record<string, number> = {};
  const habilidades: string[] = [];
  for (const c of nomes) {
    if (!Object.hasOwn(cfg, c)) continue;
    const n = contagem[c];
    if (n >= 2) {
      const b: Dados = cfg[c]["bonus_2"] ?? {};
      for (const k of Object.keys(b)) atributos[k] = (atributos[k] ?? 0) + Math.trunc(b[k]);
    }
    if (n >= (total[c] ?? 0) && String(cfg[c]["habilidade"] ?? "") !== "") habilidades.push(String(cfg[c]["habilidade"]));
  }
  return { atributos, habilidades, contagem, total };
}
