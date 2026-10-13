// Fixtura dos testes do servidor: balanceamento dos arquivos do jogo, banco
// falso em memória (com os efeitos relacionais e os candidatos de PvP) e
// atalhos para agir como um jogador.

import { readFileSync } from "node:fs";
import { tratar_acao } from "../../functions/_shared/servidor/handler.ts";
import type { Banco, Dependencias } from "../../functions/_shared/servidor/handler.ts";
import type { VerificadorLoja } from "../../functions/_shared/servidor/compras.ts";
import type { Candidato } from "../../functions/_shared/servidor/liga.ts";
import type { Membro, PedidoAjuda } from "../../functions/_shared/servidor/social.ts";
import type { Dados } from "./comum.ts";

const RAIZ = new URL("../../../", import.meta.url);
const ARQUIVOS: Record<string, string> = {
  historia: "game/data/historia/historia.json",
  nomes_proibidos: "game/data/texto/nomes_proibidos.json",
  nomes_sorteio: "game/data/texto/nomes_sorteio.json",
  acessibilidade: "game/data/ui/acessibilidade.json",
  paletas: "game/data/personagem/paletas.json",
  chat_rapido: "game/data/social/chat.json",
};
const cache: Record<string, Dados> = {};

/** Dados de balanceamento dos arquivos do jogo (na produção vêm da tabela `balanceamento`). */
export function bal(nome: string): Dados {
  if (!(nome in cache)) {
    cache[nome] = JSON.parse(readFileSync(new URL(ARQUIVOS[nome] ?? `game/data/balance/${nome}.json`, RAIZ), "utf-8"));
  }
  return cache[nome];
}

export const JOGADOR = "11111111-1111-4111-8111-111111111111";
export const OUTRO = "22222222-2222-4222-8222-222222222222";
let contador = 0;
export const uuid = () => `00000000-0000-4000-8000-${String(++contador).padStart(12, "0")}`;

export class BancoFalso implements Banco {
  estados = new Map<string, { estado: Dados; revisao: number }>();
  respostas = new Map<string, Dados>();
  chamadas = new Map<string, number>();
  /** Efeitos relacionais gravados, na ordem. */
  efeitos: { jogador: string; efeitos: Dados }[] = [];
  /** Candidatos de PvP devolvidos (o teste preenche). */
  candidatos: Candidato[] = [];
  /** Relacional em memória (o que o SQL de aplicar_ops_sociais faria). */
  ordens = new Map<string, { id: string; nome: string; brasao: Dados; idioma: string }>();
  membros_de = new Map<string, Map<string, string>>(); // ordem_id -> jogador -> cargo
  nomes = new Map<string, string>(); // jogador -> nome (para a lista de membros)
  pedidos = new Map<string, { id: string; ordem_id: string; jogador_id: string; timer_id: string; tipo: string; ajudas: number; ajudas_max: number; expira_em: number }>();
  ajudas: { pedido_id: string; ajudante_id: string; aplicada: boolean }[] = [];
  doacoes: { id: number; ordem_id: string; de_id: string; para_id: string; material: string; quantidade: number; dia: number; aplicada: boolean }[] = [];
  chat: { canal: string; de_id: string; de_nome: string; texto: string; chave: string }[] = [];
  amizades = new Set<string>(); // "a|b" nos dois sentidos
  codigos = new Map<string, string>(); // codigo -> jogador
  torneio_tabela = new Map<string, number>(); // semana|ordem|jogador -> vitorias
  silenciados = new Map<string, number>();
  /** Relógio do banco (segundos), para expirar pedidos. */
  agora_banco = () => Math.floor(Date.now() / 1000);
  /** Compras registradas por efeito (loja/hash -> dono, produto, estado). */
  compras = new Map<string, { jogador_id: string; produto: string; estado: string }>();
  /** Gancho para simular outra ação gravando antes (conflito). */
  antes_de_gravar: (() => void) | null = null;
  gravacoes = 0;

