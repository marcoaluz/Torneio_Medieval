// Compras (3.7): recibo conferido com a loja, entrega única, recibo de outro
// jogador, reembolso, renovação e webhook idempotente. A loja é falsa; o
// verificador do Google é testado com um fetch falso.

import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { hash_do_recibo } from "../../functions/_shared/servidor/compras.ts";
import type { Loja, VerificacaoRecibo, VerificadorLoja } from "../../functions/_shared/servidor/compras.ts";
import { tratar_notificacao, uuid_da_notificacao } from "../../functions/_shared/servidor/webhook.ts";
import type { DepsWebhook } from "../../functions/_shared/servidor/webhook.ts";
import { VerificadorGoogle } from "../../functions/_shared/servidor/loja_google.ts";
import { agir, bal, JOGADOR, montar, OUTRO, PERS } from "./fixtura.ts";
import type { Dados } from "./comum.ts";

/** Loja falsa: recibos conhecidos viram {produto, transacao}; guarda o que foi confirmado. */
class LojaFalsa implements VerificadorLoja {
  recibos = new Map<string, VerificacaoRecibo>();
  confirmados: string[] = [];
  async verificar(_l: Loja, _p: string, recibo: string) {
    return this.recibos.get(recibo) ?? { valido: false, produto: "", transacao: "", erro: "recibo_recusado" };
  }
  async confirmar(_l: Loja, _p: string, recibo: string) {
    this.confirmados.push(recibo);
  }
}

async function loja_pronta() {
  const m = montar();
  const compras = m.banco.compras;
  const loja = new LojaFalsa();
  m.dep.verificador = loja;
  await agir(m.dep, "criar_personagem", [PERS]);
  return { ...m, compras, loja };
}

