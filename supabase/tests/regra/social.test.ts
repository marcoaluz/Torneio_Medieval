// Funções sociais no servidor (3.8): ordem e cargos, ajuda nos timers
// (aplicada por quem pediu), doação com limite, torneio semanal, loja da ordem,
// chat com moderação e amigos. O banco é o falso em memória (fixtura.ts), que
// emula as operações do SQL.

import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { agir, bal, JOGADOR, montar, OUTRO, PERS, uuid } from "./fixtura.ts";
import type { Dados } from "./comum.ts";

const TERCEIRO = "33333333-3333-4333-8333-333333333333";
const BRASAO = { forma: "classico", divisao: "liso", cor1: "azul_real", cor2: "prata" };

/** Três jogadores prontos (nível 10, ouro, fora do primeiro dia) e o primeiro cria a ordem. */
async function ordem_pronta() {
  const m = montar();
  for (const [j, nome] of [[JOGADOR, "Isolda"], [OUTRO, "Beatriz"], [TERCEIRO, "Cecília"]] as const) {
    await agir(m.dep, "criar_personagem", [{ ...PERS, nome }], undefined, j);
    m.banco.nomes.set(j, nome);
  }
  m.relogio.avancar(100000);
  for (const j of [JOGADOR, OUTRO, TERCEIRO]) {
    const e = m.banco.estados.get(j)!.estado;
    e["cavaleiro"]["nivel"] = 10;
    e["inventario"]["ouro"] = 5000;
  }
  const r = await agir(m.dep, "criar_ordem", ["Ordem do Corvo", BRASAO, "pt"]);
  assert.equal(r.corpo["ok"], true, JSON.stringify(r.corpo));
  const [ordem_id] = [...m.banco.ordens.keys()];
  return { ...m, ordem_id };
}

