// PvE no servidor (3.2/3.4): progresso dos torneios, preparação da disputa e
// conclusão pelos EVENTOS que o servidor mesmo calculou (nunca os do cliente).
// Porte da seção "PvE" de game/scripts/services/servico_jogador.gd.

import * as Pve from "../regra/pve.ts";
import { concluir, copiar, div, erro, inteiro, tem } from "./base.ts";
import type { Dados, Resultado, Servico } from "./base.ts";
import {
  _evento, _evento_maximo, bonus_companheiros, cfg_baus, derrota_por_pouco, disparar_oferta, ganhar, guardar_bau, guardar_vitoria,
  lado_para_justa, registrar_justa, renome, sorteio_milesimos,
} from "./jogador.ts";

export function pve(s: Servico): Dados {
  return s.bal("pve");
}

export function progresso_torneio(s: Servico, id: string): Dados {
  const t = s.estado["pve"]["torneios"][id] ?? {};
  return {
    proxima: inteiro(t["proxima"] ?? 0), concluido: t["concluido"] ?? false,
    estrelas: copiar(t["estrelas"] ?? {}), falhou: t["falhou"] ?? false,
  };
}

export function regiao_do_torneio(s: Servico, id: string): string {
  const dados = pve(s);
  for (const r of dados["ordem_regioes"] as string[]) {
    if ((dados["regioes"][r]["torneios"] as string[]).includes(id)) return r;
  }
  return "";
}

export function regioes_liberadas(s: Servico): string[] {
  const ordem: string[] = pve(s)["ordem_regioes"];
  return ordem.slice(0, ordem.indexOf(s.estado["pve"]["regiao"]) + 1);
}

export function regiao_liberada(s: Servico, regiao: string): boolean {
  return regioes_liberadas(s).includes(regiao);
}

export function desafios_do_torneio(s: Servico, id: string): string[] {
  return [...((pve(s)["torneios"][id] ?? {})["desafios"] ?? [])];
}

/** Último torneio obrigatório da região: vencê-lo fecha a região. */
export function torneio_final_da_regiao(s: Servico, regiao: string): string {
  const dados = pve(s);
  const lista: string[] = dados["regioes"][regiao]["torneios"];
  for (let i = lista.length - 1; i >= 0; i--) {
    if (!(dados["torneios"][lista[i]]["opcional"] ?? false)) return lista[i];
  }
  return "";
}

export function torneio_liberado(s: Servico, id: string): boolean {
  const dados = pve(s);
  const t = dados["torneios"][id] ?? {};
  const regiao = regiao_do_torneio(s, id);
  if (Object.keys(t).length === 0 || regiao === "" || !regiao_liberada(s, regiao) ||
    inteiro(s.estado["cavaleiro"]["nivel"]) < inteiro(t["nivel_minimo"])) return false;
  if (renome(s) < inteiro(t["renome_minimo"] ?? 0)) return false;
  for (const anterior of dados["regioes"][regiao]["torneios"] as string[]) {
    if (anterior === id) return true;
    if (!(dados["torneios"][anterior]["opcional"] ?? false) && !progresso_torneio(s, anterior)["concluido"]) return false;
  }
  return true;
}

export function uma_chance(s: Servico, torneio: string): boolean {
  const defs = pve(s)["desafios"] ?? {};
  for (const d of desafios_do_torneio(s, torneio)) {
    if (inteiro((defs[d] ?? {})["tentativas"] ?? 0) === 1) return true;
  }
  return false;
}

export function pode_disputar(s: Servico, torneio: string, indice: number): Resultado {
  if (!torneio_liberado(s, torneio)) return erro("torneio_bloqueado");
  const rivais: string[] = pve(s)["torneios"][torneio]["rivais"];
  if (indice < 0 || indice >= rivais.length) return erro("disputa_inexistente");
  const prog = progresso_torneio(s, torneio);
  if (indice > prog["proxima"]) return erro("disputa_bloqueada");
  if (uma_chance(s, torneio) && (prog["falhou"] || prog["concluido"] || indice < prog["proxima"])) return erro("chance_perdida");
  return concluir();
}