describe("compra com recibo", () => {
  test("recibo válido entrega uma vez, registra e confirma com a loja", async () => {
    const { banco, dep, loja, compras } = await loja_pronta();
    loja.recibos.set("RECIBO-GEMAS-1", { valido: true, produto: "gemas_medio", transacao: "GPA.1" });
    const g0 = banco.estados.get(JOGADOR)!.estado["inventario"]["gemas"];
    const r = await agir(dep, "comprar_recibo", ["google", "gemas_medio", "RECIBO-GEMAS-1"]);
    assert.equal(r.corpo["ok"], true, JSON.stringify(r.corpo));
    assert.equal(r.corpo["teste"], false);
    assert.equal(banco.estados.get(JOGADOR)!.estado["inventario"]["gemas"], g0 + 450);
    assert.equal("_efeitos" in r.corpo || "_confirmar" in r.corpo, false);
    assert.deepEqual(loja.confirmados, ["RECIBO-GEMAS-1"]);
    const hash = await hash_do_recibo("RECIBO-GEMAS-1");
    assert.equal(compras.get(`google/${hash}`)?.produto, "gemas_medio");
    assert.equal(banco.estados.get(JOGADOR)!.estado["loja"]["compras"].length, 1);
  });

  test("o mesmo recibo de novo (outro id de ação) não entrega duas vezes", async () => {
    const { banco, dep, loja } = await loja_pronta();
    loja.recibos.set("RECIBO-GEMAS-2", { valido: true, produto: "gemas_pequeno", transacao: "GPA.2" });
    await agir(dep, "comprar_recibo", ["google", "gemas_pequeno", "RECIBO-GEMAS-2"]);
    const g1 = banco.estados.get(JOGADOR)!.estado["inventario"]["gemas"];
    const r = await agir(dep, "comprar_recibo", ["google", "gemas_pequeno", "RECIBO-GEMAS-2"]);
    assert.equal(r.corpo["ok"], true);
    assert.equal(r.corpo["repetida"], true);
    assert.equal(banco.estados.get(JOGADOR)!.estado["inventario"]["gemas"], g1);
  });

  test("recibo de outro jogador é fraude", async () => {
    const { banco, dep, loja } = await loja_pronta();
    loja.recibos.set("RECIBO-ALHEIO", { valido: true, produto: "gemas_grande", transacao: "GPA.3" });
    await agir(dep, "comprar_recibo", ["google", "gemas_grande", "RECIBO-ALHEIO"]);
    await agir(dep, "criar_personagem", [{ ...PERS, nome: "Beatriz" }], undefined, OUTRO);
    const g0 = banco.estados.get(OUTRO)!.estado["inventario"]["gemas"];
    const r = await agir(dep, "comprar_recibo", ["google", "gemas_grande", "RECIBO-ALHEIO"], undefined, OUTRO);
    assert.equal(r.corpo["erro"], "recibo_de_outro_jogador");
    assert.equal(banco.estados.get(OUTRO)!.estado["inventario"]["gemas"], g0);
  });

  test("recibo recusado, produto diferente, loja ou produto inexistentes", async () => {
    const { banco, dep, loja } = await loja_pronta();
    const g0 = banco.estados.get(JOGADOR)!.estado["inventario"]["gemas"];
    assert.equal((await agir(dep, "comprar_recibo", ["google", "gemas_medio", "RECIBO-FALSO-1"])).corpo["erro"], "recibo_recusado");
    loja.recibos.set("RECIBO-BARATO", { valido: true, produto: "gemas_pequeno", transacao: "GPA.4" });
    assert.equal((await agir(dep, "comprar_recibo", ["google", "gemas_grande", "RECIBO-BARATO"])).corpo["erro"], "produto_diferente");
    assert.equal((await agir(dep, "comprar_recibo", ["google", "produto_que_nao_existe", "RECIBO-FALSO-2"])).corpo["erro"], "produto_inexistente");
    assert.equal((await agir(dep, "comprar_recibo", ["pix", "gemas_medio", "RECIBO-FALSO-3"])).corpo["erro"], "loja_invalida");
    assert.equal((await agir(dep, "comprar_recibo", ["teste", "gemas_medio", "RECIBO-FALSO-4"])).corpo["erro"], "loja_indisponivel");
    assert.equal((await agir(dep, "comprar_recibo", ["google", "gemas_medio", "curto"])).corpo["erro"], "recibo_invalido");
    assert.equal(banco.estados.get(JOGADOR)!.estado["inventario"]["gemas"], g0);
  });

  test("VIP: assinatura, renovação estende e reembolso tira os dias", async () => {
    const { banco, dep, loja, relogio } = await loja_pronta();
    const agora = relogio.agora();
    loja.recibos.set("ASSINATURA-VIP-1", { valido: true, produto: "vip_mensal", transacao: "GPA.5", valido_ate: agora + 30 * 86400 });
    const r = await agir(dep, "comprar_recibo", ["google", "vip_mensal", "ASSINATURA-VIP-1"]);
    assert.equal(r.corpo["ok"], true);
    const e = banco.estados.get(JOGADOR)!.estado;
    assert.ok(e["loja"]["vip_ate"] > agora);

    const webhook: DepsWebhook = { ...dep, compra_por_hash: banco.compra_por_hash.bind(banco) };
    const hash = await hash_do_recibo("ASSINATURA-VIP-1");
    const g_antes = e["inventario"]["gemas"];
    relogio.avancar(31 * 86400);
    const renov = await tratar_notificacao("msg-1", { loja: "google", tipo: "renovada", recibo_hash: hash, valido_ate: relogio.agora() + 30 * 86400 }, webhook);
    assert.equal(renov.ok, true, JSON.stringify(renov));
    const e2 = banco.estados.get(JOGADOR)!.estado;
    assert.ok(e2["loja"]["vip_ate"] > relogio.agora() + 29 * 86400);
    assert.equal(e2["inventario"]["gemas"], g_antes + bal("economia")["vip"]["gemas_mes"]);
    // A mesma notificação de novo (a loja repete): nada muda.
    const rep = await tratar_notificacao("msg-1", { loja: "google", tipo: "renovada", recibo_hash: hash, valido_ate: relogio.agora() + 30 * 86400 }, webhook);
    assert.equal(rep.repetida, true);
    assert.equal(banco.estados.get(JOGADOR)!.estado["inventario"]["gemas"], g_antes + bal("economia")["vip"]["gemas_mes"]);
    // Reembolso: acaba o VIP agora.
    const ref = await tratar_notificacao("msg-2", { loja: "google", tipo: "reembolsada", recibo_hash: hash }, webhook);
    assert.equal(ref.ok, true);
    assert.ok(banco.estados.get(JOGADOR)!.estado["loja"]["vip_ate"] <= relogio.agora());
  });

  test("reembolso de gemas tira o que ainda tem (nunca abaixo de zero)", async () => {
    const { banco, dep, loja } = await loja_pronta();
    loja.recibos.set("RECIBO-GEMAS-RF", { valido: true, produto: "gemas_grande", transacao: "GPA.6" });
    await agir(dep, "comprar_recibo", ["google", "gemas_grande", "RECIBO-GEMAS-RF"]);
    const e = banco.estados.get(JOGADOR)!.estado;
    e["inventario"]["gemas"] = 300; // gastou parte
    const hash = await hash_do_recibo("RECIBO-GEMAS-RF");
    const webhook: DepsWebhook = { ...dep, compra_por_hash: banco.compra_por_hash.bind(banco) };
    const r = await tratar_notificacao("msg-3", { loja: "google", tipo: "reembolsada", recibo_hash: hash }, webhook);
    assert.equal(r.ok, true);
    assert.equal(banco.estados.get(JOGADOR)!.estado["inventario"]["gemas"], 0);
    const desconhecida = await tratar_notificacao("msg-4", { loja: "google", tipo: "reembolsada", recibo_hash: "00" }, webhook);
    assert.equal(desconhecida.erro, "compra_desconhecida");
  });

  test("uuid da notificação é estável e válido", async () => {
    const a = await uuid_da_notificacao("google", "msg-1");
    assert.equal(a, await uuid_da_notificacao("google", "msg-1"));
    assert.notEqual(a, await uuid_da_notificacao("google", "msg-2"));
    assert.match(a, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-8[0-9a-f]{3}-[0-9a-f]{12}$/);
  });
});

