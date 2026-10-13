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
import type { Resultado, Servico } from "./base.ts";

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
  concluir_disputa_conferida: D.concluir_disputa_conferida,
  abandonar_disputa: D.abandonar_disputa,
};

/** Comandos só do servidor (nunca expostos ao cliente). */
export const INTERNOS: Record<string, Comando> = {
  adicionar_cavalo: J.adicionar_cavalo,
  registrar_justa: J.registrar_justa,
  ganhar_bau: J.ganhar_bau,
  entregar_compra: J.entregar_compra,
  concluir_disputa: P.concluir_disputa,
  disputa_automatica_com_semente: P.disputa_automatica,
};

export const TODOS: Record<string, Comando> = { ...PUBLICOS, ...INTERNOS };
