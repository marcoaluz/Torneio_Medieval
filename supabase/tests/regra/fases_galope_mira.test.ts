// Casos compartilhados: fases da justa, gerador, largada e galope, mira.
// Mesmos arquivos de tests/shared/ que os testes do GDScript.

import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { Aleatorio } from "../../functions/_shared/regra/aleatorio.ts";
import { JustaFases, NOMES_FASE, NOMES_LADO } from "../../functions/_shared/regra/justa_fases.ts";
import type { Evento } from "../../functions/_shared/regra/justa_fases.ts";
import { Galope } from "../../functions/_shared/regra/galope.ts";
import * as Mira from "../../functions/_shared/regra/mira.ts";
import { carregar_casos, carregar_dados } from "./comum.ts";

describe("gerador Aleatorio (xorshift32)", () => {
  const dados = carregar_casos("galope");
  for (const v of dados["aleatorio"]) {
    test(`semente ${v["semente"]}`, () => {
      const r = new Aleatorio(v["semente"]);
      const obtidos = v["primeiros"].map(() => r.proximo());
      assert.deepEqual(obtidos, v["primeiros"].map((x: number) => Math.trunc(x)));
    });
  }
});

describe("fases da justa", () => {
  const dados = carregar_casos("justa_fases");

  function anotar(saida: string[], eventos: Evento[]) {
    for (const e of eventos) {
      if (e["tipo"] === "fase") {
        saida.push(`fase:${NOMES_FASE[e["fase"]]}:${e["passada"]}@${e["t"]}`);
      } else if (e["tipo"] === "passada") {
        saida.push(`passada:${e["passada"]}:${e["pontos_jogador"]}-${e["pontos_rival"]}:${NOMES_LADO[e["derrubado"]]}:${NOMES_LADO[e["desclassificado"]]}@${e["t"]}`);
      } else if (e["tipo"] === "fim") {
        saida.push(`fim:${NOMES_LADO[e["vencedor"]]}:${e["motivo"]}:${e["placar_jogador"]}-${e["placar_rival"]}@${e["t"]}`);
      }
    }
  }

  // pedaco = 0: aplica cada avanço inteiro; > 0: pica o avanço em pedaços.
  // deno-lint-ignore no-explicit-any
  function rodar(cfg: any, acoes: any[], pedaco: number): string[] {
    const j = new JustaFases(cfg);
    const saida: string[] = [];
    anotar(saida, j.iniciar());
    for (const a of acoes) {
      switch (a["acao"]) {
        case "avancar": {
          let ms = Math.trunc(a["ms"]);
          if (pedaco <= 0) {
            anotar(saida, j.avancar(ms));
          } else {
            while (ms > 0) {
              const p = Math.min(pedaco, ms);
              anotar(saida, j.avancar(p));
              ms -= p;
            }
          }
          break;
        }
        case "pular":
          anotar(saida, j.pular());
          break;
        case "encerrar_corrida":
          anotar(saida, j.encerrar_corrida());
          break;
        case "resultado":
          j.registrar_resultado(
            Math.trunc(a["jogador"]), Math.trunc(a["rival"]),
            NOMES_LADO.indexOf(a["derrubado"] ?? "nenhum"), NOMES_LADO.indexOf(a["desclassificado"] ?? "nenhum"));
          break;
      }
    }
    return saida;
  }

  for (const caso of dados["casos"]) {
    test(caso["nome"], () => {
      const cfg = { ...dados["config_base"], ...(caso["config"] ?? {}) };
      assert.equal(JustaFases.validar(cfg), "");
      assert.deepEqual(rodar(cfg, caso["acoes"], 0), caso["esperado"]);
      assert.deepEqual(rodar(cfg, caso["acoes"], 17), caso["esperado"], "picado em 17 ms");
    });
  }

  test("dados do jogo validos e configuracao ruim recusada", () => {
    assert.equal(JustaFases.validar(carregar_dados("balance/justa.json")), "");
    assert.notEqual(JustaFases.validar({ passadas: 3, passadas_extras_max: 1 }), "");
    const ruim = structuredClone(dados["config_base"]);
    ruim["fases_ms"]["mira"] = 1.5;
    assert.notEqual(JustaFases.validar(ruim), "");
    delete ruim["fases_ms"]["mira"];
    assert.notEqual(JustaFases.validar(ruim), "");
  });
});

describe("largada e galope", () => {
  const dados = carregar_casos("galope");
  const cfg = dados["config"];

  test("config embutida e dados do jogo validos", () => {
    assert.equal(Galope.validar(cfg), "");
    assert.equal(Galope.validar(carregar_dados("balance/galope.json")), "");
  });

  for (const l of dados["largada"]) {
    test(`largada tocou=${l["tocou"]} reacao=${l["reacao_ms"]} -> ${l["esperado"]}`, () => {
      assert.equal(Galope.avaliar_largada(cfg, l["tocou"], Math.trunc(l["reacao_ms"])), l["esperado"]);
    });
  }

  // deno-lint-ignore no-explicit-any
  function fmt(e: any, g: Galope): string {
    return `${e.resultado}:${e.batida}:${e.desvio_ms}:v${g.velocidade}:f${g.folego}@${g.t_ms}`;
  }

  for (const caso of dados["casos"]) {
    test(caso["nome"], () => {
      const g = new Galope(cfg, caso["cavalo"]);
      const ev = [`inicio:nominal${g.velocidade_nominal}:janela${g.janela_ms}:folego${g.folego_max}`];
      for (const a of caso["acoes"]) {
        switch (a[0]) {
          case "passada":
            g.nova_passada(a[1]);
            ev.push(`passada:${a[1]}:v${g.velocidade}:f${g.folego}`);
            break;
          case "avancar":
            for (let i = 0; i < Math.trunc(a[1]); i++) {
              const e = g.avancar_1ms();
              if (e) ev.push(fmt(e, g));
            }
            break;
          case "tocar":
            ev.push(fmt(g.tocar(), g));
            break;
        }
      }
      ev.push(`fim:d${g.distancia_mil}:ritmo${g.ritmo_milesimos()}`);
      assert.deepEqual(ev, caso["esperado"]);
    });
  }
});

describe("mira", () => {
  const dados = carregar_casos("mira");
  const cfg = dados["config"];

  test("config embutida e dados do jogo validos", () => {
    assert.equal(Mira.validar(cfg), "");
    assert.equal(Mira.validar(carregar_dados("balance/mira.json")), "");
  });
  for (const c of dados["crescimento"]) {
    test(`crescimento precisao ${c["precisao"]} bonus ${c["bonus"]}`, () => {
      assert.equal(Mira.crescimento_pct(cfg, Math.trunc(c["precisao"]), Math.trunc(c["bonus"])), Math.trunc(c["esperado"]));
    });
  }
  for (const z of dados["zonas"]) {
    test(`zona: ${z["nome"]}`, () => {
      const obtida = Mira.zona_no_ponto(cfg, { x: Math.trunc(z["x"]), y: Math.trunc(z["y"]) }, Math.trunc(z["precisao"]), Math.trunc(z["bonus"]));
      assert.equal(obtida, z["esperado"]);
    });
  }
  for (const l of dados["limites"]) {
    test(`limitar (${l["x"]},${l["y"]})`, () => {
      const p = Mira.limitar(cfg, { x: Math.trunc(l["x"]), y: Math.trunc(l["y"]) });
      assert.deepEqual([p.x, p.y], l["esperado"].map((n: number) => Math.trunc(n)));
    });
  }
});