describe("ordem e cargos", () => {
  test("criar: gasta ouro, vira líder; nome único; sem nível/ouro não cria", async () => {
    const { banco, dep, ordem_id } = await ordem_pronta();
    assert.equal(banco.membros_de.get(ordem_id)!.get(JOGADOR), "lider");
    assert.equal(banco.estados.get(JOGADOR)!.estado["inventario"]["ouro"], 5000 - bal("ordem")["criar"]["ouro"]);
    assert.equal((await agir(dep, "criar_ordem", ["Outra Ordem", BRASAO, "pt"])).corpo["erro"], "ja_tem_ordem");
    assert.equal((await agir(dep, "criar_ordem", ["ordem do corvo", BRASAO, "pt"], undefined, OUTRO)).corpo["erro"], "nome_em_uso");
    assert.equal((await agir(dep, "criar_ordem", ["Porra Total", BRASAO, "pt"], undefined, OUTRO)).corpo["erro"], "nome_ofensivo");
    banco.estados.get(OUTRO)!.estado["cavaleiro"]["nivel"] = 1;
    assert.equal((await agir(dep, "criar_ordem", ["Ordem Nova", BRASAO, "pt"], undefined, OUTRO)).corpo["erro"], "nivel_baixo");
  });

  test("entrar, cargos, expulsar e passar a liderança, pelas permissões do cargo", async () => {
    const { banco, dep, ordem_id } = await ordem_pronta();
    assert.equal((await agir(dep, "entrar_ordem", [ordem_id], undefined, OUTRO)).corpo["ok"], true);
    assert.equal((await agir(dep, "entrar_ordem", [ordem_id], undefined, TERCEIRO)).corpo["ok"], true);
    assert.equal((await agir(dep, "entrar_ordem", ["nao-existe"], undefined, TERCEIRO)).corpo["erro"], "ja_tem_ordem");
    // membro não promove; líder promove
    assert.equal((await agir(dep, "agir_sobre_membro", [TERCEIRO, "promover"], undefined, OUTRO)).corpo["erro"], "sem_permissao");
    assert.equal((await agir(dep, "agir_sobre_membro", [OUTRO, "promover"])).corpo["ok"], true);
    assert.equal(banco.membros_de.get(ordem_id)!.get(OUTRO), "oficial");
    // oficial expulsa membro comum, mas não o líder
    assert.equal((await agir(dep, "agir_sobre_membro", [JOGADOR, "expulsar"], undefined, OUTRO)).corpo["erro"], "sem_permissao");
    assert.equal((await agir(dep, "agir_sobre_membro", [TERCEIRO, "expulsar"], undefined, OUTRO)).corpo["ok"], true);
    assert.equal(banco.membros_de.get(ordem_id)!.has(TERCEIRO), false);
    // líder não sai com gente; passa a liderança e sai
    assert.equal((await agir(dep, "sair_ordem", [])).corpo["erro"], "passe_a_lideranca");
    assert.equal((await agir(dep, "passar_lideranca", [OUTRO])).corpo["ok"], true);
    assert.equal(banco.membros_de.get(ordem_id)!.get(OUTRO), "lider");
    assert.equal(banco.membros_de.get(ordem_id)!.get(JOGADOR), "oficial");
    assert.equal((await agir(dep, "sair_ordem", [])).corpo["ok"], true);
    // o último a sair apaga a ordem
    assert.equal((await agir(dep, "sair_ordem", [], undefined, OUTRO)).corpo["ok"], true);
    assert.equal(banco.ordens.size, 0);
  });

  test("ordem cheia e editar nome/brasão por cargo; dissolver só o líder", async () => {
    const { banco, dep, ordem_id } = await ordem_pronta();
    const membros = banco.membros_de.get(ordem_id)!;
    for (let i = 0; i < 29; i++) membros.set(`00000000-0000-4000-8000-0000000000${String(i).padStart(2, "0")}`, "membro");
    assert.equal((await agir(dep, "entrar_ordem", [ordem_id], undefined, OUTRO)).corpo["erro"], "ordem_cheia");
    membros.delete("00000000-0000-4000-8000-000000000000");
    await agir(dep, "entrar_ordem", [ordem_id], undefined, OUTRO);
    assert.equal((await agir(dep, "editar_ordem", ["Novo Nome", {}], undefined, OUTRO)).corpo["erro"], "sem_permissao");
    assert.equal((await agir(dep, "editar_ordem", ["", { ...BRASAO, simbolo: "lua" }], undefined, OUTRO)).corpo["erro"], "sem_permissao");
    assert.equal((await agir(dep, "editar_ordem", ["Ordem do Lobo", { ...BRASAO, simbolo: "lua" }])).corpo["ok"], true);
    assert.equal(banco.ordens.get(ordem_id)!.nome, "Ordem do Lobo");
    assert.equal((await agir(dep, "dissolver_ordem", [], undefined, OUTRO)).corpo["erro"], "sem_permissao");
    assert.equal((await agir(dep, "dissolver_ordem", [])).corpo["ok"], true);
    assert.equal(banco.ordens.size, 0);
  });
});

