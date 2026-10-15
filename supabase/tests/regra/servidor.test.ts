// Tratamento de ações (3.2) e disputa conferida (3.4), com um banco falso em
// memória: idempotência, limite de chamadas, argumentos hostis, concorrência,
// anúncio sem comprovante e a justa refeita pelo servidor.

import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { tratar_acao } from "../../functions/_shared/servidor/handler.ts";
import { novo_estado } from "../../functions/_shared/servidor/estado.ts";
import { refazer_justa, validar_entradas } from "../../functions/_shared/servidor/disputa.ts";
import { Justa } from "../../functions/_shared/regra/justa.ts";
import { Fase } from "../../functions/_shared/regra/justa_fases.ts";
import type { Dados } from "./comum.ts";

import { agir, bal, BancoFalso, JOGADOR, montar, PERS, uuid } from "./fixtura.ts";

const RAIZ = new URL("../../../", import.meta.url);

describe("ações do servidor", () => {
  test("primeiro uso cria o estado e a ação grava com revisão 1", async () => {
    const { banco, dep } = montar();
    const r = await agir(dep, "criar_personagem", [PERS]);
    assert.equal(r.status, 200);
    assert.equal(r.corpo["ok"], true);
    assert.equal(r.corpo["revisao"], 1);
    assert.equal(banco.estados.get(JOGADOR)?.estado["cavaleiro"]["nome"], "Isolda");
    assert.equal(banco.estados.get(JOGADOR)?.estado["baus"]["semente"], 123456789);
  });

  test("idempotência: o mesmo id não entrega duas vezes", async () => {
    const { banco, dep, relogio } = montar();
    await agir(dep, "criar_personagem", [PERS]);
    relogio.avancar(100000); // fora do primeiro dia
    const estado0 = banco.estados.get(JOGADOR)!.estado;
    estado0["cavaleiro"]["nivel"] = 10;
    estado0["inventario"]["ouro"] = 5000;
    const id = uuid();
    const a = await agir(dep, "treinar_cavaleiro", ["forca"], id);
    assert.equal(a.corpo["ok"], true);
    const ouro_depois = banco.estados.get(JOGADOR)!.estado["inventario"]["ouro"];
    assert.ok(ouro_depois < 5000);
    const b = await agir(dep, "treinar_cavaleiro", ["forca"], id);
    assert.equal(b.corpo["repetida"], true);
    assert.equal(b.corpo["ok"], true);
    assert.equal(banco.estados.get(JOGADOR)!.estado["inventario"]["ouro"], ouro_depois);
    assert.equal(banco.estados.get(JOGADOR)!.estado["timers"].length, 1);
  });

  test("erro de regra não muda o estado e também repete igual", async () => {
    const { banco, dep } = montar();
    await agir(dep, "criar_personagem", [PERS]);
    const antes = JSON.stringify(banco.estados.get(JOGADOR));
    const id = uuid();
    const a = await agir(dep, "melhorar_predio", ["nao_existe"], id);
    assert.equal(a.corpo["erro"], "predio_inexistente");
    const b = await agir(dep, "melhorar_predio", ["nao_existe"], id);
    assert.equal(b.corpo["repetida"], true);
    assert.equal(b.corpo["erro"], "predio_inexistente");
    assert.equal(JSON.stringify(banco.estados.get(JOGADOR)), antes);
  });

  test("limite de chamadas por minuto", async () => {
    const { dep } = montar();
    let ultimo = 200;
    for (let i = 0; i < 61; i++) {
      const r = await agir(dep, "resgatar_login", []);
      ultimo = r.status;
    }
    assert.equal(ultimo, 429);
  });

  test("comandos internos e inexistentes não são expostos", async () => {
    const { dep } = montar();
    for (const tipo of ["ganhar_bau", "entregar_compra", "registrar_justa", "adicionar_cavalo", "concluir_disputa", "toString", "__proto__"]) {
      const r = await agir(dep, tipo, ["ferro"]);
      assert.equal(r.status, 400, tipo);
      assert.equal(r.corpo["erro"], "comando_inexistente", tipo);
    }
  });

  test("argumentos hostis são recusados", async () => {
    const { dep } = montar();
    const casos: [string, unknown][] = [
      ["treinar_cavaleiro", "forca"], // não é lista
      ["treinar_cavaleiro", []],
      ["treinar_cavaleiro", [5]],
      ["treinar_cavaleiro", ["a".repeat(500)]],
      ["fundir", ["lingote_ferro", 1.5]],
      ["abrir_bau", ["b1", "sim"]],
      ["criar_personagem", [JSON.parse('{"__proto__": {"admin": true}}')]],
      ["criar_personagem", [{ a: { b: { c: { d: { e: { f: 1 } } } } } }]],
      ["definir_config", ["texto", { x: 1 }]],
    ];
    for (const [tipo, args] of casos) {
      const r = await agir(dep, tipo, args as unknown[]);
      assert.equal(r.status, 400, `${tipo} ${JSON.stringify(args).slice(0, 40)}`);
    }
    const sem_id = await tratar_acao({ jogador_id: JOGADOR, id: "123", tipo: "resgatar_login", args: [] }, dep);
    assert.equal(sem_id.corpo["erro"], "id_invalido");
  });

  test("conflito de revisão: refaz sobre o estado novo e não perde a ação", async () => {
    const { banco, dep, relogio } = montar();
    await agir(dep, "criar_personagem", [PERS]);
    relogio.avancar(100000);
    const e = banco.estados.get(JOGADOR)!.estado;
    e["inventario"]["ouro"] = 1000;
    e["cavaleiro"]["nivel"] = 5;
    // Outra ação (outro aparelho) grava no meio: sobe a revisão e muda o ouro.
    banco.antes_de_gravar = () => {
      const atual = banco.estados.get(JOGADOR)!;
      atual.estado["inventario"]["ouro"] = 900;
      atual.revisao += 1;
    };
    const r = await agir(dep, "treinar_cavaleiro", ["forca"]);
    assert.equal(r.corpo["ok"], true);
    // O custo saiu do estado NOVO (900), não do que a primeira tentativa tinha lido (1000).
    const custo = 1000 - 900 + (900 - banco.estados.get(JOGADOR)!.estado["inventario"]["ouro"]);
    assert.ok(banco.estados.get(JOGADOR)!.estado["inventario"]["ouro"] < 900);
    assert.ok(custo > 100);
    assert.equal(banco.estados.get(JOGADOR)!.estado["timers"].length, 1);
  });

  test("anúncio: sem comprovante válido não entrega; com, entrega uma vez", async () => {
    const { banco, dep, anuncios, relogio } = montar();
    await agir(dep, "criar_personagem", [PERS]);
    relogio.avancar(100000);
    const ruim = await agir(dep, "recompensa_anuncio", ["bau_madeira_extra", "", "falso"]);
    assert.equal(ruim.corpo["erro"], "anuncio_nao_confirmado");
    assert.equal(banco.estados.get(JOGADOR)!.estado["baus"]["espacos"].length, 0);
    const id = uuid();
    const boa = await agir(dep, "recompensa_anuncio", ["bau_madeira_extra", "", "bom"], id);
    assert.equal(boa.corpo["ok"], true);
    assert.equal(banco.estados.get(JOGADOR)!.estado["baus"]["espacos"].length, 1);
    await agir(dep, "recompensa_anuncio", ["bau_madeira_extra", "", "bom"], id); // repetida
    assert.equal(banco.estados.get(JOGADOR)!.estado["baus"]["espacos"].length, 1);
    assert.deepEqual(anuncios, ["falso", "bom"]);
  });

  test("a disputa automática usa semente do servidor (o cliente não escolhe)", async () => {
    const { banco, dep, relogio } = montar();
    await agir(dep, "criar_personagem", [PERS]);
    relogio.avancar(100000);
    const e = banco.estados.get(JOGADOR)!.estado;
    e["cavaleiro"]["nivel"] = 20;
    e["pve"]["torneios"]["feira_moinho"] = { proxima: 1, concluido: false, estrelas: { "0": 3 } };
    const r = await agir(dep, "disputa_automatica", ["feira_moinho", 0]);
    assert.equal(r.corpo["ok"], true);
    assert.ok(Array.isArray(r.corpo["eventos"]));
    // Com um argumento a mais (a semente) o formato é recusado.
    const r2 = await agir(dep, "disputa_automatica", ["feira_moinho", 0, 1234]);
    assert.equal(r2.status, 400);
  });
});

