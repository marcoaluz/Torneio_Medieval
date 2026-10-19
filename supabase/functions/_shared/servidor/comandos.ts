// Tabela dos comandos do servidor: nome (o mesmo do ServicoJogador do GDScript)
// -> função. `PUBLICOS` é o que o cliente pode pedir pela Edge Function de
// ação; os demais (ganhar baú, entregar compra, concluir disputa com eventos,
// adicionar cavalo, registrar justa...) só o próprio servidor chama, depois de
// conferir. Cada função recebe (servico, ...argumentos) e devolve {ok, erro, ...}.

import { Aleatorio } from "../regra/aleatorio.ts";
import { semente_servico } from "./base.ts";
import * as J from "./jogador.ts";
import * as P from "./pve.ts";
import * as D from "./disputa.ts";
import * as L from "./liga.ts";
import type { Resultado, Servico } from "./base.ts";
import type { Candidato } from "./liga.ts";
import { comprar_recibo } from "./compras.ts";
import type { DepsCompras } from "./compras.ts";
import * as S from "./social.ts";
import type { BancoSocial } from "./social.ts";

// deno-lint-ignore no-explicit-any
type Comando = (s: Servico, ...args: any[]) => Resultado;

/** Disputa automática: a semente é do servidor (o cliente não escolhe o resultado). */
function disputa_automatica(s: Servico, torneio: string, indice: number): Resultado {
  return P.disputa_automatica(s, torneio, indice, new Aleatorio(semente_servico(s)).proximo());
}

/** Comandos que o cliente pode pedir (a Edge Function confere permissão, argumentos e limite). */
export const PUBLICOS: Record<string, Comando> = {
  criar_personagem: J.criar_personagem,
  definir_brasao: J.definir_brasao,
  equipar: J.equipar,
  definir_visual: J.definir_visual,
  usar_peca_trofeu: P.usar_peca_trofeu,
  equipar_habilidades: J.equipar_habilidades,
  melhorar_predio: J.melhorar_predio,
  concluir_timer: J.concluir_timer,
  treinar_cavaleiro: J.treinar_cavaleiro,
  treinar_cavalo: J.treinar_cavalo,
  usar_cavalo: J.usar_cavalo,
  consertar: J.consertar,
  forjar: J.forjar,
  melhorar_peca: J.melhorar_peca,
  fundir: J.fundir,
  resgatar_missao: J.resgatar_missao,
  resgatar_login: J.resgatar_login,
  definir_titulo: J.definir_titulo,
  comecar_abrir: J.comecar_abrir,
  abrir_bau: J.abrir_bau,
  comprar_com_gemas: J.comprar_com_gemas,
  usar_cosmetico: J.usar_cosmetico,
  pular_com_gemas: J.pular_com_gemas,
  resgatar_passe: J.resgatar_passe,
  marcar_oferta_vista: J.marcar_oferta_vista,
  recompensa_anuncio: J.recompensa_anuncio,
  marcar_cena_vista: J.marcar_cena_vista,
  definir_passo_tutorial: J.definir_passo_tutorial,
  recompensa_tutorial: J.recompensa_tutorial,
  definir_config: J.definir_config,
  definir_notificacao: J.definir_notificacao,
  disputa_automatica,
  iniciar_disputa: D.iniciar_disputa,
  iniciar_revanche: D.iniciar_revanche,
  concluir_disputa_conferida: D.concluir_disputa_conferida,
  abandonar_disputa: D.abandonar_disputa,
  salvar_defesa: L.salvar_defesa,
  comprar_da_ordem: S.comprar_da_ordem,
  remover_amigo: (s, id) => S.remover_amigo(s, id),
};

/** O banco que os comandos assíncronos usam para DECIDIR (as escritas saem em `_efeitos`). */
export interface BancoDeComandos extends BancoSocial {
  /** Jogadores reais com defesa salva, na faixa de poder, ordenados por proximidade de pontos. */
  candidatos_pvp(jogador: string, pontos: number, poder: number, faixa: number, limite: number): Promise<Candidato[]>;
  compra_existente: DepsCompras["compra_existente"];
  /** Conta uma chamada na janela (a mesma tabela do limite de ações, com outra faixa de chaves). */
  contar_chamada(jogador: string, janela: number): Promise<number>;
}

export interface DepsComando {
  banco: BancoDeComandos;
  verificador: DepsCompras["verificador"];
  loja_teste?: boolean;
}