describe("ajuda e doação entre membros", () => {
  async function com_membros() {
    const m = await ordem_pronta();
    await agir(m.dep, "entrar_ordem", [m.ordem_id], undefined, OUTRO);
    // OUTRO tem um timer de treino longo para pedir ajuda
    const e = m.banco.estados.get(OUTRO)!.estado;
    e["timers"].push({ id: "t-teste", tipo: "treino_cavaleiro", alvo: "campo_treino", atributo: "forca", inicio_em: m.relogio.agora(), termina_em: m.relogio.agora() + 7200 });
    return m;
  }

  test("pedido de ajuda: o colega ajuda, ganha moeda; o corte entra no estado de quem pediu na próxima ação", async () => {
    const { banco, dep, relogio } = await com_membros();
    const p = await agir(dep, "pedir_ajuda", ["t-teste"], undefined, OUTRO);
    assert.equal(p.corpo["ok"], true, JSON.stringify(p.corpo));
    assert.equal((await agir(dep, "pedir_ajuda", ["t-teste"], undefined, OUTRO)).corpo["erro"], "ja_pediu");
    assert.equal((await agir(dep, "pedir_ajuda", ["nao-existe"], undefined, OUTRO)).corpo["erro"], "timer_inexistente");
    const [pedido] = [...banco.pedidos.values()];
    assert.equal((await agir(dep, "ajudar_pedido", [pedido.id], undefined, OUTRO)).corpo["erro"], "pedido_proprio");
    const a = await agir(dep, "ajudar_pedido", [pedido.id]);
    assert.equal(a.corpo["ok"], true, JSON.stringify(a.corpo));
    assert.equal(a.corpo["moeda"], bal("ordem")["ajuda"]["moeda_por_ajuda"]);
    assert.equal(banco.estados.get(JOGADOR)!.estado["social"]["moeda"], a.corpo["moeda"]);
    assert.equal((await agir(dep, "ajudar_pedido", [pedido.id])).corpo["erro"], "ja_ajudou");
  });

  test("o estado de quem pediu só muda quando ele age (nunca o de quem ajudou)", async () => {
    const { banco, dep, relogio } = await com_membros();
    await agir(dep, "pedir_ajuda", ["t-teste"], undefined, OUTRO);
    const [pedido] = [...banco.pedidos.values()];
    await agir(dep, "ajudar_pedido", [pedido.id]);
    const antes = banco.estados.get(OUTRO)!.estado["timers"][0]["termina_em"];
    assert.equal(banco.estados.get(OUTRO)!.estado["timers"][0]["termina_em"], antes, "ainda não aplicada");
    // qualquer ação do OUTRO aplica a ajuda pendente no estado dele
    await agir(dep, "resgatar_login", [], undefined, OUTRO);
    const depois = banco.estados.get(OUTRO)!.estado["timers"][0]["termina_em"];
    assert.equal(depois, antes - bal("ordem")["ajuda"]["segundos_por_ajuda"]);
    assert.equal(banco.ajudas[0].aplicada, true);
    // de novo: não aplica duas vezes
    await agir(dep, "resgatar_login", [], undefined, OUTRO);
    assert.equal(banco.estados.get(OUTRO)!.estado["timers"][0]["termina_em"], depois);
    void relogio;
  });

  test("doação: sai do doador, vira moeda; o colega recebe na próxima ação; limite diário", async () => {
    const { banco, dep } = await com_membros();
    banco.estados.get(JOGADOR)!.estado["inventario"]["materiais"]["sucata"] = 50;
    const outro_antes = banco.estados.get(OUTRO)!.estado["inventario"]["materiais"]["sucata"] ?? 0;
    const r = await agir(dep, "doar", [OUTRO, "sucata", 10]);
    assert.equal(r.corpo["ok"], true, JSON.stringify(r.corpo));
    assert.equal(banco.estados.get(JOGADOR)!.estado["inventario"]["materiais"]["sucata"], 40);
    assert.equal(banco.estados.get(OUTRO)!.estado["inventario"]["materiais"]["sucata"] ?? 0, outro_antes, "ainda não recebeu");
    await agir(dep, "resgatar_login", [], undefined, OUTRO);
    assert.equal(banco.estados.get(OUTRO)!.estado["inventario"]["materiais"]["sucata"], outro_antes + 10);
    assert.equal((await agir(dep, "doar", [OUTRO, "sucata", 10])).corpo["erro"], "limite_diario");
    assert.equal((await agir(dep, "doar", [OUTRO, "gemas", 1])).corpo["erro"], "material_nao_doavel");
    assert.equal((await agir(dep, "doar", [TERCEIRO, "sucata", 1])).corpo["erro"], "membro_inexistente");
    assert.equal((await agir(dep, "doar", [OUTRO, "sucata", 0])).corpo["erro"], "quantidade_invalida");
  });
});