// ---------------------------------------------------------- justa conferida

const PEITO = { x: 80, y: -860 };

/** Jogador-robô (o mesmo do teste do GDScript): larga 100 ms depois da bandeira, toca no compasso, mira no peito e solta. */
function robo(d: Dados): [number, string, number, number][] {
  const j = new Justa(d["cfg"], d["lado_jogador"], d["lado_rival"], d["semente"], d["perfil_rival"]);
  const entradas: [number, string, number, number][] = [];
  j.iniciar();
  while (!j.terminou()) {
    const f = j.fases.fase;
    const t = j.fases.tempo_total_ms;
    if (f === Fase.LARGADA && !j.tocou_largada && j.fases.tempo_na_fase_ms === j.bandeira_ms + 100) {
      entradas.push([t, "tocar", 0, 0]);
      j.tocar();
    } else if (f === Fase.CORRIDA && j.jogador.t_ms > 0 && j.jogador.t_ms % j.jogador.compasso_ms() === 0) {
      entradas.push([t, "tocar", 0, 0]);
      j.tocar();
    } else if (f === Fase.MIRA && j.fases.tempo_na_fase_ms === 100) {
      entradas.push([t, "mirar", PEITO.x, PEITO.y]);
      j.mirar(PEITO);
    } else if (f === Fase.MIRA && j.fases.tempo_na_fase_ms === 1000) {
      entradas.push([t, "soltar", 0, 0]);
      j.soltar();
    }
    j.avancar(1);
  }
  return entradas;
}

