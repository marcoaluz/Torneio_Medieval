// Ordens (guildas), ajuda, doações, torneio semanal, loja da ordem e código de
// amigo, puro. Porte de game/scripts/rules/ordem.gd; casos em
// tests/shared/ordem.json. Números em ordem.json (balanceamento).

import { Aleatorio } from "./aleatorio.ts";
import { clampi, div } from "./util.ts";

// deno-lint-ignore no-explicit-any
type Cfg = Record<string, any>;

export const ALFABETO_CODIGO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

// ------------------------------------------------------------- cargos

/** O cargo pode fazer a ação? */
export function pode(cargo: string, acao: string, cfg: Cfg): boolean {
  return ((cfg["permissoes"][cargo] ?? []) as string[]).includes(acao);
}

/** Ação sobre outro membro: o líder promove, rebaixa e expulsa; o oficial só expulsa membro comum; ninguém age sobre o líder. */
export function pode_sobre(cargo_ator: string, cargo_alvo: string, acao: string, cfg: Cfg): boolean {
  if (cargo_alvo === "lider") return false;
  switch (acao) {
    case "promover":
      return cargo_alvo === "membro" && pode(cargo_ator, "promover", cfg);
    case "rebaixar":
      return cargo_alvo === "oficial" && pode(cargo_ator, "rebaixar", cfg);
    case "expulsar":
      return pode(cargo_ator, cargo_alvo === "oficial" ? "expulsar_oficial" : "expulsar_membro", cfg);
  }
  return false;
}

export function cargo_depois(cargo: string, acao: string): string {
  if (acao === "promover" && cargo === "membro") return "oficial";
  if (acao === "rebaixar" && cargo === "oficial") return "membro";
  return cargo;
}

/** Dá para entrar ou convidar mais gente? */
export function tem_vaga(membros: number, cfg: Cfg): boolean {
  return membros < Math.trunc(cfg["membros_max"]);
}

// ------------------------------------------------------ ajuda e doação

/** Quantos segundos uma ajuda tira de um timer que ainda tem `restante_s`. */
export function segundos_da_ajuda(restante_s: number, cfg: Cfg): number {
  return clampi(restante_s, 0, Math.trunc(cfg["ajuda"]["segundos_por_ajuda"]));
}

export function pedido_aceita_ajuda(ajudas_recebidas: number, cfg: Cfg): boolean {
  return ajudas_recebidas < Math.trunc(cfg["ajuda"]["ajudas_max_por_pedido"]);
}

/** Moeda da ordem de uma ajuda, respeitando o teto do dia. */
export function moeda_da_ajuda(moeda_hoje: number, cfg: Cfg): number {
  return clampi(Math.trunc(cfg["ajuda"]["moeda_max_dia"]) - moeda_hoje, 0, Math.trunc(cfg["ajuda"]["moeda_por_ajuda"]));
}

/** Unidades que ainda podem ser doadas hoje. */
export function doacao_restante(unidades_hoje: number, cfg: Cfg): number {
  return Math.max(0, Math.trunc(cfg["doacao"]["limite_dia_unidades"]) - unidades_hoje);
}

// ------------------------------------------------------ torneio semanal

/** Posição da ordem (1 = primeira): 1 + quantas outras têm MAIS vitórias (empate fica à frente). */
export function posicao_no_torneio(minhas: number, outras: number[]): number {
  let p = 1;
  for (const o of outras) {
    if (Math.trunc(o) > minhas) p += 1;
  }
  return p;
}

/** Prêmio da posição: o primeiro da lista com posicao <= ate_posicao. */
export function premio_do_torneio(posicao: number, cfg: Cfg): { moeda: number; bau: string } {
  for (const p of cfg["torneio"]["premios"]) {
    if (posicao <= Math.trunc(p["ate_posicao"])) return { moeda: Math.trunc(p["moeda"] ?? 0), bau: String(p["bau"] ?? "") };
  }
  return { moeda: 0, bau: "" };
}

/** Vitórias de PvP que um membro simulado acumula até agora na semana (arredonda para cima). */
export function vitorias_simuladas(semente: number, semana: number, indice: number, fracao_milesimos: number, cfg: Cfg): number {
  const f: number[] = cfg["torneio"]["vitorias_por_membro_semana"];
  const rng = new Aleatorio(semente + 4099 * (semana + 1) + 131 * (indice + 1));
  const total = rng.inteiro(Math.trunc(f[0]), Math.trunc(f[1]));
  return div(total * clampi(fracao_milesimos, 0, 1000) + 999, 1000);
}

// ------------------------------------------------------------- loja

/** "" se dá para comprar; senão o código do erro. */
export function erro_da_compra(moeda: number, comprados_na_semana: number, item: Cfg): string {
  if (comprados_na_semana >= Math.trunc(item["limite_semana"])) return "limite_semana";
  if (moeda < Math.trunc(item["moeda"])) return "moeda_insuficiente";
  return "";
}

// --------------------------------------------------- código de amigo

/** Código público de um jogador ("TM-" + 6 caracteres sem 0/O/1/I) pela semente dele. */
export function codigo_amigo(semente: number): string {
  const rng = new Aleatorio(semente ^ 0x2545F491);
  rng.proximo();
  let s = "TM-";
  for (let i = 0; i < 6; i++) s += ALFABETO_CODIGO[rng.proximo() % ALFABETO_CODIGO.length];
  return s;
}

/** Maiúsculas, sem espaços; aceita sem o "TM-" e sem hífen. */
export function normalizar_codigo(texto: string): string {
  let t = texto.trim().toUpperCase().replaceAll(" ", "");
  if (t.startsWith("TM-")) t = t.slice(3);
  else if (t.startsWith("TM")) t = t.slice(2);
  return "TM-" + t;
}

export function codigo_valido(texto: string): boolean {
  const c = normalizar_codigo(texto);
  if (c.length !== 9) return false;
  for (let i = 3; i < 9; i++) {
    if (ALFABETO_CODIGO.indexOf(c[i]) < 0) return false;
  }
  return true;
}

// -------------------------------------------------- ordens simuladas

export interface OrdemSimulada {
  id: string;
  nome: string;
  membros: number;
  poder: number;
  brasao: Record<string, string>;
}

/** `quantas` ordens para o jogador escolher (até o servidor). Os nomes não repetem. */
export function ordens_simuladas(semente: number, cfg: Cfg, nomes: string[], cores: string[], simbolos: string[], divisoes: string[]): OrdemSimulada[] {
  const rng = new Aleatorio(semente + 99991);
  const s = cfg["simuladas"];
  const disponiveis = [...nomes];
  const r: OrdemSimulada[] = [];
  const quantas = Math.min(Math.trunc(s["quantas"]), disponiveis.length); // calculado uma vez (o loop esvazia a lista)
  for (let i = 0; i < quantas; i++) {
    const nome = disponiveis.splice(rng.inteiro(0, disponiveis.length - 1), 1)[0];
    const c1 = cores[rng.inteiro(0, cores.length - 1)];
    const c2 = cores[rng.inteiro(0, cores.length - 1)];
    const membros = rng.inteiro(Math.trunc(s["membros"][0]), Math.trunc(s["membros"][1]));
    const poder = rng.inteiro(Math.trunc(s["poder"][0]), Math.trunc(s["poder"][1]));
    r.push({
      id: `s${i}`, nome, membros, poder,
      brasao: {
        cor1: c1, cor2: c2, cor_simbolo: c2,
        simbolo: simbolos[rng.inteiro(0, simbolos.length - 1)],
        divisao: divisoes[rng.inteiro(0, divisoes.length - 1)],
      },
    });
  }
  return r;
}
