// Edge Function `acao` (3.2): TODA mudança de economia do jogador passa por aqui.
// POST /functions/v1/acao  { id: uuid, tipo: string, args: [] }
//   -> { ok, erro, ...resultado, estado, revisao }  (ou { ok: false, erro } com status 4xx)
// Autenticada pelo JWT do jogador (verify_jwt ligado, o padrão). A chave de
// serviço fica só nos segredos da função; o app só conhece a chave publicável.
//
// NÃO PUBLICADA: depende das migrações 3.1/3.2 (supabase/migrations/) e da
// tabela de balanceamento preenchida (tools/exportar_balanceamento.sh).

import { createClient } from "npm:@supabase/supabase-js@2";
import { BancoSupabase, carregar_balanceamento } from "../_shared/servidor/banco_supabase.ts";
import { tratar_acao } from "../_shared/servidor/handler.ts";
import type { Dependencias } from "../_shared/servidor/handler.ts";
import { VerificadorGoogle } from "../_shared/servidor/loja_google.ts";
import { registrar_erro } from "../_shared/servidor/erros.ts";
import type { VerificadorLoja } from "../_shared/servidor/compras.ts";

const URL_PROJETO = Deno.env.get("SUPABASE_URL")!;
const CHAVE_SERVICO = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const cliente = createClient(URL_PROJETO, CHAVE_SERVICO, { auth: { persistSession: false } });

// Balanceamento em memória por 60 s (muda no painel sem lançar versão).
// deno-lint-ignore no-explicit-any
let cache_bal: { em: number; dados: Record<string, any> } | null = null;
async function balanceamento() {
  const agora = Date.now();
  if (!cache_bal || agora - cache_bal.em > 60_000) cache_bal = { em: agora, dados: await carregar_balanceamento(cliente) };
  return cache_bal.dados;
}

// Recibos: Google Play com a conta de serviço (segredos da função); sem ela, recusa tudo.
const verificador: VerificadorLoja = Deno.env.get("GOOGLE_PLAY_CLIENT_EMAIL")
  ? new VerificadorGoogle({
    pacote: Deno.env.get("GOOGLE_PLAY_PACOTE")!, email: Deno.env.get("GOOGLE_PLAY_CLIENT_EMAIL")!,
    chave_privada: Deno.env.get("GOOGLE_PLAY_PRIVATE_KEY")!, assinaturas: ["vip_mensal"],
  })
  : {
    verificar: async () => ({ valido: false, produto: "", transacao: "", erro: "loja_indisponivel" }),
    confirmar: async () => {},
  };

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(corpo: unknown, status = 200): Response {
  return new Response(JSON.stringify(corpo), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ ok: false, erro: "metodo" }, 405);
  try {
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: u, error } = await cliente.auth.getUser(token);
    if (error || !u.user) return json({ ok: false, erro: "nao_autenticado" }, 401);
    // Corpo pequeno: uma ação cabe em poucos KB (a justa conferida tem no máximo ~400 entradas).
    if (Number(req.headers.get("content-length") ?? 0) > 65536) return json({ ok: false, erro: "corpo_grande" }, 413);
    const corpo = await req.json();
    const dados = await balanceamento();
    const dep: Dependencias = {
      banco: new BancoSupabase(cliente),
      bal: (nome) => {
        if (!(nome in dados)) throw new Error("balanceamento ausente: " + nome);
        return dados[nome];
      },
      agora: () => Math.floor(Date.now() / 1000),
      sorteio: () => crypto.getRandomValues(new Uint32Array(1))[0] & 0x7FFFFFFF,
      verificador,
      loja_teste: Deno.env.get("PERMITIR_LOJA_TESTE") === "1",
      // SSV do provedor de anúncios (AdMob): a conferir quando a conta existir (3.9/3.10).
      verificar_anuncio: async () => false,
    };
    const r = await tratar_acao({ jogador_id: u.user.id, id: corpo.id, tipo: corpo.tipo, args: corpo.args }, dep);
    return json(r.corpo, r.status);
  } catch (e) {
    // Nunca devolve detalhe interno ao cliente; o registro fica na tabela erro_servidor.
    await registrar_erro(cliente, "acao", e);
    return json({ ok: false, erro: "falha_interna" }, 500);
  }
});
