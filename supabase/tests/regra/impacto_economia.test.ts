// Casos compartilhados: impacto, conjuntos, forja, baús, ligas, desafios do
// PvE e ordens. Mesmos arquivos de tests/shared/ que os testes do GDScript.

import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { Aleatorio } from "../../functions/_shared/regra/aleatorio.ts";
import * as Impacto from "../../functions/_shared/regra/impacto.ts";
import * as Conjuntos from "../../functions/_shared/regra/conjuntos.ts";
import * as Forja from "../../functions/_shared/regra/forja.ts";
import * as Bau from "../../functions/_shared/regra/bau.ts";
import * as Liga from "../../functions/_shared/regra/liga.ts";
import * as Pve from "../../functions/_shared/regra/pve.ts";
import * as Ordem from "../../functions/_shared/regra/ordem.ts";
import { carregar_casos, carregar_dados, normalizar } from "./comum.ts";

describe("impacto", () => {
  const dados = carregar_casos("impacto");
  const cfg = dados["config"];

  test("config embutida e dados do jogo validos", () => {
    assert.equal(Impacto.validar(cfg), "");
    assert.equal(Impacto.validar(carregar_dados("balance/impacto.json")), "");
  });
  for (const s of dados["suave"]) {
    test(`suave(${s["valor"]}, ${s["teto"]}, ${s["joelho_pct"]})`, () => {
      assert.equal(Impacto.suave(Math.trunc(s["valor"]), Math.trunc(s["teto"]), Math.trunc(s["joelho_pct"])), Math.trunc(s["esperado"]));
    });
  }
  for (const c of dados["casos"]) {
    test(c["nome"], () => {
      const obtido = Impacto.resolver(cfg, c["entrada"], new Aleatorio(Math.trunc(c["semente"])));
      const de_novo = Impacto.resolver(cfg, c["entrada"], new Aleatorio(Math.trunc(c["semente"])));
      assert.equal(normalizar(obtido), normalizar(c["esperado"]));
      assert.equal(normalizar(de_novo), normalizar(obtido));
    });
  }
});

describe("conjuntos", () => {
  const dados = carregar_casos("conjuntos");
  for (const c of dados["casos"]) {
    test(c["nome"], () => {
      const r = Conjuntos.efeito(c["equipados"], dados["itens"]);
      assert.deepEqual(r["habilidades"], c["esperado"]["habilidades"]);
      assert.deepEqual(Object.keys(r["atributos"]).sort(), Object.keys(c["esperado"]["atributos"]).sort());
      for (const k of Object.keys(c["esperado"]["atributos"])) {
        assert.equal(r["atributos"][k], Math.trunc(c["esperado"]["atributos"][k]));
      }
    });
  }
});

describe("forja", () => {
  const dados = carregar_casos("forja");
  dados["variacao"].forEach((c: Record<string, unknown>, i: number) => {
    test(`variacao de status #${i}`, () => {
      // deno-lint-ignore no-explicit-any
      const r = Forja.variar_status(c["status"] as any, Math.trunc(c["pct"] as number), Math.trunc(c["semente"] as number));
      assert.equal(normalizar(r), normalizar(c["esperado"]));
    });
  });
  dados["nivel"].forEach((c: Record<string, unknown>, i: number) => {
    test(`status com nivel #${i}`, () => {
      // deno-lint-ignore no-explicit-any
      const r = Forja.status_com_nivel(c["status"] as any, Math.trunc(c["nivel"] as number), Math.trunc(c["pct"] as number));
      assert.equal(normalizar(r), normalizar(c["esperado"]));
    });
  });
  dados["tentativas"].forEach((c: Record<string, unknown>, i: number) => {
    test(`tentativa de melhoria #${i}`, () => {
      assert.equal(Forja.melhoria_deu_certo(Math.trunc(c["nivel"] as number), dados["melhoria"], Math.trunc(c["semente"] as number)), c["esperado"]);
    });
  });
  test("tabela de chances do jogo = a dos casos", () => {
    const eco = carregar_dados("balance/economia.json");
    assert.deepEqual(eco["melhoria"]["chance_sucesso_pct"], dados["melhoria"]["chance_sucesso_pct"]);
  });
});

