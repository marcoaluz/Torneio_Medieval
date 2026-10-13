// Edge Function `loja_webhook` (3.7): notificações da Google Play (RTDN via
// Pub/Sub push). Reembolso, renovação, cancelamento e expiração mudam o estado
// do jogador pelo mesmo caminho transacional das ações.
//   POST /functions/v1/loja_webhook?s=<segredo>
// SEM verify_jwt (quem chama é o Pub/Sub, não um jogador): a autenticação é o
// segredo na URL (LOJA_WEBHOOK_SEGREDO nos segredos da função), comparado em
// tempo constante. Deploy: `supabase functions deploy loja_webhook --no-verify-jwt`.
//
// NÃO PUBLICADA: depende da conta do Play Console e do tópico Pub/Sub (docs/SERVIDOR.md).

import { createClient } from "npm:@supabase/supabase-js@2";
import { BancoSupabase, carregar_balanceamento } from "../_shared/servidor/banco_supabase.ts";
import { hash_do_recibo } from "../_shared/servidor/compras.ts";
import type { NotificacaoLoja } from "../_shared/servidor/compras.ts";
import { VerificadorGoogle } from "../_shared/servidor/loja_google.ts";
import { tratar_notificacao } from "../_shared/servidor/webhook.ts";
import type { DepsWebhook } from "../_shared/servidor/webhook.ts";

const cliente = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

function iguais(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

/** Notificação do Google -> o que fazer (renovação consulta o fim do período na loja). */
async function interpretar(msg: Record<string, any>, verificador: VerificadorGoogle): Promise<{ n: NotificacaoLoja; produto: string } | null> {
  const sub = msg["subscriptionNotification"];
  const unico = msg["oneTimeProductNotification"];
  const anulada = msg["voidedPurchaseNotification"];
  if (anulada) {
    return { n: { loja: "google", tipo: "reembolsada", recibo_hash: await hash_do_recibo(String(anulada["purchaseToken"])) }, produto: "" };
  }
  if (sub) {
    const token = String(sub["purchaseToken"]);
    const base = { loja: "google" as const, recibo_hash: await hash_do_recibo(token) };
    // 2 renovada, 3 cancelada, 12 revogada, 13 expirada (códigos do RTDN)
    switch (Number(sub["notificationType"])) {
      case 2: {
        const v = await verificador.verificar("google", String(sub["subscriptionId"]), token);
        return { n: { ...base, tipo: "renovada", valido_ate: v.valido_ate }, produto: String(sub["subscriptionId"]) };
      }
      case 3: return { n: { ...base, tipo: "cancelada" }, produto: String(sub["subscriptionId"]) };
      case 12: return { n: { ...base, tipo: "reembolsada" }, produto: String(sub["subscriptionId"]) };
      case 13: return { n: { ...base, tipo: "expirada" }, produto: String(sub["subscriptionId"]) };
    }
    return null;
  }
  if (unico && Number(unico["notificationType"]) === 2) {
    return { n: { loja: "google", tipo: "reembolsada", recibo_hash: await hash_do_recibo(String(unico["purchaseToken"])) }, produto: String(unico["sku"]) };
  }
  return null;
}

Deno.serve(async (req) => {
  const segredo = Deno.env.get("LOJA_WEBHOOK_SEGREDO") ?? "";
  const dado = new URL(req.url).searchParams.get("s") ?? "";
  if (segredo === "" || !iguais(dado, segredo)) return new Response("nao_autorizado", { status: 401 });
  try {
    const corpo = await req.json();
    const id = String(corpo?.message?.messageId ?? "");
    const dados = JSON.parse(atob(String(corpo?.message?.data ?? "")));
    const verificador = new VerificadorGoogle({
      pacote: Deno.env.get("GOOGLE_PLAY_PACOTE")!, email: Deno.env.get("GOOGLE_PLAY_CLIENT_EMAIL")!,
      chave_privada: Deno.env.get("GOOGLE_PLAY_PRIVATE_KEY")!, assinaturas: ["vip_mensal"],
    });
    const i = await interpretar(dados, verificador);
    if (!i || id === "") return new Response("ignorada", { status: 200 }); // o Pub/Sub não reenvia 2xx
    const bal = await carregar_balanceamento(cliente);
    const banco = new BancoSupabase(cliente);
    const dep: DepsWebhook = {
      banco, bal: (nome) => bal[nome], agora: () => Math.floor(Date.now() / 1000), sorteio: () => 0,
      verificar_anuncio: async () => false, verificador,
      compra_por_hash: banco.compra_por_hash.bind(banco),
    };
    const r = await tratar_notificacao(id, i.n, dep);
    // Compra desconhecida: 200 mesmo assim (pode ser de outro ambiente); erro de verdade: 500 para o Pub/Sub reenviar.
    if (!r.ok && r.erro !== "compra_desconhecida") return new Response(r.erro, { status: 500 });
    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error("loja_webhook falhou:", e);
    return new Response("falha_interna", { status: 500 });
  }
});