  async carregar(j: string) {
    const e = this.estados.get(j);
    return e ? { estado: structuredClone(e.estado), revisao: e.revisao } : null;
  }
  async gravar(j: string, estado: Dados, esperada: number | null, log: { id: string; tipo: string; resposta: Dados }, efeitos: Dados = {}) {
    if (this.antes_de_gravar) {
      const g = this.antes_de_gravar;
      this.antes_de_gravar = null;
      g();
    }
    if (this.respostas.has(`${j}/${log.id}`)) return "repetida" as const;
    const atual = this.estados.get(j);
    if ((atual?.revisao ?? null) !== esperada) return null;
    // Operações sociais: se alguma invariante quebra, a ação inteira é desfeita (conflito).
    const snapshot = {
      ordens: structuredClone([...this.ordens]), membros: structuredClone([...this.membros_de].map(([k, v]) => [k, [...v]])),
      pedidos: structuredClone([...this.pedidos]), ajudas: structuredClone(this.ajudas), doacoes: structuredClone(this.doacoes),
      chat: structuredClone(this.chat), amizades: new Set(this.amizades), torneio: new Map(this.torneio_tabela),
    };
    try {
      this.aplicar_ops(j, (efeitos["social"] as Dados[]) ?? []);
    } catch (e) {
      if ((e as Error).message !== "conflito_de_revisao") throw e;
      this.ordens = new Map(snapshot.ordens as never);
      this.membros_de = new Map((snapshot.membros as [string, [string, string][]][]).map(([k, v]) => [k, new Map(v)]));
      this.pedidos = new Map(snapshot.pedidos as never);
      this.ajudas = snapshot.ajudas;
      this.doacoes = snapshot.doacoes;
      this.chat = snapshot.chat;
      this.amizades = snapshot.amizades;
      this.torneio_tabela = snapshot.torneio;
      return null;
    }
    const nova = (atual?.revisao ?? 0) + 1;
    this.estados.set(j, { estado: structuredClone(estado), revisao: nova });
    this.respostas.set(`${j}/${log.id}`, structuredClone(log.resposta));
    this.efeitos.push({ jogador: j, efeitos: structuredClone(efeitos) });
    const c = efeitos["compra"];
    if (c) this.compras.set(`${c["loja"]}/${c["recibo_hash"]}`, { jogador_id: j, produto: c["produto"], estado: "validada" });
    const ce = efeitos["compra_estado"];
    if (ce) {
      const x = this.compras.get(`${ce["loja"]}/${ce["recibo_hash"]}`);
      if (x) x.estado = ce["estado"];
    }
    this.gravacoes += 1;
    return nova;
  }
  async resposta_guardada(j: string, id: string) {
    return this.respostas.get(`${j}/${id}`) ?? null;
  }
  async guardar_resposta(j: string, id: string, _tipo: string, resposta: Dados) {
    if (this.respostas.has(`${j}/${id}`)) return false;
    this.respostas.set(`${j}/${id}`, structuredClone(resposta));
    return true;
  }
  async contar_chamada(j: string, janela: number) {
    const k = `${j}/${janela}`;
    this.chamadas.set(k, (this.chamadas.get(k) ?? 0) + 1);
    return this.chamadas.get(k) as number;
  }
  // ---- leituras sociais
  async ordem_do_jogador(j: string) {
    for (const [oid, ms] of this.membros_de) {
      const cargo = ms.get(j);
      if (cargo) return { ordem_id: oid, cargo };
    }
    return null;
  }
  async ordem(oid: string) {
    return this.ordens.get(oid) ?? null;
  }
  async membros(oid: string): Promise<Membro[]> {
    return [...(this.membros_de.get(oid) ?? new Map()).entries()].map(([jogador_id, cargo]) => ({
      jogador_id, cargo, nome: this.nomes.get(jogador_id) ?? jogador_id, poder: 10,
    }));
  }
  async nome_de_ordem_livre(nome: string) {
    return ![...this.ordens.values()].some((o) => o.nome.toLowerCase() === nome.toLowerCase());
  }
  async pedidos_abertos(oid: string, agora: number, jogador: string): Promise<PedidoAjuda[]> {
    return [...this.pedidos.values()].filter((p) => p.ordem_id === oid && p.expira_em > agora)
      .map((p) => ({
        id: p.id, jogador_id: p.jogador_id, timer_id: p.timer_id, tipo: p.tipo, ajudas: p.ajudas, ajudas_max: p.ajudas_max,
        ajudado_por_mim: this.ajudas.some((a) => a.pedido_id === p.id && a.ajudante_id === jogador),
      }));
  }
  async ajudas_pendentes(j: string) {
    return this.ajudas.filter((a) => !a.aplicada && this.pedidos.get(a.pedido_id)?.jogador_id === j)
      .map((a) => ({ pedido_id: a.pedido_id, ajudante_id: a.ajudante_id, timer_id: this.pedidos.get(a.pedido_id)!.timer_id }));
  }
  async doacoes_pendentes(j: string) {
    return this.doacoes.filter((d) => d.para_id === j && !d.aplicada).map((d) => ({ id: d.id, material: d.material, quantidade: d.quantidade }));
  }
  async doado_no_dia(j: string, dia: number) {
    return this.doacoes.filter((d) => d.de_id === j && d.dia === dia).reduce((a, d) => a + d.quantidade, 0);
  }
  async jogador_por_codigo(c: string) {
    const j = this.codigos.get(c);
    return j ? { jogador_id: j, nome: this.nomes.get(j) ?? j } : null;
  }
  async silenciado_ate(j: string) {
    return this.silenciados.get(j) ?? null;
  }
  async torneio(semana: number, limite: number) {
    const por_ordem = new Map<string, number>();
    for (const [k, v] of this.torneio_tabela) {
      const [sem, oid] = k.split("|");
      if (Number(sem) === semana) por_ordem.set(oid, (por_ordem.get(oid) ?? 0) + v);
    }
    return [...por_ordem.entries()].map(([ordem_id, vitorias]) => ({ ordem_id, nome: this.ordens.get(ordem_id)?.nome ?? ordem_id, vitorias }))
      .sort((a, b) => b.vitorias - a.vitorias).slice(0, limite);
  }
  async amigos(j: string) {
    return [...this.amizades].filter((x) => x.startsWith(j + "|")).map((x) => x.split("|")[1]);
  }

