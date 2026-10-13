// Fixtura dos testes do servidor: balanceamento dos arquivos do jogo, banco
// falso em memória (com os efeitos relacionais e os candidatos de PvP) e
// atalhos para agir como um jogador.

import { readFileSync } from "node:fs";
import { tratar_acao } from "../../functions/_shared/servidor/handler.ts";
import type { Banco, Dependencias } from "../../functions/_shared/servidor/handler.ts";
import type { VerificadorLoja } from "../../functions/_shared/servidor/compras.ts";
import type { Candidato } from "../../functions/_shared/servidor/liga.ts";
import type { Dados } from "./comum.ts";

const RAIZ = new URL("../../../", import.meta.url);
const ARQUIVOS: Record<string, string> = {
  historia: "game/data/historia/historia.json",
  nomes_proibidos: "game/data/texto/nomes_proibidos.json",
  nomes_sorteio: "game/data/texto/nomes_sorteio.json",
  acessibilidade: "game/data/ui/acessibilidade.json",
  paletas: "game/data/personagem/paletas.json",
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
  return { banco, dep, anuncios, relogio: { avancar: (s: number) => { agora += s; }, ir_para: (t: number) => { agora = t; }, agora: () => agora } };
}

export const PERS = {
  nome: "Isolda", nome_casa: "Casa Pardal", corpo: "feminino", rosto: "1", cabelo: "1", pele: "clara",
  cor_principal: "azul_real", cor_secundaria: "ouro_velho", pelagem: "preto",
};

export async function agir(dep: Dependencias, tipo: string, args: unknown[], id = uuid(), jogador = JOGADOR) {
  return await tratar_acao({ jogador_id: jogador, id, tipo, args }, dep);
}
