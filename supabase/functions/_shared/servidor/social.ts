// Funções sociais no servidor (3.8): ordens (cargos, ajuda nos timers,
// doações, torneio semanal, loja), chat da ordem e global, amigos e
// moderação. A regra pura é a de ordem.ts (a mesma do GDScript, com os mesmos
// casos). Aqui ficam as decisões que dependem de OUTROS jogadores: o banco é
// lido por `BancoSocial` e as escritas saem como operações em
// `resultado._efeitos.social`, gravadas na MESMA transação do estado do jogador
// (aplicar_ops_sociais). O estado de OUTRO jogador nunca é mexido aqui: ajuda
// e doação são aplicadas por quem recebe, na próxima ação dele (aplicar_pendencias).

import * as Ordem from "../regra/ordem.ts";
import { concluir, copiar, dia_atual, erro, gastar_materiais, inteiro, material, ouro, semana_atual, tem } from "./base.ts";
import type { Dados, Resultado, Servico } from "./base.ts";
import { _evento, entregar_conteudo, guardar_bau, limpar_nome, validar_nome } from "./jogador.ts";

export interface Membro {
  jogador_id: string;
  cargo: string;
  nome: string;
  poder: number;
}

export interface PedidoAjuda {
  id: string;
  jogador_id: string;
  timer_id: string;
  tipo: string;
  ajudas: number;
  ajudas_max: number;
  /** Eu já ajudei este pedido (cada jogador ajuda um pedido uma vez). */
  ajudado_por_mim: boolean;
}

/** Leituras do banco de que as funções sociais precisam (as escritas vão em `_efeitos.social`). */
export interface BancoSocial {
  ordem_do_jogador(jogador: string): Promise<{ ordem_id: string; cargo: string } | null>;
  ordem(ordem_id: string): Promise<{ id: string; nome: string; brasao: Dados; idioma: string } | null>;
  membros(ordem_id: string): Promise<Membro[]>;
  nome_de_ordem_livre(nome: string): Promise<boolean>;
  pedidos_abertos(ordem_id: string, agora: number, jogador: string): Promise<PedidoAjuda[]>;
  ajudas_pendentes(jogador: string): Promise<{ pedido_id: string; ajudante_id: string; timer_id: string }[]>;
  doacoes_pendentes(jogador: string): Promise<{ id: number; material: string; quantidade: number }[]>;
  doado_no_dia(jogador: string, dia: number): Promise<number>;
  jogador_por_codigo(codigo: string): Promise<{ jogador_id: string; nome: string } | null>;
  silenciado_ate(jogador: string): Promise<number | null>;
  /** Vitórias de PvP de cada ordem na semana (maiores primeiro), com o nome. */
  torneio(semana: number, limite: number): Promise<{ ordem_id: string; nome: string; vitorias: number }[]>;
  amigos(jogador: string): Promise<string[]>;
}

type Op = Dados;

function cfg(s: Servico): Dados {
  return s.bal("ordem");
}

/** Acrescenta operações sociais aos efeitos de um resultado (gravadas na mesma transação). */
export function ops(r: Resultado, ...novas: Op[]): Resultado {
  const ef = (r["_efeitos"] ?? {}) as Dados;
  ef["social"] = [...((ef["social"] as Op[]) ?? []), ...novas];
  r["_efeitos"] = ef;
  return r;
}

/** Cargo de quem age (dado do banco, nunca do cliente). */
async function meu_papel(banco: BancoSocial, jogador: string): Promise<{ ordem_id: string; cargo: string } | null> {
  return await banco.ordem_do_jogador(jogador);
}

function nome_valido(s: Servico, nome: string): string {
  const e = validar_nome(s, nome);
  if (e !== "") return e;
  if (limpar_nome(nome).length < inteiro(cfg(s)["nome"]["min"])) return "nome_curto";
  return "";
}

// ------------------------------------------------------------------ ordem

export async function criar_ordem(s: Servico, jogador: string, nome: string, brasao: Dados, idioma: string, banco: BancoSocial): Promise<Resultado> {
  const c = cfg(s);
  if (await meu_papel(banco, jogador)) return erro("ja_tem_ordem");
  if (inteiro(s.estado["cavaleiro"]["nivel"]) < inteiro(c["nivel_minimo"])) return erro("nivel_baixo");
  const e = nome_valido(s, nome);
  if (e !== "") return erro(e);
  if (ouro(s) < inteiro(c["criar"]["ouro"])) return erro("ouro_insuficiente");
  const limpo = limpar_nome(nome);
  if (!(await banco.nome_de_ordem_livre(limpo))) return erro("nome_em_uso");
  s.estado["inventario"]["ouro"] = ouro(s) - inteiro(c["criar"]["ouro"]);
  const id = crypto.randomUUID();
  return ops(concluir(), { op: "ordem_criar", ordem_id: id, nome: limpo, brasao, idioma: idioma === "en" ? "en" : "pt" });
}

