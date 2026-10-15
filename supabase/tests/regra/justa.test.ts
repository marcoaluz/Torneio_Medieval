// IA do rival e justa completa: o TypeScript tem que reproduzir, evento por
// evento, as gravações feitas pelo GDScript (tests/shared/justa_referencia.json
// e justa_referencia_ia.json). Se algum teste daqui falhar, as duas versões da
// regra divergiram: o servidor não pode conferir justas até voltar a bater.

import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { IaRival, centro_da_zona, semente_da_justa, validar as validar_ia } from "../../functions/_shared/regra/ia_rival.ts";
import { Justa, validar as validar_justa } from "../../functions/_shared/regra/justa.ts";
import { carregar_casos, carregar_dados, evento_para_texto, normalizar } from "./comum.ts";
import type { Dados } from "./comum.ts";

describe("IA do rival", () => {
  const dados = carregar_casos("ia_rival");
  const cfg_ia = dados["config_ia"];
  const cfg_mira = dados["config_mira"];

  test("config embutida e dados do jogo validos", () => {
    assert.equal(validar_ia(cfg_ia), "");
    assert.equal(validar_ia(carregar_dados("balance/ia_rival.json")), "");
  });
  for (const z of Object.keys(dados["centros"])) {
    test(`centro de ${z}`, () => {
      const c = centro_da_zona(cfg_mira, z);
      assert.deepEqual([c.x, c.y], dados["centros"][z].map((n: number) => Math.trunc(n)));
    });
  }
  for (const caso of dados["casos"]) {
    test(`${caso["perfil"]} semente ${caso["semente_justa"]}`, () => {
      assert.equal(semente_da_justa(Math.trunc(caso["semente_justa"])), Math.trunc(caso["semente_ia"]));
      const ia = new IaRival(cfg_ia["perfis"][caso["perfil"]], Math.trunc(caso["semente_ia"]));
      const obtido = [];
      for (let i = 0; i < caso["passadas"].length; i++) {
        const r = ia.reacao_largada_ms();
        const g = ia.plano_galope(500, 6000);
        const m = ia.ponto_mira(cfg_mira);
        obtido.push({ reacao_ms: r, galope: g, mira: [m.x, m.y] });
      }
      assert.equal(normalizar(obtido), normalizar(caso["passadas"]));
    });
  }
});

/** Repete a gravação: avança até cada entrada [t, acao, x, y] e aplica; vai até o fim. */
function repetir(j: Justa, entradas: [number, string, number, number][], pedaco: number): string[] {
  const eventos: string[] = [];
  const anotar = (evs: Dados[]) => evs.forEach((e) => eventos.push(evento_para_texto(e)));
  anotar(j.iniciar());
  for (const e of [...entradas, [2 ** 40, "fim", 0, 0] as [number, string, number, number]]) {
    const t = Math.trunc(e[0]);
    while (j.fases.tempo_total_ms < t && !j.terminou()) {
      const falta = t - j.fases.tempo_total_ms;
      anotar(j.avancar(pedaco <= 0 ? falta : Math.min(pedaco, falta)));
    }
    if (j.terminou()) break;
    switch (e[1]) {
      case "tocar": anotar(j.tocar()); break;
      case "mirar": j.mirar({ x: Math.trunc(e[2]), y: Math.trunc(e[3]) }); break;
      case "soltar": anotar(j.soltar()); break;
      case "habilidade": anotar(j.ativar_habilidade()); break;
      case "rival_mirar": j.rival_mirar({ x: Math.trunc(e[2]), y: Math.trunc(e[3]) }); break;
    }
  }
  return eventos;
}

describe("justa completa (gravações do GDScript)", () => {
  test("sem IA: equipamento, habilidades e rival mirando", () => {
    const g = carregar_casos("justa_referencia");
    assert.equal(validar_justa(g["config"]), "");
    for (const pedaco of [0, 1, 33]) {
      const j = new Justa(g["config"], g["lado_jogador"], g["lado_rival"], Math.trunc(g["semente"]));
      assert.deepEqual(repetir(j, g["entradas"], pedaco), g["eventos"], `pedaco ${pedaco}`);
    }
  });

  test("com IA: perfil agressivo", () => {
    const g = carregar_casos("justa_referencia_ia");
    for (const pedaco of [0, 17]) {
      const j = new Justa(g["config"], g["lado_jogador"], g["lado_rival"], Math.trunc(g["semente"]), g["perfil"]);
      assert.deepEqual(repetir(j, g["entradas"], pedaco), g["eventos"], `pedaco ${pedaco}`);
    }
  });

  test("dados do jogo validos juntos", () => {
    const cfg = {
      justa: carregar_dados("balance/justa.json"), galope: carregar_dados("balance/galope.json"),
      mira: carregar_dados("balance/mira.json"), impacto: carregar_dados("balance/impacto.json"),
    };
    assert.equal(validar_justa(cfg), "");
  });
});

describe("habilidade de precisão (tests/shared/habilidade_precisao.json)", () => {
  const dados = carregar_casos("habilidade_precisao");
  const base = carregar_casos("justa_referencia");
  const cfg = JSON.parse(JSON.stringify(base["config"]));
  Object.assign(cfg["impacto"]["habilidades"], dados["habilidades"]);
  cfg["galope"]["largada"]["bonus_precisao_pct"] = dados["largada_bonus_precisao_pct"];
  test("config com as habilidades novas valida", () => assert.equal(validar_justa(cfg), ""));
  for (const c of dados["casos"]) {
    test(c["nome"], () => {
      const lj = JSON.parse(JSON.stringify(base["lado_jogador"]));
      const lr = JSON.parse(JSON.stringify(base["lado_rival"]));
      lj["habilidades"] = c["habilidades_jogador"];
      lr["habilidades"] = c["habilidades_rival"];
      const j = new Justa(cfg, lj, lr, Math.trunc(base["semente"]));
      j.qualidade_largada = c["largada_jogador"];
      assert.equal(j.bonus_precisao_pct(), Math.trunc(c["esperado_jogador"]));
      assert.equal(j.precisao_de_habilidades(lr), Math.trunc(c["esperado_rival"]));
    });
  }
});
