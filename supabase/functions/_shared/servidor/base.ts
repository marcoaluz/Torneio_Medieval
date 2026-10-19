// Base do porte do ServicoJogador para o servidor (3.2). Cada módulo desta
// pasta traduz uma seção de game/scripts/services/servico_jogador.gd, com os
// mesmos nomes, e opera sobre o MESMO documento de estado (docs/DADOS_JOGADOR.md).
// O GDScript é a referência: tests/shared/cenarios_servico.json grava o que ele
// faz passo a passo e os testes daqui conferem o mesmo resultado.
//
// Convenções: comandos devolvem {ok, erro, ...}; leituras devolvem cópias;
// `agora()` é o relógio do SERVIDOR (segundos Unix); dados de balanceamento
// vêm de `bal(nome)` (tabela `balanceamento` na produção, arquivos nos testes).

// deno-lint-ignore no-explicit-any
export type Dados = Record<string, any>;

export interface Servico {
  /** Estado do jogador (o documento versionado). Os comandos mudam este objeto. */
  estado: Dados;
  /** Dados de balanceamento por nome (justa, treino, economia, itens, ...). Somente leitura. */
  bal(nome: string): Dados;
  /** Relógio do servidor, em segundos Unix. */
  agora(): number;
}

export interface Resultado {
  ok: boolean;
  erro: string;
  // deno-lint-ignore no-explicit-any
  [chave: string]: any;
}

export const VERSAO = 12;
export const ESPACOS_REGRA = ["elmo", "peitoral", "escudo", "lanca"];

export function erro(codigo: string): Resultado {
  return { ok: false, erro: codigo };
}

/** O que `_concluir` devolve no GDScript (aqui a gravação é da Edge Function). */
export function concluir(): Resultado {
  return { ok: true, erro: "" };
}

export function copiar<T>(v: T): T {
  return JSON.parse(JSON.stringify(v));
}

/** Chave própria (não herdada de Object.prototype). */
export function tem(obj: unknown, chave: string): boolean {
  return typeof obj === "object" && obj !== null && Object.hasOwn(obj, chave);
}

export function div(a: number, b: number): number {
  return Math.trunc(a / b);
}

export function clampi(v: number, minimo: number, maximo: number): number {
  return v < minimo ? minimo : (v > maximo ? maximo : v);
}

export function inteiro(v: unknown): number {
  return Math.trunc(Number(v));
}

/** Id novo ("t12", "c3", "i7"...) pelo contador do estado. */
export function novo_id(e: Dados, prefixo: string): string {
  const n = inteiro(e["proximo_id"]);
  e["proximo_id"] = n + 1;
  return `${prefixo}${n}`;
}

/** Semente dos sorteios do serviço: a do save mais um contador. */
export function semente_servico(s: Servico): number {
  const bs = s.estado["baus"];
  bs["sorteios"] = inteiro(bs["sorteios"]) + 1;
  return inteiro(bs["semente"]) + 1000003 * inteiro(bs["sorteios"]);
}

/** Sorteio em milésimos com a semente do serviço (chance em 0..1000). */
export function sorteio_milesimos(s: Servico, chance: number, Aleatorio: new (semente: number) => { chance_milesimos(c: number): boolean }): boolean {
  return new Aleatorio(semente_servico(s)).chance_milesimos(chance);
}

// ---------------------------------------------------------------- relógio

export function restante(s: Servico, termina_em: number): number {
  return Math.max(termina_em - s.agora(), 0);
}

export function pronto(s: Servico, termina_em: number): boolean {
  return s.agora() >= termina_em;
}

/** Dia do jogo (vira na hora configurada em metas.json). */
export function dia_atual(s: Servico): number {
  return div(s.agora() - inteiro(s.bal("metas")["virada_hora_utc"]) * 3600, 86400);
}

/** Semana que começa na segunda (o dia 0, 1/1/1970, foi uma quinta). */
export function semana_atual(s: Servico): number {
  return div(dia_atual(s) + 3, 7);
}

// ------------------------------------------------------------- inventário

export function ouro(s: Servico): number {
  return inteiro(s.estado["inventario"]["ouro"]);
}

export function gemas(s: Servico): number {
  return inteiro(s.estado["inventario"]["gemas"]);
}

export function material(s: Servico, nome: string): number {
  return inteiro(s.estado["inventario"]["materiais"][nome] ?? 0);
}

export function materiais(s: Servico): Dados {
  return copiar(s.estado["inventario"]["materiais"]);
}

export function gastar_materiais(s: Servico, custo: Dados): void {
  const mats = s.estado["inventario"]["materiais"];
  for (const m of Object.keys(custo)) mats[m] = inteiro(mats[m] ?? 0) - inteiro(custo[m]);
}

export function item(s: Servico, id: string): Dados {
  for (const it of s.estado["inventario"]["itens"]) {
    if (it["id"] === id) return copiar(it);
  }
  return {};
}

/** Referência (não cópia) ao item do inventário, para os comandos mudarem. */
export function item_ref(s: Servico, id: string): Dados | null {
  for (const it of s.estado["inventario"]["itens"]) {
    if (it["id"] === id) return it;
  }
  return null;
}

export function cavalo(s: Servico, id: string): Dados {
  for (const c of s.estado["cavalos"]) {
    if (c["id"] === id) return copiar(c);
  }
  return {};
}

export function cavalo_ativo(s: Servico): Dados {
  return cavalo(s, s.estado["cavalo_ativo"]);
}

/** Peça equipada num espaço ({} se vazio). */
export function equipado(s: Servico, espaco: string): Dados {
  return item(s, s.estado["equipamento"][espaco] ?? "");
}

export function predio_nivel_simples(s: Servico, nome: string): number {
  const preds = s.estado["vila"]["predios"];
  return tem(preds, nome) ? inteiro(preds[nome]["nivel"]) : 0;
}

/** Valor de uma curva [[nivel, valor], ...] para o nível atual do cavaleiro. */
export function da_curva(s: Servico, curva: number[][]): number {
  const nivel = inteiro(s.estado["cavaleiro"]["nivel"]);
  let v = inteiro(curva[0][1]);
  for (const par of curva) {
    if (nivel >= inteiro(par[0])) v = inteiro(par[1]);
  }
  return v;
}