export async function entrar_ordem(s: Servico, jogador: string, ordem_id: string, banco: BancoSocial): Promise<Resultado> {
  const c = cfg(s);
  if (await meu_papel(banco, jogador)) return erro("ja_tem_ordem");
  if (inteiro(s.estado["cavaleiro"]["nivel"]) < inteiro(c["nivel_minimo"])) return erro("nivel_baixo");
  const o = await banco.ordem(ordem_id);
  if (!o) return erro("ordem_inexistente");
  if (!Ordem.tem_vaga((await banco.membros(ordem_id)).length, c)) return erro("ordem_cheia");
  return ops(concluir(), { op: "ordem_entrar", ordem_id });
}

export async function sair_ordem(s: Servico, jogador: string, banco: BancoSocial): Promise<Resultado> {
  const p = await meu_papel(banco, jogador);
  if (!p) return erro("sem_ordem");
  const membros = await banco.membros(p.ordem_id);
  if (p.cargo === "lider" && membros.length > 1) return erro("passe_a_lideranca");
  return ops(concluir(), { op: "ordem_sair", ordem_id: p.ordem_id });
}

export async function dissolver_ordem(s: Servico, jogador: string, banco: BancoSocial): Promise<Resultado> {
  const p = await meu_papel(banco, jogador);
  if (!p) return erro("sem_ordem");
  if (!Ordem.pode(p.cargo, "dissolver", cfg(s))) return erro("sem_permissao");
  return ops(concluir(), { op: "ordem_dissolver", ordem_id: p.ordem_id });
}

/** Promover, rebaixar ou expulsar `alvo` (id do jogador), pelas permissões do cargo (regra pura). */
export async function agir_sobre_membro(s: Servico, jogador: string, alvo: string, acao: string, banco: BancoSocial): Promise<Resultado> {
  const p = await meu_papel(banco, jogador);
  if (!p) return erro("sem_ordem");
  if (alvo === jogador) return erro("sem_permissao");
  const m = (await banco.membros(p.ordem_id)).find((x) => x.jogador_id === alvo);
  if (!m) return erro("membro_inexistente");
  if (!["promover", "rebaixar", "expulsar"].includes(acao)) return erro("acao_invalida");
  if (!Ordem.pode_sobre(p.cargo, m.cargo, acao, cfg(s))) return erro("sem_permissao");
  if (acao === "expulsar") return ops(concluir(), { op: "ordem_expulsar", ordem_id: p.ordem_id, alvo });
  return ops(concluir(), { op: "ordem_cargo", ordem_id: p.ordem_id, alvo, cargo: Ordem.cargo_depois(m.cargo, acao) });
}

export async function passar_lideranca(s: Servico, jogador: string, alvo: string, banco: BancoSocial): Promise<Resultado> {
  const p = await meu_papel(banco, jogador);
  if (!p) return erro("sem_ordem");
  if (!Ordem.pode(p.cargo, "passar_lideranca", cfg(s))) return erro("sem_permissao");
  const m = (await banco.membros(p.ordem_id)).find((x) => x.jogador_id === alvo);
  if (!m || alvo === jogador) return erro("membro_inexistente");
  return ops(concluir(), { op: "ordem_lideranca", ordem_id: p.ordem_id, alvo });
}

export async function editar_ordem(s: Servico, jogador: string, nome: string | null, brasao: Dados | null, banco: BancoSocial): Promise<Resultado> {
  const p = await meu_papel(banco, jogador);
  if (!p) return erro("sem_ordem");
  if (brasao && !Ordem.pode(p.cargo, "editar_brasao", cfg(s))) return erro("sem_permissao");
  if (nome !== null) {
    if (!Ordem.pode(p.cargo, "editar_nome", cfg(s))) return erro("sem_permissao");
    const e = nome_valido(s, nome);
    if (e !== "") return erro(e);
    if (!(await banco.nome_de_ordem_livre(limpar_nome(nome)))) return erro("nome_em_uso");
  }
  return ops(concluir(), { op: "ordem_editar", ordem_id: p.ordem_id, nome: nome === null ? null : limpar_nome(nome), brasao });
}

// ------------------------------------------------- ajuda nos timers

const TIPOS_AJUDAVEIS = (s: Servico): string[] => cfg(s)["ajuda"]["tipos"];

