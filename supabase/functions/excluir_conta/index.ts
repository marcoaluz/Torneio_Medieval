// Edge Function `excluir_conta` (3.9): o jogador apaga a própria conta.
// POST /functions/v1/excluir_conta  { confirmacao: "EXCLUIR" }
// Autenticada pelo JWT do jogador; quem apaga é a chave de serviço (só aqui).
// NÃO PUBLICADA (depende das migrações 3.1).

import { createClient } from "npm:@supabase/supabase-js@2";
import { excluir_conta } from "../_shared/servidor/excluir_conta.ts";
import { registrar_erro } from "../_shared/servidor/erros.ts";

const cliente = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return new Response("metodo", { status: 405, headers: CORS });
  const corpo = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), { status, headers: { ...CORS, "Content-Type": "application/json" } });
  try {
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: u, error } = await cliente.auth.getUser(token);
    if (error || !u.user) return corpo({ ok: false, erro: "nao_autenticado" }, 401);
    const { confirmacao } = await req.json();
    const r = await excluir_conta(cliente, u.user.id, confirmacao);
    return corpo(r, r.ok ? 200 : 400);
  } catch (e) {
    await registrar_erro(cliente, "excluir_conta", e);
    return corpo({ ok: false, erro: "falha_interna" }, 500);
  }
});