async function preparar_disputa() {
  const m = montar();
  await agir(m.dep, "criar_personagem", [PERS]);
  m.relogio.avancar(100000);
  const e = m.banco.estados.get(JOGADOR)!.estado;
  e["cavaleiro"]["nivel"] = 10;
  const ini = await agir(m.dep, "iniciar_disputa", ["feira_moinho", 0]);
  assert.equal(ini.corpo["ok"], true, JSON.stringify(ini.corpo));
  const d = m.banco.estados.get(JOGADOR)!.estado["disputa"];
  // O cliente joga com o que o servidor devolveu (a mesma configuração e os mesmos lados).
  assert.deepEqual(ini.corpo["cfg"], d["cfg"]);
  assert.deepEqual(ini.corpo["lado_jogador"], d["lado_jogador"]);
  assert.deepEqual(ini.corpo["rival"]["lado"], d["lado_rival"]);
  return { ...m, d, semente: ini.corpo["semente"] as number };
}

describe("justa conferida pelo servidor", () => {
  test("iniciar guarda semente e retrato; concluir refaz a justa e entrega as recompensas", async () => {
    const { banco, dep, d, relogio } = await preparar_disputa();
    assert.ok(Number.isInteger(d["semente"]));
    const entradas = robo(d);
    assert.ok(entradas.length > 10);
    relogio.avancar(60);
    const ouro0 = banco.estados.get(JOGADOR)!.estado["inventario"]["ouro"];
    const r = await agir(dep, "concluir_disputa_conferida", [entradas]);
    assert.equal(r.corpo["ok"], true, JSON.stringify(r.corpo));
    assert.ok(r.corpo["estrelas"] >= 1, "o robô que acerta o peito vence");
    const e = banco.estados.get(JOGADOR)!.estado;
    assert.equal("disputa" in e, false, "a disputa ativa some");
    assert.ok(e["inventario"]["ouro"] > ouro0);
    assert.equal(e["pve"]["torneios"]["feira_moinho"]["proxima"], 1);
    // O mesmo resultado se refaz fora do servidor, com a mesma semente e as mesmas entradas.
    const refeita = refazer_justa(d, entradas);
    assert.equal(refeita.justa.fases.placar_jogador, r.corpo["placar"][0]);
  });

  test("terminar rápido demais é recusado (tempo impossível) e nada é entregue", async () => {
    const { banco, dep, d } = await preparar_disputa();
    const entradas = robo(d);
    const ouro0 = banco.estados.get(JOGADOR)!.estado["inventario"]["ouro"];
    const r = await agir(dep, "concluir_disputa_conferida", [entradas]); // sem avançar o relógio
    assert.equal(r.corpo["erro"], "tempo_impossivel");
    assert.equal(banco.estados.get(JOGADOR)!.estado["inventario"]["ouro"], ouro0);
    assert.ok("disputa" in banco.estados.get(JOGADOR)!.estado, "a disputa continua ativa");
  });

  test("entradas impossíveis são recusadas", async () => {
    const cfg = bal("servidor")["anticheat"];
    assert.equal(validar_entradas([[100, "tocar", 0, 0], [110, "tocar", 0, 0]], cfg), "toques_impossiveis");
    assert.equal(validar_entradas([[200, "tocar", 0, 0], [100, "soltar", 0, 0]], cfg), "entradas_fora_de_ordem");
    assert.equal(validar_entradas([[100, "teleportar", 0, 0]], cfg), "entradas_invalidas");
    assert.equal(validar_entradas([[-5, "tocar", 0, 0]], cfg), "entradas_invalidas");
    assert.equal(validar_entradas([[100, "tocar", 0.5, 0]], cfg), "entradas_invalidas");
    assert.equal(validar_entradas("tocar", cfg), "entradas_invalidas");
    assert.equal(validar_entradas([[100, "tocar", 0, 0], [500, "mirar", 0, -1000]], cfg), "");
  });

  test("sem disputa ativa, concluir é recusado; abandonar limpa", async () => {
    const m = montar();
    await agir(m.dep, "criar_personagem", [PERS]);
    const r = await agir(m.dep, "concluir_disputa_conferida", [[]]);
    assert.equal(r.corpo["erro"], "sem_disputa_ativa");
    const p = await preparar_disputa();
    const a = await agir(p.dep, "abandonar_disputa", []);
    assert.equal(a.corpo["ok"], true);
    assert.equal("disputa" in p.banco.estados.get(JOGADOR)!.estado, false);
  });

  test("sem tocar em nada a justa corre sozinha e o jogador perde; ainda assim conclui", async () => {
    const { banco, dep, relogio } = await preparar_disputa();
    relogio.avancar(60);
    const r = await agir(dep, "concluir_disputa_conferida", [[]]);
    assert.equal(r.corpo["ok"], true);
    assert.equal(r.corpo["venceu"], false);
    assert.equal(banco.estados.get(JOGADOR)!.estado["pve"]["torneios"]["feira_moinho"]["proxima"], 0);
  });
});