  /** Emula aplicar_ops_sociais; lança "conflito_de_revisao" como o SQL. */
  aplicar_ops(j: string, ops: Dados[]) {
    const conflito = () => { throw new Error("conflito_de_revisao"); };
    const cargo_de = (oid: string, jog: string) => this.membros_de.get(oid)?.get(jog);
    const minha = () => { for (const [oid, ms] of this.membros_de) if (ms.has(j)) return oid; return undefined; };
    for (const op of ops) {
      switch (op["op"]) {
        case "ordem_criar":
          if ([...this.ordens.values()].some((o) => o.nome.toLowerCase() === String(op["nome"]).toLowerCase()) || minha()) conflito();
          this.ordens.set(op["ordem_id"], { id: op["ordem_id"], nome: op["nome"], brasao: op["brasao"], idioma: op["idioma"] });
          this.membros_de.set(op["ordem_id"], new Map([[j, "lider"]]));
          break;
        case "ordem_entrar":
          if (!this.ordens.has(op["ordem_id"]) || minha() || (this.membros_de.get(op["ordem_id"])?.size ?? 0) >= 30) conflito();
          this.membros_de.get(op["ordem_id"])!.set(j, "membro");
          break;
        case "ordem_sair":
          this.membros_de.get(op["ordem_id"])?.delete(j);
          if ((this.membros_de.get(op["ordem_id"])?.size ?? 0) === 0) {
            this.membros_de.delete(op["ordem_id"]);
            this.ordens.delete(op["ordem_id"]);
          }
          break;
        case "ordem_dissolver":
          if (cargo_de(op["ordem_id"], j) !== "lider") conflito();
          this.membros_de.delete(op["ordem_id"]);
          this.ordens.delete(op["ordem_id"]);
          break;
        case "ordem_cargo":
          if (cargo_de(op["ordem_id"], j) !== "lider" || !cargo_de(op["ordem_id"], op["alvo"]) || cargo_de(op["ordem_id"], op["alvo"]) === "lider") conflito();
          this.membros_de.get(op["ordem_id"])!.set(op["alvo"], op["cargo"]);
          break;
        case "ordem_expulsar": {
          const meu = cargo_de(op["ordem_id"], j);
          const alvo = cargo_de(op["ordem_id"], op["alvo"]);
          if (!alvo || alvo === "lider" || !(meu === "lider" || (meu === "oficial" && alvo === "membro"))) conflito();
          this.membros_de.get(op["ordem_id"])!.delete(op["alvo"]);
          break;
        }
        case "ordem_lideranca":
          if (cargo_de(op["ordem_id"], j) !== "lider" || !cargo_de(op["ordem_id"], op["alvo"])) conflito();
          this.membros_de.get(op["ordem_id"])!.set(j, "oficial");
          this.membros_de.get(op["ordem_id"])!.set(op["alvo"], "lider");
          break;
        case "ordem_editar": {
          const meu = cargo_de(op["ordem_id"], j);
          if (!meu || meu === "membro" || (op["nome"] != null && meu !== "lider")) conflito();
          const o = this.ordens.get(op["ordem_id"])!;
          if (op["nome"] != null) o.nome = op["nome"];
          if (op["brasao"] != null) o.brasao = op["brasao"];
          break;
        }
        case "ajuda_pedir":
          this.pedidos.set(op["pedido_id"], { id: op["pedido_id"], ordem_id: op["ordem_id"], jogador_id: j, timer_id: op["timer_id"], tipo: op["tipo"],
            ajudas: 0, ajudas_max: op["ajudas_max"], expira_em: op["expira_em"] });
          break;
        case "ajuda_dar": {
          const p = this.pedidos.get(op["pedido_id"]);
          if (!p || p.ajudas >= p.ajudas_max || p.expira_em <= this.agora_banco() || p.jogador_id === j || minha() !== p.ordem_id) conflito();
          if (this.ajudas.some((a) => a.pedido_id === p!.id && a.ajudante_id === j)) conflito();
          p!.ajudas += 1;
          this.ajudas.push({ pedido_id: p!.id, ajudante_id: j, aplicada: false });
          break;
        }
        case "ajuda_aplicada": {
          const a = this.ajudas.find((x) => x.pedido_id === op["pedido_id"] && x.ajudante_id === op["ajudante_id"]);
          if (a && this.pedidos.get(a.pedido_id)?.jogador_id === j) a.aplicada = true;
          break;
        }
        case "doacao_registrar":
          if (minha() !== op["ordem_id"] || !cargo_de(op["ordem_id"], op["para_id"])) conflito();
          this.doacoes.push({ id: this.doacoes.length + 1, ordem_id: op["ordem_id"], de_id: j, para_id: op["para_id"], material: op["material"],
            quantidade: op["quantidade"], dia: op["dia"], aplicada: false });
          break;
        case "doacao_aplicada": {
          const d = this.doacoes.find((x) => x.id === op["id"]);
          if (d && d.para_id === j) d.aplicada = true;
          break;
        }
        case "chat_inserir":
          if ((this.silenciados.get(j) ?? 0) > this.agora_banco()) conflito();
          if (String(op["canal"]).startsWith("ordem:") && minha() !== String(op["canal"]).slice(6)) conflito();
          this.chat.push({ canal: op["canal"], de_id: j, de_nome: op["de_nome"], texto: op["texto"], chave: op["chave"] });
          break;
        case "amigo_adicionar":
          this.amizades.add(`${j}|${op["amigo_id"]}`);
          this.amizades.add(`${op["amigo_id"]}|${j}`);
          break;
        case "amigo_remover":
          this.amizades.delete(`${j}|${op["amigo_id"]}`);
          this.amizades.delete(`${op["amigo_id"]}|${j}`);
          break;
        case "torneio_vitoria": {
          if (minha() !== op["ordem_id"]) conflito();
          const k = `${op["semana"]}|${op["ordem_id"]}|${j}`;
          this.torneio_tabela.set(k, (this.torneio_tabela.get(k) ?? 0) + 1);
          break;
        }
        default:
          conflito();
      }
    }
  }