/** Pede ajuda da ordem para um timer do jogador (precisa existir e estar em andamento). */
export async function pedir_ajuda(s: Servico, jogador: string, timer_id: string, banco: BancoSocial): Promise<Resultado> {
  const p = await meu_papel(banco, jogador);
  if (!p) return erro("sem_ordem");
  const c = cfg(s)["ajuda"];
  const t = (s.estado["timers"] as Dados[]).find((x) => x["id"] === timer_id);
  if (!t || s.agora() >= inteiro(t["termina_em"]) || !TIPOS_AJUDAVEIS(s).includes(t["tipo"])) return erro("timer_inexistente");
  const abertos = await banco.pedidos_abertos(p.ordem_id, s.agora(), jogador);
  if (abertos.some((x) => x.jogador_id === jogador && x.timer_id === timer_id)) return erro("ja_pediu");
  return ops(concluir(), {
    op: "ajuda_pedir", ordem_id: p.ordem_id, pedido_id: crypto.randomUUID(), timer_id, tipo: t["tipo"],
    ajudas_max: inteiro(c["ajudas_max_por_pedido"]), expira_em: inteiro(t["termina_em"]),
  });
}

/** Ajuda o pedido de um colega: ganha moeda da ordem (teto diário); o corte do timer é do colega. */
export async function ajudar_pedido(s: Servico, jogador: string, pedido_id: string, banco: BancoSocial): Promise<Resultado> {
  const p = await meu_papel(banco, jogador);
  if (!p) return erro("sem_ordem");
  const pedido = (await banco.pedidos_abertos(p.ordem_id, s.agora(), jogador)).find((x) => x.id === pedido_id);
  if (!pedido) return erro("pedido_inexistente");
  if (pedido.jogador_id === jogador) return erro("pedido_proprio");
  if (pedido.ajudado_por_mim) return erro("ja_ajudou");
  if (!Ordem.pedido_aceita_ajuda(pedido.ajudas, cfg(s))) return erro("pedido_completo");
  const am = social(s)["ajuda_moeda"];
  if (inteiro(am["dia"]) !== dia_atual(s)) {
    am["dia"] = dia_atual(s);
    am["moeda"] = 0;
  }
  const g = Ordem.moeda_da_ajuda(inteiro(am["moeda"]), cfg(s));
  am["moeda"] = inteiro(am["moeda"]) + g;
  social(s)["moeda"] = inteiro(social(s)["moeda"]) + g;
  _evento(s, "ajuda_ordem");
  return { ...ops(concluir(), { op: "ajuda_dar", pedido_id }), moeda: g };
}

function social(s: Servico): Dados {
  if (!tem(s.estado, "social")) s.estado["social"] = {};
  const x = s.estado["social"];
  x["ajuda_moeda"] ??= { dia: -1, moeda: 0 };
  x["moeda"] ??= 0;
  x["doacoes"] ??= { dia: -1, unidades: 0 };
  x["loja"] ??= { semana: -1, compras: {} };
  x["torneio"] ??= { semana: -1, pendente: {} };
  return x;
}

/**
 * Pré-passo de toda ação do jogador (chamado pelo handler): aplica no estado
 * dele as ajudas e doações que os colegas fizeram para ele. Devolve as
 * operações que marcam o que foi aplicado.
 */
export async function aplicar_pendencias(s: Servico, jogador: string, banco: BancoSocial): Promise<Op[]> {
  const feitas: Op[] = [];
  const cfg_a = cfg(s);
  const pend = await banco.ajudas_pendentes(jogador);
  for (const a of pend) {
    const t = (s.estado["timers"] as Dados[]).find((x) => x["id"] === a.timer_id);
    if (t) {
      t["termina_em"] = inteiro(t["termina_em"]) - Ordem.segundos_da_ajuda(Math.max(inteiro(t["termina_em"]) - s.agora(), 0), cfg_a);
    }
    feitas.push({ op: "ajuda_aplicada", pedido_id: a.pedido_id, ajudante_id: a.ajudante_id });
  }
  for (const d of await banco.doacoes_pendentes(jogador)) {
    const mats = s.estado["inventario"]["materiais"];
    mats[d.material] = inteiro(mats[d.material] ?? 0) + d.quantidade;
    feitas.push({ op: "doacao_aplicada", id: d.id });
  }
  return feitas;
}

// ----------------------------------------------------------------- doação