describe("auditoria (3.11): re-sorteio, abandono e espera", () => {
  test("iniciar de novo a mesma disputa devolve a MESMA semente (nada de re-sortear)", async () => {
    const { dep, d } = await preparar_disputa();
    const r = await agir(dep, "iniciar_disputa", ["feira_moinho", 0]);
    assert.equal(r.corpo["ok"], true);
    assert.equal(r.corpo["semente"], d["semente"]);
    assert.equal(r.corpo["retomada"], true);
  });

  test("abandonar zera a sequência e exige espera para pedir outra semente", async () => {
    const { banco, dep, relogio } = await preparar_disputa();
    banco.estados.get(JOGADOR)!.estado["metas"]["sequencia"] = 5;
    const a = await agir(dep, "abandonar_disputa", []);
    assert.equal(a.corpo["ok"], true);
    assert.equal(banco.estados.get(JOGADOR)!.estado["metas"]["sequencia"], 0);
    const logo = await agir(dep, "iniciar_disputa", ["feira_moinho", 0]);
    assert.equal(logo.corpo["erro"], "aguarde");
    relogio.avancar(bal("servidor")["limites"]["cooldown_disputa_s"] + 1);
    const depois = await agir(dep, "iniciar_disputa", ["feira_moinho", 0]);
    assert.equal(depois.corpo["ok"], true);
  });

  test("a loja de teste só existe quando o ambiente permite", async () => {
    const m = montar();
    await agir(m.dep, "criar_personagem", [PERS]);
    const r = await agir(m.dep, "comprar_recibo", ["teste", "gemas_medio", "RECIBO-TESTE-1"]);
    assert.equal(r.corpo["erro"], "loja_indisponivel");
  });
});