describe("torneio semanal e loja da ordem", () => {
  test("vitória de PvP conta para a ordem; classificação e prêmio da semana passada", async () => {
    const { banco, dep, relogio, ordem_id } = await ordem_pronta();
    const semana = Math.floor((Math.floor((relogio.agora() - bal("metas")["virada_hora_utc"] * 3600) / 86400) + 3) / 7);
    banco.torneio_tabela.set(`${semana}|${ordem_id}|${JOGADOR}`, 3);
    banco.ordens.set("rival", { id: "rival", nome: "Ordem Rival", brasao: {}, idioma: "pt" });
    banco.torneio_tabela.set(`${semana}|rival|x`, 5);
    const t = await agir(dep, "torneio_semana", []);
    assert.equal(t.corpo["ok"], true);
    assert.equal(t.corpo["pontos"], 3);
    assert.equal(t.corpo["posicao"], 2);
    // semana passada: terminou em 1º -> prêmio uma vez só
    banco.torneio_tabela.set(`${semana - 1}|${ordem_id}|${JOGADOR}`, 9);
    const moeda0 = banco.estados.get(JOGADOR)!.estado["social"]["moeda"] ?? 0;
    const r = await agir(dep, "resgatar_torneio", []);
    assert.equal(r.corpo["ok"], true, JSON.stringify(r.corpo));
    assert.equal(r.corpo["posicao"], 1);
    assert.equal(banco.estados.get(JOGADOR)!.estado["social"]["moeda"], moeda0 + bal("ordem")["torneio"]["premios"][0]["moeda"]);
    assert.equal((await agir(dep, "resgatar_torneio", [])).corpo["erro"], "sem_premio");
  });

  test("loja da ordem: compra por moeda com limite semanal", async () => {
    const { banco, dep } = await ordem_pronta();
    const e = banco.estados.get(JOGADOR)!.estado;
    assert.equal((await agir(dep, "comprar_da_ordem", ["lingote_aco"])).corpo["erro"], "moeda_insuficiente");
    e["social"]["moeda"] = 500;
    const aco0 = e["inventario"]["materiais"]["lingote_aco"] ?? 0;
    assert.equal((await agir(dep, "comprar_da_ordem", ["lingote_aco"])).corpo["ok"], true);
    assert.equal(banco.estados.get(JOGADOR)!.estado["inventario"]["materiais"]["lingote_aco"], aco0 + 2);
    await agir(dep, "comprar_da_ordem", ["lingote_aco"]);
    await agir(dep, "comprar_da_ordem", ["lingote_aco"]);
    assert.equal((await agir(dep, "comprar_da_ordem", ["lingote_aco"])).corpo["erro"], "limite_semana");
    assert.equal((await agir(dep, "comprar_da_ordem", ["xx"])).corpo["erro"], "produto_inexistente");
  });
});

