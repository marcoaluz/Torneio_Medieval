// Notificações da loja (3.7): reembolso, renovação, cancelamento e expiração
// chegam por webhook (Google RTDN via Pub/Sub, App Store Server Notifications
// V2) e mudam o estado do jogador pelo MESMO caminho transacional das ações
// (aplicar_acao): idempotente pelo id da notificação, com o estado da compra
// registrado junto.

import { copiar } from "./base.ts";
import type { Dados, Servico } from "./base.ts";
import { aplicar_notificacao } from "./compras.ts";
import type { NotificacaoLoja } from "./compras.ts";
import type { Dependencias } from "./handler.ts";

export interface DepsWebhook extends Dependencias {
  /** Compra registrada pelo hash do recibo (de quem é e o que foi). */
  compra_por_hash(loja: string, recibo_hash: string): Promise<{ jogador_id: string; produto: string } | null>;
}

/** Uuid determinístico a partir do id da notificação (idempotência do webhook). */
export async function uuid_da_notificacao(loja: string, id_notificacao: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${loja}:${id_notificacao}`));
  const h = [...new Uint8Array(buf)].slice(0, 16).map((b) => b.toString(16).padStart(2, "0")).join("");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-4${h.slice(13, 16)}-8${h.slice(17, 20)}-${h.slice(20, 32)}`;
}

/** Aplica a notificação. Devolve {ok, erro, repetida?}. */
export async function tratar_notificacao(
  id_notificacao: string, n: NotificacaoLoja, dep: DepsWebhook,
): Promise<{ ok: boolean; erro: string; repetida?: boolean }> {
  const compra = await dep.compra_por_hash(n.loja, n.recibo_hash);
  if (!compra) return { ok: false, erro: "compra_desconhecida" };
  const id = await uuid_da_notificacao(n.loja, id_notificacao);
  const tentativas = Number(dep.bal("servidor")["limites"]["tentativas_conflito"]);
  for (let i = 0; i < tentativas; i++) {
    const atual = await dep.banco.carregar(compra.jogador_id);
    if (!atual) return { ok: false, erro: "jogador_sem_estado" };
    const estado: Dados = copiar(atual.estado);
    const agora = dep.agora();
    const s: Servico = { estado, bal: dep.bal, agora: () => agora };
    const r = aplicar_notificacao(s, n, { produto: compra.produto });
    if (!r.ok) {
      await dep.banco.guardar_resposta(compra.jogador_id, id, "notificacao_loja", r);
      return { ok: false, erro: r.erro };
    }
    const resposta: Dados = { ...r };
    const nova = await dep.banco.gravar(compra.jogador_id, estado, atual.revisao, { id, tipo: "notificacao_loja", resposta },
      { compra_estado: { loja: n.loja, recibo_hash: n.recibo_hash, estado: r["estado_compra"], valido_ate: n.valido_ate ?? null } });
    if (nova === "repetida") return { ok: true, erro: "", repetida: true };
    if (nova !== null) return { ok: true, erro: "" };
  }
  return { ok: false, erro: "conflito" };
}