/** Doa material a um colega da mesma ordem (limite diário em unidades; ganha moeda da ordem). */
export async function doar(s: Servico, jogador: string, para: string, material_nome: string, quantidade: number, banco: BancoSocial): Promise<Resultado> {
  const p = await meu_papel(banco, jogador);
  if (!p) return erro("sem_ordem");
  const c = cfg(s)["doacao"];
  if (!tem(c["materiais"], material_nome)) return erro("material_nao_doavel");
  if (!Number.isInteger(quantidade) || quantidade <= 0) return erro("quantidade_invalida");
  if (para === jogador) return erro("membro_inexistente");
  if (!(await banco.membros(p.ordem_id)).some((m) => m.jogador_id === para)) return erro("membro_inexistente");
  const dia = dia_atual(s);
  const feito = await banco.doado_no_dia(jogador, dia);
  if (quantidade > Ordem.doacao_restante(feito, cfg(s))) return erro("limite_diario");
  if (material(s, material_nome) < quantidade) return erro("material_insuficiente");
  gastar_materiais(s, { [material_nome]: quantidade });
  const g = inteiro(c["moeda_por_doacao"]);
  social(s)["moeda"] = inteiro(social(s)["moeda"]) + g;
  _evento(s, "doacao_ordem");
  return { ...ops(concluir(), { op: "doacao_registrar", ordem_id: p.ordem_id, para_id: para, material: material_nome, quantidade, dia }), moeda: g };
}

// ---------------------------------------------------------------- torneio

/** Torneio de Ordens da semana: classificação real (top N), posição da minha ordem e prêmio previsto. */
export async function torneio_semana(s: Servico, jogador: string, banco: BancoSocial): Promise<Resultado> {
  const p = await meu_papel(banco, jogador);
  if (!p) return erro("sem_ordem");
  const semana = semana_atual(s);
  const lista = await banco.torneio(semana, 20);
  const minha = lista.find((x) => x.ordem_id === p.ordem_id)?.vitorias ?? 0;
  const outras = lista.filter((x) => x.ordem_id !== p.ordem_id).map((x) => x.vitorias);
  const posicao = Ordem.posicao_no_torneio(minha, outras);
  return { ...concluir(), semana, pontos: minha, posicao, ordens: lista, premio: Ordem.premio_do_torneio(posicao, cfg(s)) };
}

/** Resgata o prêmio da semana passada, uma vez (a posição final é a da tabela daquela semana). */
export async function resgatar_torneio(s: Servico, jogador: string, banco: BancoSocial): Promise<Resultado> {
  const p = await meu_papel(banco, jogador);
  if (!p) return erro("sem_ordem");
  const t = social(s)["torneio"];
  const passada = semana_atual(s) - 1;
  if (inteiro(t["resgatada"] ?? -1) >= passada) return erro("sem_premio");
  const lista = await banco.torneio(passada, 200);
  const minha = lista.find((x) => x.ordem_id === p.ordem_id)?.vitorias ?? 0;
  if (minha === 0) return erro("sem_premio"); // ordem que não jogou não ganha
  const posicao = Ordem.posicao_no_torneio(minha, lista.filter((x) => x.ordem_id !== p.ordem_id).map((x) => x.vitorias));
  const pr = Ordem.premio_do_torneio(posicao, cfg(s));
  t["resgatada"] = passada;
  social(s)["moeda"] = inteiro(social(s)["moeda"]) + pr.moeda;
  const bau = pr.bau !== "" ? guardar_bau(s, pr.bau) : {};
  return { ...concluir(), moeda: pr.moeda, bau_ganho: bau, posicao };
}

/** Conta uma vitória de PvP para o torneio da ordem (efeito da conclusão da partida). */
export function op_vitoria_torneio(s: Servico, ordem_id: string): Op {
  return { op: "torneio_vitoria", semana: semana_atual(s), ordem_id };
}

// ----------------------------------------------------------------- loja

/** Itens da loja da ordem com o que dá para comprar (moeda e limite da semana ficam no estado). */
export function loja_ordem(s: Servico): Dados[] {
  const l = social(s)["loja"];
  if (inteiro(l["semana"]) !== semana_atual(s)) {
    l["semana"] = semana_atual(s);
    l["compras"] = {};
  }
  const r: Dados[] = [];
  for (const it of cfg(s)["loja"]["itens"] as Dados[]) {
    const comprados = inteiro(l["compras"][it["id"]] ?? 0);
    let e = Ordem.erro_da_compra(inteiro(social(s)["moeda"]), comprados, it);
    if (e === "" && tem(it, "projeto") && (s.estado["inventario"]["projetos"] as string[]).includes(it["projeto"])) e = "projeto_ja_tenho";
    r.push({ id: it["id"], moeda: inteiro(it["moeda"]), conteudo: copiar(it["conteudo"] ?? {}), projeto: String(it["projeto"] ?? ""), restantes: inteiro(it["limite_semana"]) - comprados, erro: e, pode: e === "" });
  }
  return r;
}

