// Banco do Supabase para o tratamento de ações (Banco de handler.ts). Usa o
// cliente com a CHAVE DE SERVIÇO (só dentro da Edge Function; nunca no app).
// As gravações que importam passam por funções SQL transacionais
// (migração 20261013120000_servidor_completo.sql).

import type { Banco } from "./handler.ts";
import type { Dados } from "./base.ts";
import type { Candidato } from "./liga.ts";

// O cliente do supabase-js, tipado de forma mínima (o servidor injeta o real).
export interface ClienteSupabase {
  // deno-lint-ignore no-explicit-any
  rpc(nome: string, args: Dados): Promise<{ data: any; error: { message: string } | null }>;
  // deno-lint-ignore no-explicit-any
  from(tabela: string): any;
}

export class BancoSupabase implements Banco {
  private cliente: ClienteSupabase;

  constructor(cliente: ClienteSupabase) {
    this.cliente = cliente;
  }

  async carregar(jogador: string) {
    const { data, error } = await this.cliente.from("save_jogador").select("dados, revisao").eq("jogador_id", jogador).maybeSingle();
    if (error) throw new Error("carregar: " + error.message);
    return data ? { estado: data.dados as Dados, revisao: Number(data.revisao) } : null;
  }

  async gravar(jogador: string, estado: Dados, revisao_esperada: number | null, log: { id: string; tipo: string; resposta: Dados }, efeitos: Dados) {
    const { data, error } = await this.cliente.rpc("aplicar_acao", {
      p_jogador: jogador, p_estado: estado, p_revisao_esperada: revisao_esperada,
      p_id: log.id, p_tipo: log.tipo, p_resposta: log.resposta, p_efeitos: efeitos,
    });
    if (error) throw new Error("gravar: " + error.message);
    if (data === null) return null;
    if (Number(data) === -1) return "repetida" as const;
    return Number(data);
  }

  async candidatos_pvp(jogador: string, pontos: number, poder: number, faixa: number, limite: number): Promise<Candidato[]> {
    const { data, error } = await this.cliente.rpc("candidatos_pvp", {
      p_jogador: jogador, p_pontos: pontos, p_poder: poder, p_faixa: faixa, p_limite: limite,
    });
    if (error) throw new Error("candidatos: " + error.message);
    return (data ?? []) as Candidato[];
  }

  async compra_existente(loja: string, recibo_hash: string) {
    const { data, error } = await this.cliente.from("compra").select("jogador_id, estado").eq("loja", loja).eq("recibo_hash", recibo_hash).maybeSingle();
    if (error) throw new Error("compra: " + error.message);
    return data ? { jogador_id: String(data.jogador_id), estado: String(data.estado) } : null;
  }

  async compra_por_hash(loja: string, recibo_hash: string) {
    const { data, error } = await this.cliente.from("compra").select("jogador_id, produto").eq("loja", loja).eq("recibo_hash", recibo_hash).maybeSingle();
    if (error) throw new Error("compra: " + error.message);
    return data ? { jogador_id: String(data.jogador_id), produto: String(data.produto) } : null;
  }

  async resposta_guardada(jogador: string, id: string) {
    const { data, error } = await this.cliente.from("acao_log").select("resposta").eq("jogador_id", jogador).eq("id", id).maybeSingle();
    if (error) throw new Error("resposta: " + error.message);
    return data ? (data.resposta as Dados) : null;
  }

  async guardar_resposta(jogador: string, id: string, tipo: string, resposta: Dados) {
    const { data, error } = await this.cliente.rpc("guardar_resposta_acao", { p_jogador: jogador, p_id: id, p_tipo: tipo, p_resposta: resposta });
    if (error) throw new Error("guardar: " + error.message);
    return Boolean(data);
  }

  async contar_chamada(jogador: string, janela: number) {
    const { data, error } = await this.cliente.rpc("contar_chamada", { p_jogador: jogador, p_janela: janela });
    if (error) throw new Error("contar: " + error.message);
    return Number(data);
  }
}

/** Lê o balanceamento ativo da tabela `balanceamento` ({nome: dados}). */
export async function carregar_balanceamento(cliente: ClienteSupabase): Promise<Record<string, Dados>> {
  const { data, error } = await cliente.from("balanceamento").select("nome, dados").eq("ativa", true);
  if (error) throw new Error("balanceamento: " + error.message);
  const r: Record<string, Dados> = {};
  for (const linha of data ?? []) r[linha.nome] = linha.dados;
  return r;
}
