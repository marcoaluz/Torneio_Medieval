// Compras no servidor (3.7): nada é entregue só porque o celular disse que
// pagou. O recibo da Google Play (ou da App Store) é conferido com a loja por
// quem NÃO é o celular; o mesmo recibo nunca entrega duas vezes; reembolso,
// cancelamento e renovação chegam por notificação da loja e mudam o estado.
//
// A conferência com a loja entra por `VerificadorLoja` (Google implementado em
// loja_google.ts; Apple e o provedor de teste em loja_teste.ts). Entrega e
// registro (`compra`) saem na MESMA transação do estado (efeito `compra`).

import { concluir, erro, gemas, inteiro } from "./base.ts";
import type { Dados, Resultado, Servico } from "./base.ts";
import { entregar_compra } from "./jogador.ts";

export type Loja = "google" | "apple" | "teste";

export interface VerificacaoRecibo {
  /** O recibo é de uma compra paga e valida (não cancelada, não reembolsada). */
  valido: boolean;
  /** Produto que a loja diz ter sido comprado (tem que ser o pedido). */
  produto: string;
  /** Identificador único da transação na loja (pedido/transaction id). */
  transacao: string;
  /** Assinatura: quando termina o período pago (segundos Unix). */
  valido_ate?: number;
  /** Motivo, quando não é válido. */
  erro?: string;
}

export interface VerificadorLoja {
  verificar(loja: Loja, produto: string, recibo: string): Promise<VerificacaoRecibo>;
  /** Confirma (acknowledge/consume) a entrega com a loja; sem isso o Google reembolsa em 3 dias. */
  confirmar(loja: Loja, produto: string, recibo: string): Promise<void>;
}

/** Lê o que o banco sabe de uma compra já registrada: de quem é e em que estado está. */
export interface DepsCompras {
  verificador: VerificadorLoja;
  /** O ambiente permite a "loja" de teste (variável de ambiente, nunca em produção). */
  loja_teste?: boolean;
  compra_existente(loja: string, recibo_hash: string): Promise<{ jogador_id: string; estado: string } | null>;
}

const LOJAS: Loja[] = ["google", "apple", "teste"];

/** Produtos que existem (gemas, VIP, passe e ofertas do catálogo). */
export function produto_existe(s: Servico, produto: string): boolean {
  const cfg = s.bal("loja");
  return (cfg["gemas"] as Dados[]).some((g) => g["id"] === produto) || produto === cfg["vip"]["id"] ||
    produto === cfg["passe"]["id"] || (cfg["ofertas"] as Dados[]).some((o) => o["id"] === produto);
}

/** SHA-256 em hexadecimal (o recibo bruto não é guardado: só o hash). */
export async function hash_do_recibo(recibo: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(recibo));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Compra com recibo: confere com a loja, entrega uma vez e registra.
 * Devolve {ok, entregue, repetida?} e o efeito `compra` para o banco.
 */
export async function comprar_recibo(
  s: Servico, jogador: string, loja: string, produto: string, recibo: string, dep: DepsCompras,
): Promise<Resultado> {
  if (!LOJAS.includes(loja as Loja)) return erro("loja_invalida");
  if (loja === "teste" && !dep.loja_teste) return erro("loja_indisponivel");
  if (!produto_existe(s, produto)) return erro("produto_inexistente");
  if (recibo.length < 8 || recibo.length > 4096) return erro("recibo_invalido");
  const hash = await hash_do_recibo(recibo);

  // Mesmo recibo de novo: se é meu, é repetição (não entrega); se é de outro, é fraude.
  const antes = await dep.compra_existente(loja, hash);
  if (antes) {
    if (antes.jogador_id !== jogador) return erro("recibo_de_outro_jogador");
    return { ...concluir(), repetida: true, estado_compra: antes.estado };
  }

  const v = await dep.verificador.verificar(loja as Loja, produto, recibo);
  if (!v.valido) return erro(v.erro || "recibo_recusado");
  if (v.produto !== produto) return erro("produto_diferente");

  const r = entregar_compra(s, produto, loja === "teste");
  if (!r.ok) return r;
  return {
    ...r,
    _efeitos: { compra: { loja, produto, recibo_hash: hash, transacao: v.transacao, valido_ate: v.valido_ate ?? null } },
    _confirmar: { loja, produto, recibo },
  };
}

// ------------------------------------------------- notificações da loja

export type TipoNotificacao = "renovada" | "reembolsada" | "cancelada" | "expirada";

export interface NotificacaoLoja {
  loja: Loja;
  tipo: TipoNotificacao;
  /** Hash do recibo/token de origem (liga a notificação à compra registrada). */
  recibo_hash: string;
  /** Renovação: novo fim do período pago (segundos Unix). */
  valido_ate?: number;
}

/**
 * Efeito de uma notificação da loja sobre o estado do jogador (a Edge Function
 * `loja_webhook` chama isto como comando interno, com idempotência pelo id da
 * notificação). Devolve o novo estado da compra para o banco.
 *  - reembolsada: gemas e dias de VIP voltam atrás (nunca abaixo de zero);
 *  - renovada: estende o VIP até o fim do período pago (+ gemas do mês);
 *  - cancelada: nada muda (vale até o fim do período);
 *  - expirada: VIP termina agora.
 */
export function aplicar_notificacao(s: Servico, n: NotificacaoLoja, compra: { produto: string }): Resultado {
  const cfg = s.bal("loja");
  const lj = s.estado["loja"];
  const produto = compra.produto;
  switch (n.tipo) {
    case "reembolsada": {
      const g = (cfg["gemas"] as Dados[]).find((x) => x["id"] === produto);
      if (g) {
        const tira = Math.min(gemas(s), inteiro(g["gemas"]));
        s.estado["inventario"]["gemas"] = gemas(s) - tira;
      } else if (produto === cfg["vip"]["id"]) {
        lj["vip_ate"] = Math.min(inteiro(lj["vip_ate"]), s.agora());
      } else if (produto === cfg["passe"]["id"]) {
        lj["passe"]["premium"] = false;
      }
      return { ...concluir(), estado_compra: "reembolsada" };
    }
    case "renovada": {
      if (produto !== cfg["vip"]["id"]) return erro("nao_renovavel");
      const ate = inteiro(n.valido_ate ?? 0);
      if (ate <= s.agora()) return erro("renovacao_invalida");
      lj["vip_ate"] = Math.max(inteiro(lj["vip_ate"]), ate);
      const gm = inteiro(s.bal("economia")["vip"]["gemas_mes"]);
      s.estado["inventario"]["gemas"] = gemas(s) + gm;
      return { ...concluir(), estado_compra: "validada", gemas: gm };
    }
    case "cancelada":
      return { ...concluir(), estado_compra: "cancelada" };
    case "expirada":
      if (produto === cfg["vip"]["id"]) lj["vip_ate"] = Math.min(inteiro(lj["vip_ate"]), s.agora());
      return { ...concluir(), estado_compra: "expirada" };
  }
}