describe("baus", () => {
  const dados = carregar_casos("baus");
  for (const caso of dados["casos"]) {
    test(caso["nome"], () => {
      const r = Bau.abrir(caso["tipo"], dados["config"], dados["modelos"], caso["possui"], Math.trunc(caso["garantia"]), Math.trunc(caso["semente"]));
      const e = caso["esperado"];
      assert.equal(r.ouro, Math.trunc(e["ouro"]));
      assert.equal(r.fragmentos, Math.trunc(e["fragmentos"]));
      assert.equal(r.garantia, Math.trunc(e["garantia"]));
      assert.deepEqual(r.itens, e["itens"].map((i: Record<string, unknown>) => ({ modelo: i["modelo"], raridade: i["raridade"], repetida: i["repetida"] })));
    });
  }
  test("config do jogo = config dos casos", () => {
    const eco = carregar_dados("balance/economia.json");
    assert.equal(normalizar(eco["baus"]), normalizar(dados["config"]));
  });
  test("probabilidades somam 100 (madeira)", () => {
    const eco = carregar_dados("balance/economia.json");
    const p = Bau.probabilidades("madeira", eco["baus"]);
    const soma = Object.values(p).reduce((a, b) => a + b, 0);
    assert.ok(Math.abs(soma - 100) < 0.2);
    assert.equal(Object.keys(p)[0], "comum");
  });
});

describe("ligas", () => {
  const d = carregar_casos("liga");
  test("posicao na liga", () => {
    for (const c of d["posicao"]) {
      const r = Liga.posicao(Math.trunc(c["pontos"]), d["ligas"]);
      for (const k of Object.keys(c["esperado"])) assert.equal(String(r[k]), String(c["esperado"][k]), `${c["pontos"]} ${k}`);
    }
  });
  test("pontos depois da partida, da defesa, reinicio, ouro e poder", () => {
    for (const c of d["partida"]) assert.equal(Liga.depois_da_partida(Math.trunc(c["pontos"]), c["venceu"], d["ligas"]), Math.trunc(c["esperado"]));
    for (const c of d["defesa"]) assert.equal(Liga.depois_da_defesa(Math.trunc(c["pontos"]), c["defendeu"], d["ligas"]), Math.trunc(c["esperado"]));
    for (const c of d["reinicio"]) assert.equal(Liga.reinicio(Math.trunc(c["pontos"]), d["ligas"]), Math.trunc(c["esperado"]));
    for (const c of d["ouro"]) assert.equal(Liga.ouro_vitoria(Math.trunc(c["liga"]), d["ligas"]), Math.trunc(c["esperado"]));
    for (const c of d["poder"]) assert.equal(Liga.poder(c["atributos"], c["pecas"], d["economia"]), Math.trunc(c["esperado"]));
  });
  test("pareamento", () => {
    for (const c of d["parear"]) {
      assert.equal(Liga.parear(Math.trunc(c["pontos"]), Math.trunc(c["poder"]), c["candidatos"], d["ligas"]), c["esperado"]);
    }
  });
});