  async compra_existente(loja: string, hash: string) {
    return this.compras.get(`${loja}/${hash}`) ?? null;
  }
  async compra_por_hash(loja: string, hash: string) {
    return this.compras.get(`${loja}/${hash}`) ?? null;
  }
  async candidatos_pvp(_j: string, _pontos: number, _poder: number, _faixa: number, _limite: number) {
    return this.candidatos;
  }
}

/** Loja que recusa tudo (os testes de compra trocam por uma que conhece recibos). */
const LOJA_QUE_RECUSA: VerificadorLoja = {
  verificar: async () => ({ valido: false, produto: "", transacao: "", erro: "recibo_recusado" }),
  confirmar: async () => {},
};

export function montar(inicio = 1790000000) {
  const banco = new BancoFalso();
  let agora = inicio;
  const anuncios: string[] = [];
  const dep: Dependencias = {
    banco, bal, agora: () => agora, sorteio: () => 123456789, verificador: LOJA_QUE_RECUSA,
    verificar_anuncio: async (_j, token) => { anuncios.push(token); return token === "bom"; },
  };
  banco.agora_banco = () => agora;
  return { banco, dep, anuncios, relogio: { avancar: (s: number) => { agora += s; }, ir_para: (t: number) => { agora = t; }, agora: () => agora } };
}

export const PERS = {
  nome: "Isolda", nome_casa: "Casa Pardal", corpo: "feminino", rosto: "1", cabelo: "1", pele: "clara",
  cor_principal: "azul_real", cor_secundaria: "ouro_velho", pelagem: "preto",
};

export async function agir(dep: Dependencias, tipo: string, args: unknown[], id = uuid(), jogador = JOGADOR) {
  return await tratar_acao({ jogador_id: jogador, id, tipo, args }, dep);
}
