// PvP assíncrono e ligas no servidor (3.5/3.6): defesa como retrato,
// pareamento real ou fantasma, partida conferida, pontos do defensor,
// temporada global e resumo público.

import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { Justa } from "../../functions/_shared/regra/justa.ts";
import { Fase } from "../../functions/_shared/regra/justa_fases.ts";
import { fantasma, temporada_atual } from "../../functions/_shared/servidor/liga.ts";
import { lado_para_justa, poder_jogador } from "../../functions/_shared/servidor/jogador.ts";
import type { Servico } from "../../functions/_shared/servidor/base.ts";
import { agir, bal, JOGADOR, montar, OUTRO, PERS } from "./fixtura.ts";
import type { Dados } from "./comum.ts";

const PEITO = { x: 0, y: -1060 };

/** Jogador-robô: larga 100 ms depois da bandeira, toca no compasso, mira no peito e solta. */
function robo(cfg: Dados, lado_jogador: Dados, lado_rival: Dados, semente: number, perfil: Dados): [number, string, number, number][] {
  const j = new Justa(cfg, lado_jogador, lado_rival, semente, perfil);
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

/** Jogador pronto para PvP: personagem criado, fora do primeiro dia, na temporada atual. */
async function pronto() {
  const m = montar(1792000000);
  await agir(m.dep, "criar_personagem", [PERS]);
  m.relogio.avancar(100000);
  const e = m.banco.estados.get(JOGADOR)!.estado;
  e["cavaleiro"]["nivel"] = 10;
  return m;
}

describe("defesa e resumo público", () => {
  test("salvar defesa guarda o retrato e o poder como efeito, e toda ação atualiza o resumo público", async () => {
    const { banco, dep } = await pronto();
    const r = await agir(dep, "salvar_defesa", []);
    assert.equal(r.corpo["ok"], true);
    assert.equal("_efeitos" in r.corpo, false, "efeitos não vão para o cliente");
    const ef = banco.efeitos[banco.efeitos.length - 1].efeitos;
    assert.ok(ef["defesa"]["retrato"]["equipamento"]["elmo"], "retrato com as peças");
    assert.ok(ef["defesa"]["poder"] > 0);
    assert.equal(ef["publico"]["nome"], "Isolda");
    assert.equal(ef["publico"]["poder"], ef["defesa"]["poder"]);
    assert.match(ef["publico"]["codigo"], /^TM-[A-Z2-9]{6}$/);
    assert.equal(ef["publico"]["liga"], "bronze");
    assert.equal(banco.estados.get(JOGADOR)!.estado["liga"]["defesa"]["cavalo"], "c1");
  });
});

describe("adversário", () => {
  test("sem ninguém na faixa: fantasma do servidor, estável pela semente do jogador", async () => {
    const { banco, dep } = await pronto();
    banco.candidatos = [];
    const r = await agir(dep, "procurar_adversario", []);
    assert.equal(r.corpo["ok"], true);
    const a = r.corpo["adversario"];
    assert.equal(a["simulado"], true);
    assert.ok(a["lado"]["equipamento"]["elmo"]);
    assert.ok(Number.isInteger(a["semente"]));
    const e = banco.estados.get(JOGADOR)!.estado;
    assert.equal(e["liga"]["adversario"]["nome"], a["nome"]);
    // mesma busca, mesmo fantasma (a semente do save e o contador de buscas decidem)
    const s: Servico = { estado: structuredClone(e), bal, agora: () => 0 };
    s.estado["liga"]["buscas"] = 0;
    const f1 = fantasma(s, 100, 0, 0, 40);
    const f2 = fantasma(s, 100, 0, 0, 40);
    assert.equal(f1["nome"], f2["nome"]);
  });

  test("com candidato real na faixa: o pareamento o escolhe", async () => {
    const { banco, dep } = await pronto();
    const lado = { cavaleiro: { forca: 50, precisao: 50, equilibrio: 50 }, cavalo: { velocidade: 50, folego: 50, temperamento: 50 },
      equipamento: { elmo: { defesa: 5, durabilidade: 100 } }, habilidades: ["bloqueio"] };
    const meu = (await agir(dep, "salvar_defesa", [])).corpo;
    assert.equal(meu["ok"], true);
    const poder_meu = banco.efeitos[banco.efeitos.length - 1].efeitos["defesa"]["poder"];
    banco.candidatos = [
      { jogador_id: OUTRO, nome: "Rival Real", pontos: 10, poder: poder_meu + 3, retrato: lado, aparencia: { principal: "verde_floresta", secundaria: "prata" }, brasao: {} },
      { jogador_id: "33333333-3333-4333-8333-333333333333", nome: "Forte Demais", pontos: 0, poder: poder_meu + 50, retrato: lado, aparencia: {}, brasao: {} },
    ];
    const r = await agir(dep, "procurar_adversario", []);
    const a = r.corpo["adversario"];
    assert.equal(a["simulado"], false);
    assert.equal(a["jogador_id"], OUTRO);
    assert.equal(a["nome"], "Rival Real");
    assert.deepEqual(a["casa"], { principal: "verde_floresta", secundaria: "prata" });
  });
});

describe("partida de PvP conferida", () => {
  async function preparar_partida(candidato: boolean) {
    const m = await pronto();
    const e = m.banco.estados.get(JOGADOR)!.estado;
    if (candidato) {
      const lado = { cavaleiro: { forca: 40, precisao: 40, equilibrio: 40 }, cavalo: { velocidade: 40, folego: 40, temperamento: 40 },
        equipamento: {}, habilidades: [] };
      m.banco.candidatos = [{ jogador_id: OUTRO, nome: "Rival Real", pontos: 0, poder: 1, retrato: lado, aparencia: {}, brasao: {} }];
      // o pareamento usa o poder real: iguala o do candidato ao do jogador
      m.banco.candidatos[0].poder = poder_jogador({ estado: e, bal, agora: () => 0 });
    }
    const r = await agir(m.dep, "procurar_adversario", []);
    assert.equal(r.corpo["ok"], true);
    const e2 = m.banco.estados.get(JOGADOR)!.estado;
    return { ...m, adversario: e2["liga"]["adversario"], estado: e2 };
  }

  function entradas_para(estado: Dados, adversario: Dados) {
    const cfg = { justa: bal("justa"), galope: bal("galope"), mira: bal("mira"), impacto: bal("impacto") };
    const perfil = bal("ia_rival")["perfis"][bal("economia")["ligas"]["fantasmas"]["perfil"]];
    return robo(cfg, lado_para_justa({ estado, bal, agora: () => 0 }), adversario["lado"], adversario["semente"], perfil);
  }

  test("o robô vence o fantasma: pontos, ouro e histórico; sem defensor real não há efeito de defensor", async () => {
    const { banco, dep, relogio, adversario, estado } = await preparar_partida(false);
    const entradas = entradas_para(estado, adversario);
    relogio.avancar(60);
    const ouro0 = estado["inventario"]["ouro"];
    const r = await agir(dep, "concluir_pvp_conferido", [entradas]);
    assert.equal(r.corpo["ok"], true, JSON.stringify(r.corpo).slice(0, 200));
    assert.equal(r.corpo["venceu"], true);
    assert.equal(r.corpo["pontos"], bal("economia")["ligas"]["vitoria"]);
    const e = banco.estados.get(JOGADOR)!.estado;
    assert.equal(e["liga"]["adversario"] && Object.keys(e["liga"]["adversario"]).length, 0);
    assert.equal(e["liga"]["partidas"].length, 1);
    assert.ok(e["inventario"]["ouro"] > ouro0);
    const ef = banco.efeitos[banco.efeitos.length - 1].efeitos;
    assert.equal("defensor" in ef, false);
    assert.equal("partida" in ef, false);
    assert.equal(ef["publico"]["pontos"], r.corpo["pontos"]);
  });

  test("contra jogador real: partida registrada; quando o atacante perde, o defensor ganha pontos", async () => {
    const { banco, dep, relogio } = await preparar_partida(true);
    relogio.avancar(60);
    // Sem tocar em nada o atacante perde a justa.
    const r = await agir(dep, "concluir_pvp_conferido", [[]]);
    assert.equal(r.corpo["ok"], true);
    assert.equal(r.corpo["venceu"], false);
    const ef = banco.efeitos[banco.efeitos.length - 1].efeitos;
    assert.deepEqual(ef["defensor"], { id: OUTRO, delta: bal("economia")["ligas"]["defesa_vencida"] });
    assert.equal(ef["partida"]["defensor_id"], OUTRO);
    assert.equal(ef["partida"]["venceu"], false);
    assert.ok(Number.isInteger(ef["partida"]["semente"]));
  });

  test("rápido demais, sem adversário e entradas impossíveis são recusados", async () => {
    const { banco, dep, relogio } = await preparar_partida(false);
    const r1 = await agir(dep, "concluir_pvp_conferido", [[]]);
    assert.equal(r1.corpo["erro"], "tempo_impossivel");
    relogio.avancar(60);
    const r2 = await agir(dep, "concluir_pvp_conferido", [[[100, "tocar", 0, 0], [110, "tocar", 0, 0]]]);
    assert.equal(r2.corpo["erro"], "toques_impossiveis");
    const ok = await agir(dep, "concluir_pvp_conferido", [[]]);
    assert.equal(ok.corpo["ok"], true);
    const de_novo = await agir(dep, "concluir_pvp_conferido", [[]]);
    assert.equal(de_novo.corpo["erro"], "sem_adversario");
    assert.equal(banco.estados.get(JOGADOR)!.estado["liga"]["partidas"].length, 1);
  });
});

describe("temporada global", () => {
  test("a grade é a mesma para todos e muda a cada temporada_dias", () => {
    const s: Servico = { estado: {}, bal, agora: () => 0 };
    const epoca = bal("servidor")["temporadas"]["epoca"];
    const dur = bal("economia")["ligas"]["temporada_dias"] * 86400;
    s.agora = () => epoca + 5;
    assert.deepEqual(temporada_atual(s), { numero: 1, inicio: epoca, fim: epoca + dur });
    s.agora = () => epoca + dur;
    assert.equal(temporada_atual(s).numero, 2);
    s.agora = () => epoca + 3 * dur + 10;
    assert.equal(temporada_atual(s).numero, 4);
    s.agora = () => epoca - 1000; // antes da época: temporada 1
    assert.equal(temporada_atual(s).numero, 1);
  });

  test("virar a temporada dá o baú pela liga e reinicia os pontos pela metade (na próxima ação de PvP)", async () => {
    const { banco, dep, relogio } = await pronto();
    const e = banco.estados.get(JOGADOR)!.estado;
    const epoca = bal("servidor")["temporadas"]["epoca"];
    const dur = bal("economia")["ligas"]["temporada_dias"] * 86400;
    relogio.ir_para(epoca + 10);
    e["liga"]["temporada"] = 1;
    e["liga"]["pontos"] = 340; // prata
    const r1 = await agir(dep, "salvar_defesa", []);
    assert.equal(r1.corpo["ok"], true);
    assert.equal(banco.estados.get(JOGADOR)!.estado["liga"]["pontos"], 340, "ainda na mesma temporada");
    relogio.ir_para(epoca + 2 * dur + 5); // duas temporadas depois
    const r2 = await agir(dep, "salvar_defesa", []);
    assert.equal(r2.corpo["ok"], true);
    const e2 = banco.estados.get(JOGADOR)!.estado;
    assert.equal(e2["liga"]["temporada"], 3);
    assert.equal(e2["liga"]["temporada_inicio"], epoca + 2 * dur);
    // 340 -> 170 -> 85 (reinicio de 50% a cada temporada que passou)
    assert.equal(e2["liga"]["pontos"], 85);
    assert.equal(e2["baus"]["espacos"].length, 2, "um baú por temporada que fechou");
    assert.equal(e2["baus"]["espacos"][0]["tipo"], "ferro", "prata e bronze dão baú de ferro");
  });
});
