// Conferência de recibos da Google Play (Google Play Developer API). NÃO
// EXERCITADO contra a loja real: precisa da conta de serviço do Play Console
// (segredos GOOGLE_PLAY_CLIENT_EMAIL, GOOGLE_PLAY_PRIVATE_KEY e o nome do
// pacote). Escrito pela documentação pública; testar com uma compra de teste
// licenciada antes de lançar (auditoria 3.11).
//
//  - OAuth: JWT RS256 da conta de serviço -> token de acesso (escopo androidpublisher);
//  - produto avulso (gemas, passe): GET purchases/products/{produto}/tokens/{token}
//    (purchaseState 0 = pago) e POST ...:acknowledge para confirmar a entrega;
//  - assinatura (VIP): GET purchases/subscriptionsv2/tokens/{token}
//    (subscriptionState ACTIVE, lineItems[].expiryTime).

import type { Loja, VerificacaoRecibo, VerificadorLoja } from "./compras.ts";

export interface ConfigGoogle {
  pacote: string;
  email: string;
  chave_privada: string; // PEM PKCS#8
  /** Quais produtos são assinatura (o resto é produto avulso). */
  assinaturas: string[];
  /** fetch injetável (testes). */
  fetch?: typeof fetch;
}

const API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";

function base64url(bytes: ArrayBuffer | Uint8Array | string): string {
  const b = typeof bytes === "string" ? new TextEncoder().encode(bytes) : new Uint8Array(bytes as ArrayBuffer);
  let s = "";
  for (const x of b) s += String.fromCharCode(x);
  return btoa(s).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

async function assinar_jwt(email: string, chave_pem: string, agora: number): Promise<string> {
  const corpo = chave_pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(corpo), (c) => c.charCodeAt(0));
  const chave = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const cabecalho = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: email, scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token", iat: agora, exp: agora + 3600,
  }));
  const assinatura = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", chave, new TextEncoder().encode(`${cabecalho}.${claims}`));
  return `${cabecalho}.${claims}.${base64url(assinatura)}`;
}

export class VerificadorGoogle implements VerificadorLoja {
  private cfg: ConfigGoogle;
  private token: { valor: string; ate: number } | null = null;

  constructor(cfg: ConfigGoogle) {
    this.cfg = cfg;
  }

  private async acesso(): Promise<string> {
    const agora = Math.floor(Date.now() / 1000);
    if (this.token && this.token.ate > agora + 60) return this.token.valor;
    const f = this.cfg.fetch ?? fetch;
    const jwt = await assinar_jwt(this.cfg.email, this.cfg.chave_privada, agora);
    const r = await f("https://oauth2.googleapis.com/token", {
      method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
    });
    if (!r.ok) throw new Error("google oauth " + r.status);
    const d = await r.json();
    this.token = { valor: d.access_token, ate: agora + Number(d.expires_in ?? 3000) };
    return this.token.valor;
  }

  async verificar(_loja: Loja, produto: string, recibo: string): Promise<VerificacaoRecibo> {
    const f = this.cfg.fetch ?? fetch;
    const acesso = await this.acesso();
    const assinatura = this.cfg.assinaturas.includes(produto);
    const url = assinatura
      ? `${API}/${this.cfg.pacote}/purchases/subscriptionsv2/tokens/${encodeURIComponent(recibo)}`
      : `${API}/${this.cfg.pacote}/purchases/products/${encodeURIComponent(produto)}/tokens/${encodeURIComponent(recibo)}`;
    const r = await f(url, { headers: { Authorization: `Bearer ${acesso}` } });
    if (!r.ok) return { valido: false, produto, transacao: "", erro: "recibo_recusado" };
    const d = await r.json();
    if (assinatura) {
      const item = (d.lineItems ?? [])[0] ?? {};
      const ativa = d.subscriptionState === "SUBSCRIPTION_STATE_ACTIVE" || d.subscriptionState === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD";
      const ate = item.expiryTime ? Math.floor(Date.parse(item.expiryTime) / 1000) : 0;
      return { valido: ativa && ate > 0, produto: item.productId ?? "", transacao: String(d.latestOrderId ?? ""), valido_ate: ate,
        erro: ativa ? undefined : "assinatura_inativa" };
    }
    // purchaseState: 0 comprado, 1 cancelado, 2 pendente. Só 0 vale.
    return { valido: d.purchaseState === 0, produto, transacao: String(d.orderId ?? ""), erro: d.purchaseState === 0 ? undefined : "compra_nao_paga" };
  }

  async confirmar(_loja: Loja, produto: string, recibo: string): Promise<void> {
    if (this.cfg.assinaturas.includes(produto)) {
      return; // o acknowledge de assinatura é feito na primeira compra pelo mesmo endpoint de produtos v2 (conferir no teste)
    }
    const f = this.cfg.fetch ?? fetch;
    const acesso = await this.acesso();
    await f(`${API}/${this.cfg.pacote}/purchases/products/${encodeURIComponent(produto)}/tokens/${encodeURIComponent(recibo)}:acknowledge`, {
      method: "POST", headers: { Authorization: `Bearer ${acesso}`, "Content-Type": "application/json" }, body: "{}",
    });
  }
}
