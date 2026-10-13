// PvP assíncrono e ligas no servidor (3.5/3.6). Porte do que o ServicoJogador
// fazia SIMULADO no aparelho (fantasmas, defesas, temporada) para o modo real:
//  - a defesa do jogador é um retrato guardado no banco (lado da justa);
//  - o adversário vem de outros jogadores reais, pareados pela regra
//    (RegraLiga.parear), ou de um fantasma do servidor quando ninguém serve;
//  - a partida é jogada pelo atacante contra a IA do retrato e CONFERIDA aqui
//    (a justa é refeita com as entradas e a semente do servidor);
//  - a temporada é global (mesma grade para todos): cada jogador vira a dele
//    de forma preguiçosa, na próxima ação.
// Efeitos relacionais (ranking, defensor, registro da partida) saem em
// `resultado._efeitos` e são gravados na mesma transação do estado.

import { Aleatorio } from "../regra/aleatorio.ts";
import * as Liga from "../regra/liga.ts";
import * as Forja from "../regra/forja.ts";
import * as Pve from "../regra/pve.ts";
import { concluir, copiar, div, erro, inteiro, semente_servico } from "./base.ts";
import type { Dados, Resultado, Servico } from "./base.ts";
import { configuracao_justa } from "./pve.ts";
import {
  _evento, cfg_baus, dar_recompensa, derrota_por_pouco, disparar_oferta, ganhar, guardar_bau, guardar_vitoria, lado_para_justa,
  poder_jogador, sorteio_milesimos,
} from "./jogador.ts";
import { refazer_justa, validar_entradas } from "./disputa.ts";
import type { Entrada } from "./disputa.ts";

export function cfg_ligas(s: Servico): Dados {
  return s.bal("economia")["ligas"];
}

// -------------------------------------------------------------- temporada

/** Temporada global: grade fixa a partir da época do servidor, com a duração do jogo. */
export function temporada_atual(s: Servico): { numero: number; inicio: number; fim: number } {
  const dur = inteiro(cfg_ligas(s)["temporada_dias"]) * 86400;
  const epoca = inteiro(s.bal("servidor")["temporadas"]["epoca"]);
  const k = Math.max(0, div(s.agora() - epoca, dur));
  return { numero: k + 1, inicio: epoca + k * dur, fim: epoca + (k + 1) * dur };
}

/**
 * Vira a temporada do jogador, se ele ficou para trás: baú pela liga em que
 * terminou, pontos com reinício parcial, histórico de partidas mantido.
 * Chamada no começo de toda ação de PvP. Devolve {temporada, liga, bau} da
 * última que fechou ({} se nenhuma).
 */
export function sincronizar_liga(s: Servico): Dados {
  const lg = s.estado["liga"];
  const cfg = cfg_ligas(s);
  const t = temporada_atual(s);
  let fechou: Dados = {};
  if (inteiro(lg["temporada"]) < t.numero) {
    // Quantas temporadas passaram: cada uma fecha com baú e reinício (pontos já reiniciados valem na seguinte).
    for (let n = inteiro(lg["temporada"]); n < t.numero; n++) {
      const pos = Liga.posicao(inteiro(lg["pontos"]), cfg);
      const rec: string[] = cfg["recompensa_temporada"];
      fechou = { temporada: n, liga: pos["nome"], bau: rec[Math.min(pos["liga"], rec.length - 1)] };
      guardar_bau(s, fechou["bau"]);
      lg["pontos"] = Liga.reinicio(inteiro(lg["pontos"]), cfg);
    }
    lg["temporada"] = t.numero;
    lg["temporada_inicio"] = t.inicio;
  }
  return fechou;
}

// ---------------------------------------------------------------- defesa

/** Guarda a configuração de agora como defesa (retrato no banco) e na lista do jogador. */
export function salvar_defesa(s: Servico): Resultado {
  sincronizar_liga(s);
  const lado = lado_para_justa(s);
  s.estado["liga"]["defesa"] = {
    equipamento: copiar(s.estado["equipamento"]), cavalo: s.estado["cavalo_ativo"],
    habilidades: [...lado["habilidades"]], salva_em: s.agora(),
  };
  return { ...concluir(), _efeitos: { defesa: { retrato: lado, poder: poder_jogador(s) } } };
}

// ------------------------------------------------------- adversário

