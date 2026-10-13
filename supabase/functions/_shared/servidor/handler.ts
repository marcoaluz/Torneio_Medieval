// Tratamento de uma ação do jogador (Edge Function `acao`, 3.2). Toda mudança
// de economia passa por aqui: valida argumentos, limita chamadas, é
// idempotente (o mesmo id devolve a mesma resposta e nunca entrega duas vezes),
// aplica o comando da regra em TypeScript sobre o estado do SERVIDOR, usa o
// relógio do servidor e grava com controle de revisão (concorrência).
//
// A lógica não conhece Deno nem Supabase: o banco entra por `Banco` (testado
// com um banco falso); a função do Supabase (acao/index.ts) só liga os fios.

import { PUBLICOS } from "./comandos.ts";
import { validar_argumentos } from "./esquema.ts";
import { novo_estado } from "./estado.ts";
import { copiar } from "./base.ts";
import type { Dados, Resultado, Servico } from "./base.ts";
import { anuncio_sem_assistir } from "./jogador.ts";

export interface Banco {
  /** Estado e revisão atuais do jogador; null se ainda não tem. */
  carregar(jogador: string): Promise<{ estado: Dados; revisao: number } | null>;
  /**
   * Grava o estado E a resposta da ação (idempotência) na MESMA transação, se a
   * revisão ainda for a esperada (null = criar o primeiro). Devolve a nova
   * revisão, "repetida" se o id já tinha resposta, ou null se houve conflito
   * (outra ação gravou antes). Atomicidade: nunca há estado gravado sem resposta.
   */
  gravar(jogador: string, estado: Dados, revisao_esperada: number | null, log: { id: string; tipo: string; resposta: Dados }):
    Promise<number | "repetida" | null>;
  /** Resposta já dada a esta ação (idempotência), se houver. */
  resposta_guardada(jogador: string, id: string): Promise<Dados | null>;
  /** Guarda a resposta; false se outra chamada com o mesmo id chegou antes. */
  guardar_resposta(jogador: string, id: string, tipo: string, resposta: Dados): Promise<boolean>;
  /** Conta uma chamada na janela (minuto) e devolve o total dela. */
  contar_chamada(jogador: string, janela: number): Promise<number>;
}

export interface Dependencias {
  banco: Banco;
  /** Balanceamento por nome (tabela `balanceamento` na produção). */
  bal(nome: string): Dados;
  /** Relógio do servidor em segundos Unix. */
  agora(): number;
  /** Inteiro aleatório de 31 bits (semente do jogador novo). */
  sorteio(): number;
  /** Confere o comprovante de um anúncio premiado com o provedor (SSV). */
  verificar_anuncio(jogador: string, token: string, tipo: string): Promise<boolean>;
}

export interface Entrada {
  jogador_id: string;
  id: string;
  tipo: string;
  args: unknown;
}

export interface Saida {
  status: number;
  corpo: Dados;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function recusar(status: number, codigo: string): Saida {
  return { status, corpo: { ok: false, erro: codigo } };
}

export async function tratar_acao(e: Entrada, dep: Dependencias): Promise<Saida> {
  const cfg = dep.bal("servidor");
  if (typeof e.id !== "string" || !UUID.test(e.id)) return recusar(400, "id_invalido");
  if (typeof e.tipo !== "string" || !Object.hasOwn(PUBLICOS, e.tipo)) return recusar(400, "comando_inexistente");
  const aviso = validar_argumentos(e.tipo, e.args, cfg["argumentos"]);
  if (aviso !== "") return recusar(400, aviso);

  // Repetição (rede ruim, toque duplo): devolve o que já foi respondido.
  const guardada = await dep.banco.resposta_guardada(e.jogador_id, e.id);
  if (guardada) return await repetida(e, dep, guardada);

  // Limite de chamadas por minuto.
  const agora = dep.agora();
  const total = await dep.banco.contar_chamada(e.jogador_id, Math.floor(agora / 60));
  if (total > Number(cfg["limites"]["acoes_por_minuto"])) return recusar(429, "muitas_chamadas");

  const tentativas = Number(cfg["limites"]["tentativas_conflito"]);
  for (let i = 0; i < tentativas; i++) {
    const atual = await dep.banco.carregar(e.jogador_id);
    const estado: Dados = atual ? copiar(atual.estado) : novo_estado(dep.bal, agora, dep.sorteio());
    const s: Servico = { estado, bal: dep.bal, agora: () => agora };
    const args = e.args as unknown[];

    // Anúncio premiado: o comprovante é conferido ANTES de entregar (o VIP dispensa).
    if (e.tipo === "recompensa_anuncio" && !anuncio_sem_assistir(s)) {
      const ok = await dep.verificar_anuncio(e.jogador_id, String(args[2]), String(args[0]));
      if (!ok) return await responder(e, dep, 200, { ok: false, erro: "anuncio_nao_confirmado" });
    }

    let r: Resultado;
    try {
      r = PUBLICOS[e.tipo](s, ...args);
    } catch (_erro) {
      // Dado inesperado numa função de regra: recusa sem mudar nada (e sem expor detalhe).
      return await responder(e, dep, 200, { ok: false, erro: "falha_interna" });
    }
    if (!r.ok) return await responder(e, dep, 200, r);

    const nova = await dep.banco.gravar(e.jogador_id, estado, atual ? atual.revisao : null, { id: e.id, tipo: e.tipo, resposta: r });
    if (nova === null) continue; // alguém gravou antes: refaz sobre o estado novo
    if (nova === "repetida") {
      const primeira = await dep.banco.resposta_guardada(e.jogador_id, e.id);
      return primeira ? await repetida(e, dep, primeira) : recusar(409, "conflito");
    }
    return { status: 200, corpo: { ...r, estado, revisao: nova } };
  }
  return recusar(409, "conflito");
}

/** Resposta sem mudança de estado (erro de regra): guarda para repetir igual. */
async function responder(e: Entrada, dep: Dependencias, status: number, corpo: Dados): Promise<Saida> {
  const ok = await dep.banco.guardar_resposta(e.jogador_id, e.id, e.tipo, corpo);
  if (!ok) {
    // Corrida: outra chamada com o mesmo id respondeu primeiro; vale a dela.
    const primeira = await dep.banco.resposta_guardada(e.jogador_id, e.id);
    if (primeira) return await repetida(e, dep, primeira);
  }
  return { status, corpo };
}

/** Repetição: a mesma resposta de antes, com o estado e a revisão de agora. */
async function repetida(e: Entrada, dep: Dependencias, guardada: Dados): Promise<Saida> {
  const atual = await dep.banco.carregar(e.jogador_id);
  const extra: Dados = atual ? { estado: atual.estado, revisao: atual.revisao } : {};
  return { status: 200, corpo: { ...guardada, ...extra, repetida: true } };
}