export function pode_automatico(s: Servico, torneio: string, indice: number): Resultado {
  const p = pode_disputar(s, torneio, indice);
  if (!p.ok) return p;
  const dados = pve(s);
  const rival: string = dados["torneios"][torneio]["rivais"][indice];
  if (dados["rivais"][rival]["campeao"] ?? false) return erro("campeao_manual");
  if (inteiro(progresso_torneio(s, torneio)["estrelas"][String(indice)] ?? 0) < 3) return erro("precisa_tres_estrelas");
  return concluir();
}

/** Tudo que a justa precisa do rival: {lado, perfil, ...}. O nêmesis cresce a cada encontro. */
export function rival_para_justa(s: Servico, rival_id: string, regiao = ""): Dados {
  return rival_de(s, pve(s)["rivais"][rival_id], rival_id, regiao);
}

export function rival_de(s: Servico, r: Dados, rival_id: string, regiao = ""): Dados {
  if (regiao !== "" && tem(r["por_regiao"] ?? {}, regiao)) {
    r = { ...r, ...r["por_regiao"][regiao] };
  }
  const modelos = s.bal("itens")["modelos"];
  let bonus = inteiro(r["cresce_por_encontro"] ?? 0) * inteiro((s.estado["pve"]["encontros"] ?? {})[rival_id] ?? 0);
  if (tem(r, "cresce_max")) bonus = Math.min(bonus, inteiro(r["cresce_max"]));
  const cav: Dados = {};
  for (const k of Object.keys(r["cavaleiro"])) cav[k] = Math.min(inteiro(r["cavaleiro"][k]) + bonus, 100);
  const equip: Dados = {};
  for (const m of r["equipamento"] as string[]) {
    const st = copiar(modelos[m]["status"]);
    st["durabilidade"] = inteiro(modelos[m]["durabilidade_max"]);
    equip[modelos[m]["espaco"]] = st;
  }
  const lado = { cavaleiro: cav, cavalo: copiar(r["cavalo"]), equipamento: equip, habilidade: r["habilidade"] ?? "" };
  const perfil = Pve.ajustar_perfil(s.bal("ia_rival")["perfis"][r["perfil"]], r["perfil_ajuste"] ?? {});
  return {
    id: rival_id, lado, perfil_nome: r["perfil"], perfil, provocacao: r["provocacao"] ?? "",
    casa: { principal: r["casa"][0], secundaria: r["casa"][1] },
    nome_chave: "RIVAL_" + rival_id.toUpperCase(), nemesis: r["nemesis"] ?? false, campeao: r["campeao"] ?? false,
  };
}

export function configuracao_justa(s: Servico): Dados {
  return { justa: s.bal("justa"), galope: s.bal("galope"), mira: s.bal("mira"), impacto: s.bal("impacto") };
}

/** Tudo para jogar uma disputa, com os desafios do torneio já aplicados. */
export function preparar_disputa(s: Servico, torneio: string, indice: number): Dados {
  const dados = pve(s);
  const rv = rival_para_justa(s, dados["torneios"][torneio]["rivais"][indice], regiao_do_torneio(s, torneio));
  const ids = desafios_do_torneio(s, torneio);
  const defs: Dados = dados["desafios"] ?? {};
  const a = Pve.aplicar_desafios(configuracao_justa(s), lado_para_justa(s), rv["lado"], rv["perfil"], ids, defs);
  rv["lado"] = a["lado_rival"];
  rv["perfil"] = a["perfil_rival"];
  const visuais: string[] = [];
  let gasta = true;
  for (const id of ids) {
    if (tem(defs[id], "visual")) visuais.push(defs[id]["visual"]);
    if (!(defs[id]["gasta_folego"] ?? true)) gasta = false;
  }
  return { cfg: a["cfg"], lado_jogador: a["lado_jogador"], rival: rv, desafios: ids, visuais, gasta_folego: gasta };
}