/** Fantasma do servidor (poder típico dos pontos, limitado à faixa), para quando ninguém serve. */
export function fantasma(s: Servico, n: number, pontos_alvo: number, extra_poder = 0, poder_ref = -1): Dados {
  const cfg = cfg_ligas(s);
  const eco = s.bal("economia");
  const rng = new Aleatorio(inteiro(s.estado["baus"]["semente"]) + 7777 * (n + 1));
  const var_p = inteiro(cfg["fantasmas"]["variacao_pontos"]);
  const pontos = Math.max(0, pontos_alvo + rng.inteiro(-var_p, var_p));
  let alvo = Math.trunc(Number(cfg["poder_rival_base"]) + pontos * Number(cfg["poder_rival_por_ponto"])) + rng.inteiro(-8, 8);
  if (poder_ref >= 0) {
    const faixa = inteiro(cfg["faixa_poder"]);
    alvo = Math.min(Math.max(alvo, poder_ref - faixa + 3), poder_ref + faixa - 3);
  }
  alvo += extra_poder;
  const ordem = ["comum", "incomum", "raro", "epico", "lendario"];
  const rar = ordem[Math.min(Math.max(div(alvo - 30, 30), 0), 4)];
  const modelos = s.bal("itens")["modelos"];
  const equip: Dados = {};
  const pecas: Liga.Pecas[] = [];
  const nivel = Math.min(Math.max(div((alvo - 30) % 30, 3), 0), 10);
  for (const esp of ["elmo", "peitoral", "escudo", "lanca"]) {
    const opcoes: string[] = [];
    for (const m of Object.keys(modelos)) {
      if (modelos[m]["espaco"] === esp && modelos[m]["raridade"] === rar) opcoes.push(m);
    }
    if (opcoes.length === 0) continue;
    opcoes.sort();
    const m = opcoes[rng.inteiro(0, opcoes.length - 1)];
    const st: Dados = Forja.status_com_nivel(modelos[m]["status"], nivel, inteiro(eco["forja"]["bonus_status_por_nivel_pct"]));
    st["durabilidade"] = inteiro(modelos[m]["durabilidade_max"]);
    equip[esp] = st;
    pecas.push({ raridade: rar, nivel });
  }
  const poder_pecas = Liga.poder([], pecas, eco);
  const base_atr = Math.min(Math.max((alvo - poder_pecas) * 2, 20), 100);
  const lim = (v: number) => Math.min(Math.max(v, 10), 100);
  const cav = {
    forca: lim(base_atr + rng.inteiro(-6, 6)), precisao: lim(base_atr + rng.inteiro(-6, 6)), equilibrio: lim(base_atr + rng.inteiro(-6, 6)),
  };
  const cavalo = {
    velocidade: lim(base_atr + rng.inteiro(-6, 6)), folego: lim(base_atr + rng.inteiro(-6, 6)), temperamento: lim(base_atr + rng.inteiro(-6, 6)),
  };
  const atr = [...Object.values(cav), ...Object.values(cavalo)];
  const nomes = s.bal("nomes_sorteio");
  const lista: string[] = [...nomes["femininos"], ...nomes["masculinos"]];
  const casas: string[] = nomes["casas"];
  const cores = Object.keys(s.bal("paletas")["cores_casa"]);
  const c1 = cores[rng.inteiro(0, cores.length - 1)];
  const c2 = cores[rng.inteiro(0, cores.length - 1)];
  const habs = ["investida", "golpe_pesado"];
  return {
    id: `f${n}`, nome: `${lista[rng.inteiro(0, lista.length - 1)]} · ${casas[rng.inteiro(0, casas.length - 1)]}`,
    pontos, poder: Liga.poder(atr, pecas, eco), simulado: true,
    lado: { cavaleiro: cav, cavalo, equipamento: equip, habilidades: [habs[rng.inteiro(0, 1)], "bloqueio"] },
    casa: { principal: c1, secundaria: c2 }, brasao_perfil: ["novato", "equilibrado", "agressivo"][rng.inteiro(0, 2)],
    raridade: rar, nivel_pecas: nivel,
  };
}

/** Candidato real do banco (outro jogador com defesa salva). */
export interface Candidato {
  jogador_id: string;
  nome: string;
  pontos: number;
  poder: number;
  retrato: Dados;
  aparencia: Dados;
  brasao: Dados;
}

/**
 * Escolhe o adversário: o candidato real que a regra de pareamento aceita
 * (faixa de poder, pontos mais próximos) ou, se nenhum serve, um fantasma
 * do servidor. Guarda em `estado.liga.adversario` com a semente da partida.
 */