describe("desafios do PvE", () => {
  const dados = carregar_casos("desafios_pve");
  const b = dados["base"];

  // Lê "a.b.c" de objetos aninhados (undefined se não existe).
  function ler(v: unknown, caminho: string): unknown {
    for (const parte of caminho.split(".")) {
      if (typeof v !== "object" || v === null || !Object.hasOwn(v, parte)) return undefined;
      v = (v as Record<string, unknown>)[parte];
    }
    return v;
  }

  for (const caso of dados["casos"]) {
    test(caso["nome"], () => {
      const antes = normalizar(b);
      const r = Pve.aplicar_desafios(b["cfg"], b["lado_jogador"], b["lado_rival"], b["perfil_rival"], caso["desafios"], dados["defs"]);
      for (const chave of Object.keys(caso["esperado"])) {
        const v = ler(r, chave);
        const e = caso["esperado"][chave];
        if (e === null) assert.equal(v, undefined, chave);
        else assert.equal(Math.trunc(Number(v)), Math.trunc(e), chave);
      }
      assert.equal(normalizar(b), antes, "nao muda a entrada");
    });
  }
  for (const caso of dados["perfil"]) {
    test(`perfil: ${caso["nome"]}`, () => {
      const p = Pve.ajustar_perfil(caso["perfil"], caso["ajuste"]);
      for (const k of Object.keys(caso["esperado"])) assert.equal(String(p[k]), String(caso["esperado"][k]), k);
    });
  }
  for (const caso of dados["perfil_rival"]) {
    test(`perfil do rival: ${caso["nome"]}`, () => {
      const p = Pve.perfil_do_rival(dados["ia_perfil_rival"], caso["rival"]);
      for (const k of Object.keys(caso["esperado"])) {
        if (caso["esperado"][k] === null) assert.equal(k in p, false, k);
        else assert.equal(String(p[k]), String(caso["esperado"][k]), k);
      }
    });
  }
});

describe("ordens", () => {
  const d = carregar_casos("ordem");
  const cfg = d["cfg"];
  test("permissoes e cargos", () => {
    for (const c of d["pode"]) assert.equal(Ordem.pode(c["cargo"], c["acao"], cfg), c["esperado"]);
    for (const c of d["pode_sobre"]) assert.equal(Ordem.pode_sobre(c["ator"], c["alvo"], c["acao"], cfg), c["esperado"]);
    for (const c of d["cargo_depois"]) assert.equal(Ordem.cargo_depois(c["cargo"], c["acao"]), c["esperado"]);
    for (const c of d["vaga"]) assert.equal(Ordem.tem_vaga(Math.trunc(c["membros"]), cfg), c["esperado"]);
  });
  test("ajuda, doacao, torneio e loja", () => {
    for (const c of d["segundos_da_ajuda"]) assert.equal(Ordem.segundos_da_ajuda(Math.trunc(c["restante"]), cfg), Math.trunc(c["esperado"]));
    for (const c of d["aceita_ajuda"]) assert.equal(Ordem.pedido_aceita_ajuda(Math.trunc(c["ajudas"]), cfg), c["esperado"]);
    for (const c of d["moeda_da_ajuda"]) assert.equal(Ordem.moeda_da_ajuda(Math.trunc(c["hoje"]), cfg), Math.trunc(c["esperado"]));
    for (const c of d["doacao_restante"]) assert.equal(Ordem.doacao_restante(Math.trunc(c["hoje"]), cfg), Math.trunc(c["esperado"]));
    for (const c of d["posicao_torneio"]) assert.equal(Ordem.posicao_no_torneio(Math.trunc(c["minhas"]), c["outras"]), Math.trunc(c["esperado"]));
    for (const c of d["premio_torneio"]) assert.deepEqual(Ordem.premio_do_torneio(Math.trunc(c["posicao"]), cfg), c["esperado"]);
    for (const c of d["erro_da_compra"]) assert.equal(Ordem.erro_da_compra(Math.trunc(c["moeda"]), Math.trunc(c["comprados"]), c["item"]), c["esperado"]);
  });
  test("vitorias simuladas, codigo de amigo e ordens simuladas", () => {
    for (const c of d["vitorias_simuladas"]) {
      assert.equal(Ordem.vitorias_simuladas(Math.trunc(c["semente"]), Math.trunc(c["semana"]), Math.trunc(c["indice"]), Math.trunc(c["fracao"]), cfg), Math.trunc(c["esperado"]));
    }
    for (const c of d["codigo_amigo"]) assert.equal(Ordem.codigo_amigo(Math.trunc(c["semente"])), c["esperado"]);
    for (const c of d["codigo_valido"]) assert.equal(Ordem.codigo_valido(c["texto"]), c["esperado"]);
    for (const c of d["ordens_simuladas"]) {
      const r = Ordem.ordens_simuladas(Math.trunc(c["semente"]), cfg, d["nomes"], d["cores"], d["simbolos"], d["divisoes"]);
      assert.equal(normalizar(r), normalizar(c["esperado"]));
    }
  });
});
