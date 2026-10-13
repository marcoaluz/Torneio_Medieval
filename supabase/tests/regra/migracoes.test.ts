// Guarda estática das migrações (3.1/3.11): sem execução em banco, confere as
// regras da skill supabase-jogo no próprio SQL — toda tabela com RLS, toda
// função privilegiada com search_path vazio e sem acesso do app.

import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";

const PASTA = new URL("../../migrations/", import.meta.url);
const arquivos = readdirSync(PASTA).filter((a) => a.endsWith(".sql")).sort();
const sql = arquivos.map((a) => readFileSync(new URL(a, PASTA), "utf-8")).join("\n");

/** Remove comentários de linha para não confundir as buscas. */
const limpo = sql.split("\n").map((l) => l.replace(/--.*$/, "")).join("\n");

describe("migrações", () => {
  test("toda tabela criada tem RLS ligada", () => {
    const tabelas = [...limpo.matchAll(/create table (?:if not exists )?public\.(\w+)/g)].map((m) => m[1]);
    assert.ok(tabelas.length >= 20, `achou ${tabelas.length} tabelas`);
    for (const t of tabelas) {
      assert.match(limpo, new RegExp(`alter table public\\.${t} enable row level security`), `tabela ${t} sem RLS`);
    }
  });

  test("toda função security definer fixa o search_path vazio", () => {
    const funcoes = [...limpo.matchAll(/create or replace function public\.(\w+)\(([\s\S]*?)\$\$;?\s*(?=\n[a-z]|\n\n|$)/g)];
    for (const m of limpo.matchAll(/create or replace function public\.(\w+)[\s\S]*?\n\$\$;/g)) {
      const corpo = m[0];
      if (/security definer/.test(corpo)) {
        assert.match(corpo, /set search_path = ''/, `função ${m[1]} sem search_path vazio`);
      }
    }
    assert.ok(funcoes.length >= 0);
  });

  test("função privilegiada não fica aberta para anon nem authenticated (exceto a das políticas)", () => {
    const nomes = [...limpo.matchAll(/create or replace function public\.(\w+)[\s\S]*?\n\$\$;/g)]
      .filter((m) => /security definer/.test(m[0]) && !/returns trigger/.test(m[0]))
      .map((m) => m[1]);
    assert.ok(nomes.length >= 8, `achou ${nomes.length} funções privilegiadas`);
    for (const n of nomes) {
      const revoga = new RegExp(`revoke all on function public\\.${n}\\([^)]*\\) from [^;]*\\banon\\b`);
      assert.match(limpo, revoga, `função ${n} não revoga o acesso do anon`);
    }
    // A única que o app executa (usada nas políticas de RLS) é a de pertencimento à ordem.
    const concedidas = [...limpo.matchAll(/grant execute on function public\.(\w+)/g)].map((m) => m[1]);
    assert.deepEqual(concedidas, ["sou_da_ordem"]);
  });

  test("views do painel não são acessíveis pelo app", () => {
    const views = [...limpo.matchAll(/create or replace view public\.(\w+)/g)].map((m) => m[1]);
    assert.ok(views.length >= 5);
    for (const v of views) {
      assert.match(limpo, new RegExp(`revoke all on [^;]*public\\.${v}\\b[^;]* from public, anon, authenticated`), `view ${v} aberta`);
    }
  });

  test("o cliente não escreve em economia, ranking, compras nem partidas", () => {
    // Políticas de escrita (insert/update/delete) só nas tabelas do próprio jogador.
    const permitidas = new Set(["jogador", "save_jogador", "evento_metrica", "dispositivo_push", "bloqueio", "denuncia", "amigo"]);
    for (const m of limpo.matchAll(/create policy "[^"]+" on public\.(\w+)\s+for (insert|update|delete)/g)) {
      assert.ok(permitidas.has(m[1]), `política de escrita do cliente em ${m[1]} (${m[2]})`);
    }
  });
});
