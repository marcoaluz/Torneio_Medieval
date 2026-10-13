// Disputa do PvE conferida pelo servidor (3.4). O cliente NUNCA manda o
// resultado: manda as entradas (toques, mira, habilidade) com o instante de
// cada uma, e o servidor refaz a justa inteira com a mesma regra e a semente
// que ele mesmo sorteou ao iniciar. Só então entrega as recompensas.
//
// Fluxo: iniciar_disputa (guarda semente e o retrato dos dois lados no estado)
// → o cliente joga → concluir_disputa_conferida(entradas).

import { Aleatorio } from "../regra/aleatorio.ts";
import { Fase } from "../regra/justa_fases.ts";
import { Justa } from "../regra/justa.ts";
import type { Evento } from "../regra/justa_fases.ts";
import { concluir, erro, inteiro, semente_servico } from "./base.ts";
import type { Dados, Resultado, Servico } from "./base.ts";
import { registrar_justa } from "./jogador.ts";
import { concluir_disputa, pode_disputar, preparar_disputa } from "./pve.ts";

/** Entrada da justa: [t (ms desde o início), ação, x, y]. */
export type Entrada = [number, string, number, number];

const ACOES = ["tocar", "mirar", "soltar", "habilidade"];
/** Máximo de entradas aceitas (3 passadas + 1 extra: toques, mira e habilidade). */
const MAX_ENTRADAS = 400;

export function iniciar_disputa(s: Servico, torneio: string, indice: number): Resultado {
  const p = pode_disputar(s, torneio, indice);
  if (!p.ok) return p;
  if (typeof indice !== "number" || !Number.isInteger(indice)) return erro("disputa_inexistente");
  const prep = preparar_disputa(s, torneio, indice);
  const semente = new Aleatorio(semente_servico(s)).proximo();
  s.estado["disputa"] = {
    torneio, indice, semente, iniciada_em: s.agora(), cfg: prep["cfg"], lado_jogador: prep["lado_jogador"],
    lado_rival: prep["rival"]["lado"], perfil_rival: prep["rival"]["perfil"], gasta_folego: prep["gasta_folego"],
  };
  // O cliente joga com EXATAMENTE a configuração, os lados e o perfil que o servidor vai usar
  // para conferir (balanceamento remoto que mudou no meio da sessão não desalinha as duas pontas).
  return {
    ...concluir(), semente, cfg: prep["cfg"], lado_jogador: prep["lado_jogador"], rival: prep["rival"],
    desafios: prep["desafios"], visuais: prep["visuais"], gasta_folego: prep["gasta_folego"],
  };
}

/** Valida o formato e a plausibilidade humana das entradas. "" se servem. */
export function validar_entradas(entradas: unknown, cfg: Dados): string {
  if (!Array.isArray(entradas) || entradas.length > MAX_ENTRADAS) return "entradas_invalidas";
  let anterior = -1;
  let ultimo_toque_corrida = -1000;
  for (const e of entradas) {
    if (!Array.isArray(e) || e.length !== 4) return "entradas_invalidas";
    const [t, acao, x, y] = e;
    if (!Number.isInteger(t) || t < 0 || t > 600000 || !ACOES.includes(acao) || !Number.isInteger(x) || !Number.isInteger(y)) {
      return "entradas_invalidas";
    }
    if (t < anterior) return "entradas_fora_de_ordem";
    anterior = t;
    // Dedos humanos: dois toques com menos de 40 ms entre si não acontecem.
    if (acao === "tocar") {
      if (t - ultimo_toque_corrida < inteiro(cfg["toque_min_intervalo_ms"] ?? 40)) return "toques_impossiveis";
      ultimo_toque_corrida = t;
    }
  }
  return "";
}

/** Refaz a justa com as entradas e devolve os eventos (a regra decide; o cliente só aperta). */
export function refazer_justa(d: Dados, entradas: Entrada[]): { eventos: Evento[]; justa: Justa } {
  const j = new Justa(d["cfg"], d["lado_jogador"], d["lado_rival"], inteiro(d["semente"]), d["perfil_rival"]);
  const eventos: Evento[] = [...j.iniciar()];
  for (const e of entradas) {
    while (j.fases.tempo_total_ms < e[0] && !j.terminou()) {
      eventos.push(...j.avancar(e[0] - j.fases.tempo_total_ms));
    }
    if (j.terminou()) break;
    switch (e[1]) {
      case "tocar": eventos.push(...j.tocar()); break;
      case "mirar": j.mirar({ x: e[2], y: e[3] }); break;
      case "soltar": eventos.push(...j.soltar()); break;
      case "habilidade": eventos.push(...j.ativar_habilidade()); break;
    }
  }
  // Sem mais entradas: a justa segue sozinha até o fim (o jogador parou de tocar).
  let guarda = 0;
  while (!j.terminou() && guarda < 1000) {
    eventos.push(...j.avancar(1000));
    guarda += 1;
  }
  return { eventos, justa: j };
}

/** Duração mínima real de uma justa (soma das fases de uma passada x passadas, sem a Apresentação pulada). */
export function duracao_minima_s(cfg: Dados): number {
  const f = cfg["justa"]["fases_ms"];
  const por_passada = inteiro(f["largada"]) + inteiro(f["mira"]) + inteiro(f["impacto"]);
  return Math.floor(inteiro(cfg["justa"]["passadas"]) * por_passada / 1000);
}

/** Conclui a disputa ativa com as entradas do cliente (conferidas). */
export function concluir_disputa_conferida(s: Servico, entradas: unknown): Resultado {
  const d = s.estado["disputa"];
  if (typeof d !== "object" || d === null) return erro("sem_disputa_ativa");
  const bal_cfg = s.bal("servidor")["anticheat"];
  const e = validar_entradas(entradas, bal_cfg);
  if (e !== "") return erro(e);
  // O tempo real tem que caber: ninguém termina uma justa mais rápido que as fases dela.
  const decorrido = s.agora() - inteiro(d["iniciada_em"]);
  if (decorrido < duracao_minima_s(d["cfg"])) return erro("tempo_impossivel");
  const { eventos, justa } = refazer_justa(d, entradas as Entrada[]);
  if (justa.fases.fase !== Fase.FIM) return erro("justa_incompleta");
  const torneio: string = d["torneio"];
  const indice = inteiro(d["indice"]);
  const gasta = d["gasta_folego"] ?? true;
  delete s.estado["disputa"];
  registrar_justa(s, { equipamento_final: justa.equipamento_final(true), gasta_folego: gasta });
  const r = concluir_disputa(s, torneio, indice, eventos, false);
  r["placar"] = [justa.fases.placar_jogador, justa.fases.placar_rival];
  r["eventos_n"] = eventos.length;
  return r;
}

/** Abandona a disputa em andamento (sai da arena): nada é entregue. */
export function abandonar_disputa(s: Servico): Resultado {
  if (!("disputa" in s.estado)) return erro("sem_disputa_ativa");
  delete s.estado["disputa"];
  return concluir();
}

