// Regras puras do PvE (GDD Disputas PvE). Porte de game/scripts/rules/pve.gd;
// casos dos desafios em tests/shared/desafios_pve.json.

import { Lado } from "./justa_fases.ts";
import type { Evento } from "./justa_fases.ts";
import { Justa } from "./justa.ts";
import { ERRO } from "./mira.ts";
import { copiar, tem } from "./util.ts";

// deno-lint-ignore no-explicit-any
type Dados = Record<string, any>;

/** Estrelas de uma disputa a partir dos eventos da Justa (0 se não venceu; 1 + sem errar + derrubada). */
export function estrelas(eventos: Evento[]): number {
  let venceu = false;
  let derrubada = false;
  let errou = false;
  for (const e of eventos) {
    if (e["tipo"] === "impacto") {
      const g = e["jogador"];
      if (g["zona"] === ERRO || g["falta"]) errou = true;
    } else if (e["tipo"] === "fim") {
      venceu = e["vencedor"] === Lado.JOGADOR;
      derrubada = e["motivo"] === "derrubada";
    }
  }
  if (!venceu) return 0;
  return 1 + (errou ? 0 : 1) + (derrubada ? 1 : 0);
}

/** Joga a justa inteira sem ninguém tocar: o jogador também é uma IA. Devolve {eventos, equipamento_final}. */
export function simular(cfg: Dados, lado_j: Dados, lado_r: Dados, semente: number, perfil_rival: Dados, perfil_jogador: Dados): Dados {
  const j = new Justa(cfg, lado_j, lado_r, semente, perfil_rival, perfil_jogador);
  const eventos: Evento[] = j.iniciar();
  let guarda = 0;
  while (!j.terminou() && guarda < 1000) {
    eventos.push(...j.avancar(1000));
    guarda += 1;
  }
  return { eventos, equipamento_final: j.equipamento_final(true) };
}

/** Desafios especiais de um torneio, aplicados antes da justa. Devolve cópias {cfg, lado_jogador, lado_rival, perfil_rival}. */
export function aplicar_desafios(cfg: Dados, lado_j: Dados, lado_r: Dados, perfil_r: Dados, ids: string[], defs: Dados): Dados {
  const c = copiar(cfg);
  const j = copiar(lado_j);
  const r = copiar(lado_r);
  const p = copiar(perfil_r);
  for (const id of ids) {
    const d = defs[id];
    if (tem(d, "cavalo")) j["cavalo"] = copiar(d["cavalo"]);
    for (const peca of (d["remover_pecas"] ?? []) as string[]) {
      if (typeof j["equipamento"] === "object" && j["equipamento"] !== null) delete j["equipamento"][peca];
      if (d["ambos"] ?? false) {
        if (typeof r["equipamento"] === "object" && r["equipamento"] !== null) delete r["equipamento"][peca];
      }
    }
    if (tem(d, "galope_janela_pct")) {
      const g = c["galope"]["galope"];
      const pct = Math.trunc(d["galope_janela_pct"]);
      for (const k of ["janela_base_ms", "janela_por_temperamento_milesimos", "janela_max_ms"]) {
        g[k] = Math.trunc(Math.trunc(g[k]) * pct / 100);
      }
    }
    if (tem(d, "mira_oscilacao_pct")) {
      const o = c["mira"]["oscilacao"];
      o["amplitude_px"] = Math.trunc(Math.trunc(o["amplitude_px"]) * Math.trunc(d["mira_oscilacao_pct"]) / 100);
    }
    if (tem(d, "ia_erro_mira_pct") && tem(p, "erro_mira_px")) {
      p["erro_mira_px"] = Math.trunc(Math.trunc(p["erro_mira_px"]) * Math.trunc(d["ia_erro_mira_pct"]) / 100);
    }
  }
  return { cfg: c, lado_jogador: j, lado_rival: r, perfil_rival: p };
}

/** Estilo de um campeão: o ajuste soma nos números do perfil da IA (sem passar de zero) e troca os textos. */
/** Perfil da IA de um rival do PvE: o do perfil, mais ajuste_campeao se for campeão, mais o perfil_ajuste dele. */
export function perfil_do_rival(ia: Dados, r: Dados): Dados {
  let p: Dados = ia["perfis"][r["perfil"]];
  if (r["campeao"] ?? false) p = ajustar_perfil(p, ia["ajuste_campeao"]);
  return ajustar_perfil(p, r["perfil_ajuste"] ?? {});
}

export function ajustar_perfil(perfil: Dados, ajuste: Dados): Dados {
  const p = copiar(perfil);
  for (const k of Object.keys(ajuste)) {
    if (k.startsWith("_")) continue; // nota
    if (typeof ajuste[k] === "number" && tem(p, k) && typeof p[k] === "number") {
      p[k] = Math.max(0, Math.trunc(p[k]) + Math.trunc(ajuste[k]));
    } else {
      p[k] = ajuste[k];
    }
  }
  return p;
}