describe("verificador do Google (fetch falso)", () => {
  async function chave_pem(): Promise<string> {
    const par = await crypto.subtle.generateKey(
      { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"]);
    const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", par.privateKey));
    let s = "";
    for (const b of der) s += String.fromCharCode(b);
    return `-----BEGIN PRIVATE KEY-----\n${btoa(s)}\n-----END PRIVATE KEY-----`;
  }

  test("produto pago vale; cancelado não; confirma com acknowledge", async () => {
    const chamadas: { url: string; metodo: string }[] = [];
    let estado_compra = 0;
    const fetch_falso = (async (url: string, init?: Dados) => {
      chamadas.push({ url: String(url), metodo: init?.["method"] ?? "GET" });
      if (String(url).includes("oauth2.googleapis.com")) return new Response(JSON.stringify({ access_token: "tok", expires_in: 3600 }));
      if (String(url).endsWith(":acknowledge")) return new Response("{}");
      return new Response(JSON.stringify({ purchaseState: estado_compra, orderId: "GPA.9" }));
    }) as unknown as typeof fetch;
    const v = new VerificadorGoogle({
      pacote: "com.exemplo.jogo", email: "servico@exemplo.iam.gserviceaccount.com", chave_privada: await chave_pem(),
      assinaturas: ["vip_mensal"], fetch: fetch_falso,
    });
    const ok = await v.verificar("google", "gemas_medio", "TOKEN123");
    assert.deepEqual([ok.valido, ok.produto, ok.transacao], [true, "gemas_medio", "GPA.9"]);
    estado_compra = 1;
    const cancelado = await v.verificar("google", "gemas_medio", "TOKEN123");
    assert.equal(cancelado.valido, false);
    await v.confirmar("google", "gemas_medio", "TOKEN123");
    assert.ok(chamadas.some((c) => c.url.endsWith("/products/gemas_medio/tokens/TOKEN123:acknowledge") && c.metodo === "POST"));
    assert.ok(chamadas.some((c) => c.url.includes("/purchases/products/gemas_medio/tokens/TOKEN123") && c.metodo === "GET"));
    assert.equal(chamadas.filter((c) => c.url.includes("oauth2.googleapis.com")).length, 1, "o token de acesso é reaproveitado");
  });
});