export function escolher_adversario(s: Servico, candidatos: Candidato[]): Resultado {
  sincronizar_liga(s);
  const cfg = cfg_ligas(s);
  const lg = s.estado["liga"];
  const meu = poder_jogador(s);
  const por_id: Record<string, Candidato> = {};
  for (const c of candidatos) por_id[c.jogador_id] = c;
  const id = Liga.parear(inteiro(lg["pontos"]), meu, candidatos.map((c) => ({ id: c.jogador_id, pontos: c.pontos, poder: c.poder })), cfg);
  lg["buscas"] = inteiro(lg["buscas"]) + 1;
  let adv: Dados;
  if (id !== "") {
    const c = por_id[id];
    adv = {
      id: `r${c.jogador_id}`, jogador_id: c.jogador_id, nome: c.nome, pontos: c.pontos, poder: c.poder, simulado: false,
      lado: c.retrato, casa: { principal: c.aparencia["principal"] ?? "azul_real", secundaria: c.aparencia["secundaria"] ?? "ouro_velho" },
      brasao: c.brasao, brasao_perfil: "equilibrado",
    };
  } else {
    adv = fantasma(s, inteiro(lg["buscas"]) * 100, inteiro(lg["pontos"]), 0, meu);
  }
  adv["semente"] = new Aleatorio(semente_servico(s)).proximo();
  adv["procurado_em"] = s.agora();
  lg["adversario"] = adv;
  return { ...concluir(), adversario: copiar(adv) };
}

// --------------------------------------------------------------- partida

/**
 * Conclui a partida de PvP com as entradas do cliente (conferidas): refaz a
 * justa contra o retrato do adversário com a semente que o servidor sorteou,
 * aplica pontos, ouro, XP e baú (mesma regra do GDScript) e devolve os efeitos
 * relacionais (pontos do defensor, registro da partida).
 */
export function concluir_pvp_conferido(s: Servico, entradas: unknown): Resultado {
  sincronizar_liga(s);
  const lg = s.estado["liga"];
  const a = lg["adversario"];
  if (!a || Object.keys(a).length === 0) return erro("sem_adversario");
  const aviso = validar_entradas(entradas, s.bal("servidor")["anticheat"]);
  if (aviso !== "") return erro(aviso);
  const cfg_j = configuracao_justa(s);
  const decorrido = s.agora() - inteiro(a["procurado_em"]);
  const f = cfg_j["justa"]["fases_ms"];
  const minimo = Math.floor(inteiro(cfg_j["justa"]["passadas"]) * (inteiro(f["largada"]) + inteiro(f["mira"]) + inteiro(f["impacto"])) / 1000);
  if (decorrido < minimo) return erro("tempo_impossivel");
  const perfil = s.bal("ia_rival")["perfis"][cfg_ligas(s)["fantasmas"]["perfil"]];
  const d: Dados = {
    cfg: cfg_j, lado_jogador: lado_para_justa(s), lado_rival: copiar(a["lado"]), semente: a["semente"], perfil_rival: perfil,
  };
  const { eventos, justa } = refazer_justa(d, entradas as Entrada[]);
  if (!justa.terminou()) return erro("justa_incompleta");
  const efeitos: Dados = {};
  const r = concluir_pvp(s, eventos, efeitos);
  r["placar"] = [justa.fases.placar_jogador, justa.fases.placar_rival];
  if (a["jogador_id"]) {
    efeitos["partida"] = {
      defensor_id: a["jogador_id"], semente: a["semente"], entradas, venceu: r["venceu"],
      pontos_atacante: inteiro(r["pontos"]) - inteiro(r["pontos_antes"]), pontos_defensor: efeitos["defensor"]?.["delta"] ?? 0,
    };
  }
  r["_efeitos"] = efeitos;
  return r;
}