export function comprar_da_ordem(s: Servico, id: string): Resultado {
  const it = loja_ordem(s).find((x) => x["id"] === id);
  if (!it) return erro("produto_inexistente");
  if (!it["pode"]) return erro(String(it["erro"]));
  const so = social(s);
  so["moeda"] = inteiro(so["moeda"]) - inteiro(it["moeda"]);
  so["loja"]["compras"][id] = inteiro(so["loja"]["compras"][id] ?? 0) + 1;
  if (it["projeto"] !== "") (s.estado["inventario"]["projetos"] as string[]).push(it["projeto"]);
  else entregar_conteudo(s, it["conteudo"]);
  return concluir();
}

// ------------------------------------------------------------------- chat

const CANAIS = ["ordem", "global"];

/** Envia mensagem (texto livre filtrado ou rápida). O canal da ordem é o da ordem do banco, nunca o do cliente. */
export async function chat_enviar(
  s: Servico, jogador: string, canal: string, texto: string, rapida: string, idioma: string, banco: BancoSocial,
): Promise<Resultado> {
  if (!CANAIS.includes(canal)) return erro("canal_inexistente");
  const c = s.bal("ordem")["chat"];
  const ate = await banco.silenciado_ate(jogador);
  if (ate !== null && ate > s.agora()) return erro("silenciado");
  let canal_id: string;
  if (canal === "ordem") {
    const p = await meu_papel(banco, jogador);
    if (!p) return erro("sem_ordem");
    canal_id = `ordem:${p.ordem_id}`;
  } else {
    canal_id = `global:${idioma === "en" ? "en" : "pt"}`;
  }
  const nome: string = s.estado["cavaleiro"]["nome"] ?? "";
  if (rapida !== "") {
    const rapidas: string[] = s.bal("chat_rapido")["rapidas"] ?? [];
    if (!rapidas.includes(rapida)) return erro("mensagem_inexistente");
    return ops(concluir(), { op: "chat_inserir", canal: canal_id, de_nome: nome, texto: "", chave: rapida });
  }
  const t = limpar_nome(texto);
  if (t === "") return erro("mensagem_vazia");
  if (t.length > inteiro(c["texto_max"])) return erro("mensagem_longa");
  if (texto_ofensivo(s, t)) return erro("mensagem_ofensiva");
  return ops(concluir(), { op: "chat_inserir", canal: canal_id, de_nome: nome, texto: t, chave: "" });
}

export function texto_ofensivo(s: Servico, texto: string): boolean {
  // Mesma lista e normalização dos nomes (ServicoNomes.texto_ofensivo no GDScript).
  const norm = normalizar(texto);
  return (s.bal("nomes_proibidos")["raizes"] as string[]).some((r) => norm.includes(r));
}

const ACENTOS: Record<string, string> = {
  "á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "é": "e", "ê": "e", "è": "e", "ë": "e", "í": "i", "î": "i", "ì": "i", "ï": "i",
  "ó": "o", "ô": "o", "õ": "o", "ò": "o", "ö": "o", "ú": "u", "û": "u", "ù": "u", "ü": "u", "ç": "c", "ñ": "n",
};
const TROCAS: Record<string, string> = { "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s" };

function normalizar(t: string): string {
  let r = "";
  for (let ch of t.toLowerCase()) {
    if (tem(ACENTOS, ch)) ch = ACENTOS[ch];
    else if (tem(TROCAS, ch)) ch = TROCAS[ch];
    if (ch >= "a" && ch <= "z") r += ch;
  }
  return r;
}

// ----------------------------------------------------------------- amigos

export async function adicionar_amigo_por_codigo(s: Servico, jogador: string, codigo: string, banco: BancoSocial): Promise<Resultado> {
  if (!Ordem.codigo_valido(codigo)) return erro("codigo_invalido");
  const c = Ordem.normalizar_codigo(codigo);
  const alvo = await banco.jogador_por_codigo(c);
  if (!alvo) return erro("codigo_nao_encontrado");
  if (alvo.jogador_id === jogador) return erro("codigo_proprio");
  const meus = await banco.amigos(jogador);
  if (meus.includes(alvo.jogador_id)) return erro("ja_amigo");
  if (meus.length >= inteiro(cfg(s)["amigos"]["max"])) return erro("amigos_cheio");
  return { ...ops(concluir(), { op: "amigo_adicionar", amigo_id: alvo.jogador_id }), nome: alvo.nome };
}

export function remover_amigo(_s: Servico, amigo_id: string): Resultado {
  return ops(concluir(), { op: "amigo_remover", amigo_id });
}