/**
 * Fim de uma disputa, a partir dos eventos da justa: estrelas, avanço na chave,
 * recompensas, baús, materiais, renome, XP e nível. No servidor os eventos vêm
 * da repetição da justa pela regra em TypeScript, nunca do cliente.
 */
export function concluir_disputa(s: Servico, torneio: string, indice: number, eventos: Dados[], automatico = false): Resultado {
  const p = pode_disputar(s, torneio, indice);
  if (!p.ok) return p;
  const dados = pve(s);
  const t = dados["torneios"][torneio];
  const rival: string = t["rivais"][indice];
  const est = Pve.estrelas(eventos);
  const reg: Dados = s.estado["pve"]["torneios"][torneio] ?? { proxima: 0, concluido: false, estrelas: {} };
  s.estado["pve"]["torneios"][torneio] = reg;
  const enc: Dados = s.estado["pve"]["encontros"] ?? {};
  enc[rival] = inteiro(enc[rival] ?? 0) + 1;
  s.estado["pve"]["encontros"] = enc;
  let ouro_g = 0;
  let xp_g = 0;
  let fechou = false;
  const regiao = regiao_do_torneio(s, torneio);
  const pct = inteiro(dados["regioes"][regiao]["recompensa_pct"] ?? 100);
  let projeto = "";
  let regiao_nova = "";
  if (est === 0 && uma_chance(s, torneio)) reg["falhou"] = true;
  const baus_ganhos: Dados[] = [];
  const estrelas_antes = inteiro(reg["estrelas"][String(indice)] ?? 0);
  if (est > 0) {
    const r = dados["recompensa_disputa"];
    ouro_g = div((inteiro(r["ouro_base"]) + est * inteiro(r["ouro_por_estrela"])) * pct, 100);
    xp_g = div((inteiro(r["xp_base"]) + est * inteiro(r["xp_por_estrela"])) * pct, 100);
    if (automatico) {
      ouro_g = div(ouro_g * inteiro(dados["recompensa_automatico_pct"]), 100);
      xp_g = div(xp_g * inteiro(dados["recompensa_automatico_pct"]), 100);
    }
    reg["estrelas"][String(indice)] = Math.max(inteiro(reg["estrelas"][String(indice)] ?? 0), est);
    if (indice === inteiro(reg["proxima"])) {
      reg["proxima"] = indice + 1;
      if (inteiro(reg["proxima"]) >= (t["rivais"] as string[]).length && !reg["concluido"]) {
        reg["concluido"] = true;
        fechou = true;
        ouro_g += inteiro(t["recompensa"]["ouro"]);
        xp_g += inteiro(t["recompensa"]["xp"]);
        if (torneio === torneio_final_da_regiao(s, regiao)) {
          projeto = String((dados["regioes"][regiao]["recompensa_regiao"] ?? {})["projeto"] ?? "");
          const projetos: string[] = s.estado["inventario"]["projetos"];
          if (projeto !== "" && !projetos.includes(projeto)) projetos.push(projeto);
          const ordem: string[] = dados["ordem_regioes"];
          const i = ordem.indexOf(regiao);
          if (i + 1 < ordem.length && s.estado["pve"]["regiao"] === regiao) {
            regiao_nova = ordem[i + 1];
            s.estado["pve"]["regiao"] = regiao_nova;
          }
        }
      }
    }
  }
  // Baús: ferro na primeira vez que a disputa chega a 3 estrelas, senão chance
  // de madeira; ouro ao vencer um campeão.
  if (est > 0) {
    const cb = cfg_baus(s);
    if (est >= 3 && estrelas_antes < 3 && cb["ferro_por_tres_estrelas"]) {
      baus_ganhos.push(guardar_bau(s, "ferro"));
    } else if (sorteio_milesimos(s, Math.round(Number(cb["chance_madeira_por_vitoria"]) * 1000.0))) {
      baus_ganhos.push(guardar_bau(s, "madeira"));
    }
    if ((dados["rivais"][rival]["campeao"] ?? false) && cb["ouro_por_campeao"] && estrelas_antes === 0) {
      baus_ganhos.push(guardar_bau(s, "ouro"));
    }
  }
  // Materiais: por vitória (no automático, a mesma porcentagem do ouro) e os da região ao fechá-la.
  const mats_g: Dados = {};
  if (est > 0) {
    const mv: Dados = dados["regioes"][regiao]["materiais_vitoria"] ?? {};
    for (const m of Object.keys(mv)) {
      const q = div(inteiro(mv[m]) * (automatico ? inteiro(dados["recompensa_automatico_pct"]) : 100), 100);
      if (q > 0) mats_g[m] = q;
    }
  }
  if (projeto !== "") {
    const mr: Dados = (dados["regioes"][regiao]["recompensa_regiao"] ?? {})["materiais"] ?? {};
    for (const m of Object.keys(mr)) mats_g[m] = inteiro(mats_g[m] ?? 0) + inteiro(mr[m]);
  }
  const inv_mats = s.estado["inventario"]["materiais"];
  for (const m of Object.keys(mats_g)) inv_mats[m] = inteiro(inv_mats[m] ?? 0) + inteiro(mats_g[m]);
  // Metas: eventos para missões e conquistas, renome e sequência.
  const metas = s.estado["metas"];
  let renome_g = 0;
  const ganho = s.bal("metas")["renome"]["ganho"];
  if (est > 0) {
    _evento(s, "vitoria");
    renome_g += inteiro(ganho["vitoria"]);
    metas["sequencia"] = inteiro(metas["sequencia"]) + 1;
    _evento_maximo(s, "sequencia", inteiro(metas["sequencia"]));
    if (est >= 3) {
      _evento(s, "tres_estrelas");
      renome_g += inteiro(ganho["tres_estrelas"]);
    }
    for (const e of eventos) {
      if ((e["tipo"] ?? "") === "fim" && (e["motivo"] ?? "") === "derrubada") {
        _evento(s, "derrubada");
        renome_g += inteiro(ganho["derrubada"]);
      }
    }
    if ((dados["rivais"][rival]["campeao"] ?? false) && estrelas_antes === 0) renome_g += inteiro(ganho["campeao"]);
  } else {
    metas["sequencia"] = 0;
    if (derrota_por_pouco(s, eventos)) disparar_oferta(s, "derrota_por_pouco");
  }
  if (fechou) _evento(s, "torneio_vencido");
  if (projeto !== "") {
    _evento(s, "regiao_vencida");
    renome_g += inteiro(ganho["regiao_vencida"]);
  }
  renome_g = div(renome_g * (100 + bonus_companheiros(s, "renome_pct")), 100);
  metas["renome"] = inteiro(metas["renome"]) + renome_g;
  if (est > 0 && ouro_g > 0) guardar_vitoria(s, ouro_g);
  const niveis = ganhar(s, ouro_g, xp_g);
  return {
    ...concluir(), estrelas: est, ouro: ouro_g, xp: xp_g, niveis, torneio_concluido: fechou, venceu: est > 0,
    projeto, regiao_nova, baus: baus_ganhos, materiais: mats_g, renome: renome_g,
  };
}

/** Disputa no automático: a mesma regra, com uma IA de precisão média no lugar do jogador. */
export function disputa_automatica(s: Servico, torneio: string, indice: number, semente: number): Resultado {
  const p = pode_automatico(s, torneio, indice);
  if (!p.ok) return p;
  const dados = pve(s);
  const prep = preparar_disputa(s, torneio, indice);
  const perfil_auto = s.bal("ia_rival")["perfis"][dados["perfil_automatico"]];
  const sim = Pve.simular(prep["cfg"], prep["lado_jogador"], prep["rival"]["lado"], semente, prep["rival"]["perfil"], perfil_auto);
  registrar_justa(s, { equipamento_final: sim["equipamento_final"], gasta_folego: prep["gasta_folego"] });
  const r = concluir_disputa(s, torneio, indice, sim["eventos"], true);
  r["eventos"] = sim["eventos"];
  return r;
}

export function rival_tutorial(s: Servico): Dados {
  return rival_de(s, s.bal("inicio")["tutorial"]["rival_primeira_justa"], "tutorial");
}