// deno-lint-ignore no-explicit-any
type ComandoAssincrono = (s: Servico, args: any[], ctx: DepsComando, jogador: string) => Promise<Resultado>;

/** Comandos que precisam do banco para decidir (pareamento, ordem, chat...): públicos, idempotentes. */
export const ASSINCRONOS: Record<string, ComandoAssincrono> = {
  procurar_adversario: async (s, _args, ctx, jogador) => {
    const cfg = L.cfg_ligas(s);
    const lg = s.estado["liga"];
    const meu = J.poder_jogador(s);
    const candidatos = await ctx.banco.candidatos_pvp(jogador, Math.trunc(lg["pontos"]), meu, Math.trunc(cfg["faixa_poder"]), Math.trunc(cfg["fantasmas"]["candidatos"]));
    return L.escolher_adversario(s, candidatos);
  },
  // A partida de PvP conta como vitória no torneio da ordem (quem está numa).
  concluir_pvp_conferido: async (s, [entradas], ctx, jogador) => {
    const r = L.concluir_pvp_conferido(s, entradas);
    if (r.ok && r["venceu"]) {
      const p = await ctx.banco.ordem_do_jogador(jogador);
      if (p) S.ops(r, S.op_vitoria_torneio(s, p.ordem_id));
    }
    return r;
  },
  comprar_recibo: (s, [loja, produto, recibo], ctx, jogador) =>
    comprar_recibo(s, jogador, loja, produto, recibo, {
      verificador: ctx.verificador, loja_teste: ctx.loja_teste, compra_existente: ctx.banco.compra_existente.bind(ctx.banco),
    }),
  criar_ordem: (s, [nome, brasao, idioma], ctx, j) => S.criar_ordem(s, j, nome, brasao, idioma, ctx.banco),
  entrar_ordem: (s, [id], ctx, j) => S.entrar_ordem(s, j, id, ctx.banco),
  sair_ordem: (s, _a, ctx, j) => S.sair_ordem(s, j, ctx.banco),
  dissolver_ordem: (s, _a, ctx, j) => S.dissolver_ordem(s, j, ctx.banco),
  agir_sobre_membro: (s, [alvo, acao], ctx, j) => S.agir_sobre_membro(s, j, alvo, acao, ctx.banco),
  passar_lideranca: (s, [alvo], ctx, j) => S.passar_lideranca(s, j, alvo, ctx.banco),
  editar_ordem: (s, [nome, brasao], ctx, j) => S.editar_ordem(s, j, nome === "" ? null : nome, brasao, ctx.banco),
  pedir_ajuda: (s, [timer], ctx, j) => S.pedir_ajuda(s, j, timer, ctx.banco),
  ajudar_pedido: (s, [id], ctx, j) => S.ajudar_pedido(s, j, id, ctx.banco),
  doar: (s, [para, material, qtd], ctx, j) => S.doar(s, j, para, material, qtd, ctx.banco),
  torneio_semana: (s, _a, ctx, j) => S.torneio_semana(s, j, ctx.banco),
  resgatar_torneio: (s, _a, ctx, j) => S.resgatar_torneio(s, j, ctx.banco),
  chat_enviar: async (s, [canal, texto, rapida, idioma], ctx, j) => {
    // Limite próprio do chat por minuto (além do geral de ações): evita inundar o canal.
    const janela = 4_000_000_000_000 + Math.floor(s.agora() / 60);
    const n = await ctx.banco.contar_chamada(j, janela);
    if (n > Number(s.bal("servidor")["limites"]["chat_por_minuto"])) return { ok: false, erro: "enviando_rapido" };
    return await S.chat_enviar(s, j, canal, texto, rapida, idioma, ctx.banco);
  },
  adicionar_amigo_por_codigo: (s, [codigo], ctx, j) => S.adicionar_amigo_por_codigo(s, j, codigo, ctx.banco),
};

/** Comandos só do servidor (nunca expostos ao cliente). */
export const INTERNOS: Record<string, Comando> = {
  adicionar_cavalo: J.adicionar_cavalo,
  registrar_justa: J.registrar_justa,
  ganhar_bau: J.ganhar_bau,
  entregar_compra: J.entregar_compra,
  concluir_disputa: P.concluir_disputa,
  concluir_revanche: P.concluir_revanche,
  disputa_automatica_com_semente: P.disputa_automatica,
};

export const TODOS: Record<string, Comando> = { ...PUBLICOS, ...INTERNOS };