/** Fim da justa de PvP (porte de ServicoJogador.concluir_pvp, sem a parte de ordem). */
export function concluir_pvp(s: Servico, eventos: Dados[], efeitos: Dados): Resultado {
  const lg = s.estado["liga"];
  const a = lg["adversario"];
  const cfg = cfg_ligas(s);
  const venceu = Pve.estrelas(eventos) > 0;
  const antes = inteiro(lg["pontos"]);
  const pos_antes = Liga.posicao(antes, cfg);
  let ouro_g = 0;
  let xp_g = 0;
  const baus_g: Dados[] = [];
  let premio: Dados = {};
  const camp = lg["campeonato"];
  if (a["campeonato"] ?? false) {
    if (venceu) {
      const premios: Dados[] = cfg["campeonato"]["premios"];
      premio = premios[Math.min(inteiro(camp["rodada"]), premios.length - 1)];
      camp["rodada"] = inteiro(camp["rodada"]) + 1;
      dar_recompensa(s, premio);
    } else {
      camp["eliminado"] = true;
    }
  } else {
    lg["pontos"] = Liga.depois_da_partida(antes, venceu, cfg);
    if (venceu) {
      ouro_g = Liga.ouro_vitoria(pos_antes["liga"], cfg);
      xp_g = inteiro(cfg["xp_vitoria"]);
      if (sorteio_milesimos(s, Math.round(Number(cfg_baus(s)["chance_madeira_por_vitoria"]) * 1000.0))) baus_g.push(guardar_bau(s, "madeira"));
    }
  }
  const pos = Liga.posicao(inteiro(lg["pontos"]), cfg);
  const nomes: string[] = cfg["nomes"];
  if (String(lg["melhor"]) === "" || nomes.indexOf(lg["melhor"]) < pos["liga"]) lg["melhor"] = nomes[pos["liga"]];
  const partidas: Dados[] = lg["partidas"];
  partidas.unshift({
    quando: s.agora(), adversario: a["nome"], venceu, pontos: inteiro(lg["pontos"]) - antes, campeonato: a["campeonato"] ?? false,
  });
  while (partidas.length > 30) partidas.pop();
  // O defensor (jogador real) ganha pontos quando a defesa vence; perder a defesa não tira nada.
  if (a["jogador_id"] && !venceu && !(a["campeonato"] ?? false)) {
    efeitos["defensor"] = { id: a["jogador_id"], delta: inteiro(cfg["defesa_vencida"]) };
  }
  lg["adversario"] = {};
  if (!venceu && derrota_por_pouco(s, eventos)) disparar_oferta(s, "derrota_por_pouco");
  if (pos["liga"] > pos_antes["liga"]) disparar_oferta(s, "subiu_liga");
  if (venceu && ouro_g > 0) guardar_vitoria(s, ouro_g);
  const niveis = ganhar(s, ouro_g, xp_g);
  if (venceu) _evento(s, "vitoria_pvp");
  return {
    ...concluir(), venceu, estrelas: venceu ? 1 : 0, pontos_antes: antes, pontos: inteiro(lg["pontos"]), ouro: ouro_g, xp: xp_g,
    niveis, baus: baus_g,
    subiu: pos["liga"] > pos_antes["liga"] || (pos["divisao"] !== pos_antes["divisao"] && inteiro(lg["pontos"]) > antes),
    premio, pvp: true,
  };
}

// --------------------------------------------------------- perfil público

/** Resumo do jogador para ranking, pareamento e perfil (`jogador_publico`), do estado autoritativo. */
export function resumo_publico(s: Servico, codigo: string): Dados {
  const e = s.estado;
  const lg = e["liga"] ?? {};
  const pos = Liga.posicao(inteiro(lg["pontos"] ?? 0), cfg_ligas(s));
  const cores = e["casa"]["cores"];
  const cav = e["cavaleiro"];
  const cavalo = (e["cavalos"] as Dados[]).find((c) => c["id"] === e["cavalo_ativo"]) ?? {};
  return {
    codigo, nome: String(cav["nome"] ?? "").slice(0, 20), casa: String(e["casa"]["nome"] ?? "").slice(0, 20),
    nivel: inteiro(cav["nivel"]), poder: poder_jogador(s), pontos: inteiro(lg["pontos"] ?? 0), liga: pos["nome"],
    melhor_liga: String(lg["melhor"] || pos["nome"]),
    aparencia: {
      principal: cores["principal"], secundaria: cores["secundaria"], metal: cores["metal"] ?? "ferro", pele: cav["pele"],
      cabelo: cav["cor_cabelo"], corpo: cav["corpo"], rosto: cav["rosto"], estilo_cabelo: cav["cabelo"], pelagem: cavalo["pelagem"] ?? "alazao",
    },
    brasao: copiar(e["casa"]["brasao"] ?? {}), titulo: String((e["metas"] ?? {})["titulo"] ?? ""),
  };
}