describe("estado inicial", () => {
  test("novo_estado do servidor tem a mesma forma do GDScript (cenários gravados)", () => {
    const c = JSON.parse(readFileSync(new URL("tests/shared/cenarios_servico.json", RAIZ), "utf-8"))["cenarios"][0];
    const e = novo_estado(bal, c["criado_em"], c["estado_inicial"]["baus"]["semente"]);
    assert.deepEqual(JSON.parse(JSON.stringify(e)), c["estado_inicial"]);
  });
});

// ------------------------------------------------------- banco do Supabase

import { BancoSupabase, carregar_balanceamento } from "../../functions/_shared/servidor/banco_supabase.ts";

describe("banco do Supabase (cliente falso)", () => {
  /** Cliente que grava as chamadas e devolve o que o teste mandar. */
  function falso(respostas: Record<string, Dados>) {
    const chamadas: Dados[] = [];
    const cliente = {
      async rpc(nome: string, args: Dados) {
        chamadas.push({ rpc: nome, args });
        return respostas[nome] ?? { data: null, error: null };
      },
      from(tabela: string) {
        const f: Dados = { tabela, filtros: {} };
        const api = {
          select: (c: string) => { f["cols"] = c; return api; },
          eq: (k: string, v: unknown) => { f["filtros"][k] = v; return api; },
          maybeSingle: async () => { chamadas.push({ from: tabela, ...f }); return respostas["from:" + tabela] ?? { data: null, error: null }; },
          then: (res: (v: Dados) => void) => { chamadas.push({ from: tabela, ...f }); res(respostas["from:" + tabela] ?? { data: [], error: null }); },
        };
        return api;
      },
    };
    return { cliente, chamadas };
  }

  test("gravar usa a função transacional e traduz -1 (repetida) e null (conflito)", async () => {
    const { cliente, chamadas } = falso({ aplicar_acao: { data: "7", error: null } });
    const banco = new BancoSupabase(cliente);
    const r = await banco.gravar(JOGADOR, { versao: 11 }, 6, { id: "i", tipo: "t", resposta: { ok: true } }, { publico: { nome: "x" } });
    assert.equal(r, 7);
    assert.deepEqual(chamadas[0], {
      rpc: "aplicar_acao",
      args: {
        p_jogador: JOGADOR, p_estado: { versao: 11 }, p_revisao_esperada: 6, p_id: "i", p_tipo: "t",
        p_resposta: { ok: true }, p_efeitos: { publico: { nome: "x" } },
      },
    });
    const rep = new BancoSupabase(falso({ aplicar_acao: { data: -1, error: null } }).cliente);
    assert.equal(await rep.gravar(JOGADOR, {}, null, { id: "i", tipo: "t", resposta: {} }, {}), "repetida");
    const conf = new BancoSupabase(falso({ aplicar_acao: { data: null, error: null } }).cliente);
    assert.equal(await conf.gravar(JOGADOR, {}, 1, { id: "i", tipo: "t", resposta: {} }, {}), null);
  });

  test("erro do banco vira exceção (a função responde falha_interna, sem detalhe)", async () => {
    const banco = new BancoSupabase(falso({ aplicar_acao: { data: null, error: { message: "boom" } } }).cliente);
    await assert.rejects(() => banco.gravar(JOGADOR, {}, 1, { id: "i", tipo: "t", resposta: {} }, {}), /gravar: boom/);
  });

  test("carregar e resposta_guardada leem do jogador certo; contar usa a janela", async () => {
    const { cliente, chamadas } = falso({
      "from:save_jogador": { data: { dados: { versao: 11 }, revisao: "3" }, error: null },
      "from:acao_log": { data: { resposta: { ok: true } }, error: null },
      contar_chamada: { data: 5, error: null },
    });
    const banco = new BancoSupabase(cliente);
    assert.deepEqual(await banco.carregar(JOGADOR), { estado: { versao: 11 }, revisao: 3 });
    assert.deepEqual(await banco.resposta_guardada(JOGADOR, "abc"), { ok: true });
    assert.equal(await banco.contar_chamada(JOGADOR, 29833333), 5);
    assert.equal(chamadas[0]["filtros"]["jogador_id"], JOGADOR);
    assert.equal(chamadas[1]["filtros"]["id"], "abc");
  });

  test("balanceamento ativo vira {nome: dados}", async () => {
    const { cliente } = falso({ "from:balanceamento": { data: [{ nome: "treino", dados: { a: 1 } }, { nome: "vila", dados: { b: 2 } }], error: null } });
    assert.deepEqual(await carregar_balanceamento(cliente), { treino: { a: 1 }, vila: { b: 2 } });
  });
});

