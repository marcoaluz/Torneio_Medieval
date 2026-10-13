// Paridade do servidor com o ServicoJogador do GDScript (3.2): reexecuta os
// cenários gravados por tools/gravar_cenarios.gd passo a passo e confere o
// resultado e o que mudou no estado (dif) de cada comando.
// Se falhar, a economia do servidor divergiu da do jogo: não publicar.

import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { TODOS } from "../../functions/_shared/servidor/comandos.ts";
import { entregar_compra } from "../../functions/_shared/servidor/jogador.ts";
import type { Servico } from "../../functions/_shared/servidor/base.ts";
import { carregar_casos, normalizar } from "./comum.ts";
import type { Dados } from "./comum.ts";

const RAIZ = new URL("../../../", import.meta.url);
const ARQUIVOS: Record<string, string> = {
  historia: "game/data/historia/historia.json",
  nomes_proibidos: "game/data/texto/nomes_proibidos.json",
  acessibilidade: "game/data/ui/acessibilidade.json",
};
const cache: Record<string, Dados> = {};

/** Dados de balanceamento dos arquivos do jogo (na produção vêm da tabela `balanceamento`). */
function bal(nome: string): Dados {
  if (!(nome in cache)) {
    const caminho = ARQUIVOS[nome] ?? `game/data/balance/${nome}.json`;
    cache[nome] = JSON.parse(readFileSync(new URL(caminho, RAIZ), "utf-8"));
  }
  return cache[nome];
}

/** Troca "@tipo:N" pelo id do N-ésimo (igual ao gravador do GDScript). */
function resolver(v: unknown, estado: Dados): unknown {
  if (typeof v === "string" && v.startsWith("@")) {
    const p = v.slice(1).split(":");
    switch (p[0]) {
      case "timer": return estado["timers"][Number(p[1])]["id"];
      case "bau": return estado["baus"]["espacos"][Number(p[1])]["id"];
      case "item": return estado["inventario"]["itens"][Number(p[1])]["id"];
      case "cavalo": return estado["cavalos"][Number(p[1])]["id"];
      case "missao": return estado["metas"][p[1]][Number(p[2])]["id"];
    }
    return v;
  }
  if (Array.isArray(v)) return v.map((x) => resolver(x, estado));
  if (typeof v === "object" && v !== null) {
    const r: Dados = {};
    for (const k of Object.keys(v)) r[k] = resolver((v as Dados)[k], estado);
    return r;
  }
  return v;
}

function definir(d: Dados, caminho: string[], valor: unknown): void {
  let atual: Dados = d;
  for (let i = 0; i < caminho.length - 1; i++) {
    const k = caminho[i];
    if (!(k in atual)) atual[k] = {};
    atual = atual[k];
  }
  atual[caminho[caminho.length - 1]] = valor;
}

/** Diferenças entre dois valores (mesmo algoritmo do gravador do GDScript). */
// deno-lint-ignore no-explicit-any
function dif(a: any, b: any, caminho: (string | number)[], saida: Dados[]): void {
  const dic = (v: unknown) => typeof v === "object" && v !== null && !Array.isArray(v);
  if (dic(a) && dic(b)) {
    const chaves = Object.keys(a);
    for (const k of Object.keys(b)) if (!chaves.includes(k)) chaves.push(k);
    chaves.sort();
    for (const k of chaves) {
      const c = [...caminho, k];
      if (!(k in b)) saida.push({ c, r: true });
      else if (!(k in a)) saida.push({ c, v: b[k] });
      else dif(a[k], b[k], c, saida);
    }
  } else if (Array.isArray(a) && Array.isArray(b) && a.length === b.length) {
    for (let i = 0; i < a.length; i++) dif(a[i], b[i], [...caminho, i], saida);
  } else if (JSON.stringify(a) !== JSON.stringify(b)) {
    saida.push({ c: caminho, v: b });
  }
}

const dados = carregar_casos("cenarios_servico");

describe("cenários do servidor = ServicoJogador do GDScript", () => {
  for (const cenario of dados["cenarios"]) {
    test(cenario["nome"], () => {
      const estado: Dados = structuredClone(cenario["estado_inicial"]);
      let agora = cenario["criado_em"];
      const s: Servico = { estado, bal, agora: () => agora };
      let anterior: Dados = structuredClone(estado);
      cenario["passos"].forEach((p: Dados, i: number) => {
        agora = cenario["criado_em"] + Math.trunc(p["t"]);
        const rotulo = `passo ${i} (t=${p["t"]}) ${p["cmd"] ?? "set"} ${JSON.stringify(p["args"] ?? p["set"]).slice(0, 80)}`;
        let resultado: unknown = {};
        if (p["set"]) {
          for (const k of Object.keys(p["set"])) definir(estado, k.split(".").map((x: string) => x), structuredClone(p["set"][k]));
        } else {
          const args = resolver(p["args"] ?? [], estado) as unknown[];
          // "comprar" do GDScript (produto pago pelo provedor de teste) = entregar_compra do servidor.
          // "disputa_automatica" do GDScript recebe a semente; no servidor público ela é do servidor.
          const fn = p["cmd"] === "comprar" ? (sv: Servico, prod: string) => entregar_compra(sv, prod, true)
            : p["cmd"] === "disputa_automatica" ? TODOS["disputa_automatica_com_semente"] : TODOS[p["cmd"]];
          assert.ok(fn, `comando desconhecido: ${p["cmd"]}`);
          resultado = (fn as (s: Servico, ...a: unknown[]) => unknown)(s, ...args);
          // Comandos que no GDScript não devolvem nada (marcar_oferta_vista) não têm resultado a comparar.
          if (p["resultado"] !== null) assert.equal(normalizar(resultado), normalizar(p["resultado"]), `resultado: ${rotulo}`);
        }
        const atual: Dados = JSON.parse(JSON.stringify(estado));
        const d: Dados[] = [];
        dif(anterior, atual, [], d);
        assert.equal(normalizar(d), normalizar(p["dif"]), `estado: ${rotulo}`);
        anterior = atual;
      });
    });
  }
});