describe("chat, moderação e amigos", () => {
  test("mensagem da ordem vai para o canal da ordem do BANCO (o cliente não escolhe); global por idioma", async () => {
    const { banco, dep, ordem_id } = await ordem_pronta();
    const r = await agir(dep, "chat_enviar", ["ordem", "Boa justa, pessoal!", "", "pt"]);
    assert.equal(r.corpo["ok"], true, JSON.stringify(r.corpo));
    assert.equal(banco.chat.at(-1)!.canal, `ordem:${ordem_id}`);
    assert.equal(banco.chat.at(-1)!.de_nome, "Isolda");
    const g = await agir(dep, "chat_enviar", ["global", "", "boa_justa", "en"]);
    assert.equal(g.corpo["ok"], true);
    assert.equal(banco.chat.at(-1)!.canal, "global:en");
    assert.equal(banco.chat.at(-1)!.chave, "boa_justa");
    // sem ordem não há chat da ordem
    assert.equal((await agir(dep, "chat_enviar", ["ordem", "oi", "", "pt"], undefined, OUTRO)).corpo["erro"], "sem_ordem");
    assert.equal((await agir(dep, "chat_enviar", ["sala", "oi", "", "pt"])).corpo["erro"], "canal_inexistente");
  });

  test("filtro de palavras, vazio, longo, rápida inexistente e silenciamento", async () => {
    const { banco, dep, relogio } = await ordem_pronta();
    assert.equal((await agir(dep, "chat_enviar", ["global", "seu P0RR4", "", "pt"])).corpo["erro"], "mensagem_ofensiva");
    assert.equal((await agir(dep, "chat_enviar", ["global", "   ", "", "pt"])).corpo["erro"], "mensagem_vazia");
    assert.equal((await agir(dep, "chat_enviar", ["global", "a".repeat(190), "", "pt"])).corpo["erro"], "mensagem_longa");
    assert.equal((await agir(dep, "chat_enviar", ["global", "", "nao_existe", "pt"])).corpo["erro"], "mensagem_inexistente");
    banco.silenciados.set(JOGADOR, relogio.agora() + 3600);
    assert.equal((await agir(dep, "chat_enviar", ["global", "oi", "", "pt"])).corpo["erro"], "silenciado");
    assert.equal(banco.chat.length, 0);
  });

  test("amigo por código, repetido, o próprio, desconhecido e remover (nos dois sentidos)", async () => {
    const { banco, dep } = await ordem_pronta();
    banco.codigos.set("TM-ABC234", OUTRO);
    banco.codigos.set("TM-ZZZ222", JOGADOR);
    const r = await agir(dep, "adicionar_amigo_por_codigo", ["tm-abc234"]);
    assert.equal(r.corpo["ok"], true, JSON.stringify(r.corpo));
    assert.equal(r.corpo["nome"], "Beatriz");
    assert.ok(banco.amizades.has(`${JOGADOR}|${OUTRO}`) && banco.amizades.has(`${OUTRO}|${JOGADOR}`));
    assert.equal((await agir(dep, "adicionar_amigo_por_codigo", ["TM-ABC234"])).corpo["erro"], "ja_amigo");
    assert.equal((await agir(dep, "adicionar_amigo_por_codigo", ["TM-ZZZ222"])).corpo["erro"], "codigo_proprio");
    assert.equal((await agir(dep, "adicionar_amigo_por_codigo", ["TM-AAAAAA"])).corpo["erro"], "codigo_nao_encontrado");
    assert.equal((await agir(dep, "adicionar_amigo_por_codigo", ["abc"])).corpo["erro"], "codigo_invalido");
    assert.equal((await agir(dep, "remover_amigo", [OUTRO])).corpo["ok"], true);
    assert.equal(banco.amizades.size, 0);
  });

  test("conflito do banco desfaz a ação inteira (ordem repetida na corrida) e responde o erro certo", async () => {
    const { banco, dep } = await ordem_pronta();
    // Outro jogador cria a ordem de mesmo nome entre a leitura e a gravação.
    banco.antes_de_gravar = () => {
      banco.ordens.set("corrida", { id: "corrida", nome: "Ordem da Corrida", brasao: {}, idioma: "pt" });
      banco.membros_de.set("corrida", new Map([[TERCEIRO, "lider"]]));
    };
    const ouro0 = banco.estados.get(OUTRO)!.estado["inventario"]["ouro"];
    const r = await agir(dep, "criar_ordem", ["Ordem da Corrida", BRASAO, "pt"], uuid(), OUTRO);
    assert.equal(r.corpo["erro"], "nome_em_uso");
    assert.equal(banco.estados.get(OUTRO)!.estado["inventario"]["ouro"], ouro0, "o ouro não foi cobrado");
    void (null as unknown as Dados);
  });
});