// ------------------------------------------------------ exclusão de conta

import { excluir_conta } from "../../functions/_shared/servidor/excluir_conta.ts";

describe("exclusão de conta", () => {
  test("só com a confirmação certa; prepara e depois apaga o usuário, nessa ordem", async () => {
    const chamadas: string[] = [];
    const cliente = {
      async rpc(nome: string, args: Dados) {
        chamadas.push(`rpc:${nome}:${args["p_jogador"]}`);
        return { data: null, error: null };
      },
      auth: { admin: { async deleteUser(id: string) { chamadas.push(`apagar:${id}`); return { error: null }; } } },
    };
    assert.deepEqual(await excluir_conta(cliente, JOGADOR, "excluir"), { ok: false, erro: "confirmacao_invalida" });
    assert.deepEqual(await excluir_conta(cliente, JOGADOR, undefined), { ok: false, erro: "confirmacao_invalida" });
    assert.deepEqual(chamadas, []);
    assert.deepEqual(await excluir_conta(cliente, JOGADOR, "EXCLUIR"), { ok: true, erro: "" });
    assert.deepEqual(chamadas, [`rpc:preparar_exclusao_conta:${JOGADOR}`, `apagar:${JOGADOR}`]);
  });

  test("se preparar falha, não apaga o usuário (nada pela metade)", async () => {
    const chamadas: string[] = [];
    const cliente = {
      async rpc() { return { data: null, error: { message: "boom" } }; },
      auth: { admin: { async deleteUser(id: string) { chamadas.push(id); return { error: null }; } } },
    };
    assert.deepEqual(await excluir_conta(cliente, JOGADOR, "EXCLUIR"), { ok: false, erro: "falha_ao_preparar" });
    assert.deepEqual(chamadas, []);
  });
});
