// Banco do Supabase para o tratamento de ações (Banco de handler.ts). Usa o
// cliente com a CHAVE DE SERVIÇO (só dentro da Edge Function; nunca no app).
// As gravações que importam passam por funções SQL transacionais
// (migração 20261013120000_servidor_completo.sql).

import type { Banco } from "./handler.ts";
import type { Dados } from "./base.ts";
import type { Candidato } from "./liga.ts";
import type { Membro, PedidoAjuda } from "./social.ts";

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

  // ---- leituras sociais (as escritas saem em efeitos.social, na transação da ação)

  private async linhas(consulta: PromiseLike<{ data: Dados[] | null; error: { message: string } | null }>, rotulo: string): Promise<Dados[]> {
    const { data, error } = await consulta;
    if (error) throw new Error(`${rotulo}: ${error.message}`);
    return data ?? [];
  }

  async ordem_do_jogador(jogador: string) {
    const { data, error } = await this.cliente.from("ordem_membro").select("ordem_id, cargo").eq("jogador_id", jogador).maybeSingle();
    if (error) throw new Error("ordem_do_jogador: " + error.message);
    return data ? { ordem_id: String(data.ordem_id), cargo: String(data.cargo) } : null;
  }

  async ordem(ordem_id: string) {
    const { data, error } = await this.cliente.from("ordem").select("id, nome, brasao, idioma").eq("id", ordem_id).maybeSingle();
    if (error) throw new Error("ordem: " + error.message);
    return data ? { id: String(data.id), nome: String(data.nome), brasao: data.brasao as Dados, idioma: String(data.idioma) } : null;
  }

  async membros(ordem_id: string): Promise<Membro[]> {
    const ms = await this.linhas(this.cliente.from("ordem_membro").select("jogador_id, cargo").eq("ordem_id", ordem_id), "membros");
    if (ms.length === 0) return [];
    const pub = await this.linhas(
      this.cliente.from("jogador_publico").select("jogador_id, nome, poder").in("jogador_id", ms.map((m) => m.jogador_id)), "membros_publico");
    const por_id = new Map(pub.map((p) => [String(p.jogador_id), p]));
    return ms.map((m) => ({
      jogador_id: String(m.jogador_id), cargo: String(m.cargo),
      nome: String(por_id.get(String(m.jogador_id))?.nome ?? ""), poder: Number(por_id.get(String(m.jogador_id))?.poder ?? 0),
    }));
  }

  async nome_de_ordem_livre(nome: string) {
    const r = await this.linhas(this.cliente.from("ordem").select("id").ilike("nome", nome.replace(/[%_]/g, "\\$&")).limit(1), "nome_livre");
    return r.length === 0;
  }

  async pedidos_abertos(ordem_id: string, agora: number, jogador: string): Promise<PedidoAjuda[]> {
    const ps = await this.linhas(
      this.cliente.from("ordem_pedido_ajuda").select("id, jogador_id, timer_id, tipo, ajudas, ajudas_max")
        .eq("ordem_id", ordem_id).gt("expira_em", new Date(agora * 1000).toISOString()), "pedidos");
    if (ps.length === 0) return [];
    const minhas = await this.linhas(
      this.cliente.from("ordem_ajuda").select("pedido_id").eq("ajudante_id", jogador).in("pedido_id", ps.map((p) => p.id)), "minhas_ajudas");
    const ajudei = new Set(minhas.map((m) => String(m.pedido_id)));
    return ps.map((p) => ({
      id: String(p.id), jogador_id: String(p.jogador_id), timer_id: String(p.timer_id), tipo: String(p.tipo),
      ajudas: Number(p.ajudas), ajudas_max: Number(p.ajudas_max), ajudado_por_mim: ajudei.has(String(p.id)),
    }));
  }

  async ajudas_pendentes(jogador: string) {
    const meus = await this.linhas(this.cliente.from("ordem_pedido_ajuda").select("id, timer_id").eq("jogador_id", jogador), "meus_pedidos");
    if (meus.length === 0) return [];
    const a = await this.linhas(
      this.cliente.from("ordem_ajuda").select("pedido_id, ajudante_id").eq("aplicada", false).in("pedido_id", meus.map((p) => p.id)), "ajudas");
    const timer = new Map(meus.map((p) => [String(p.id), String(p.timer_id)]));
    return a.map((x) => ({ pedido_id: String(x.pedido_id), ajudante_id: String(x.ajudante_id), timer_id: timer.get(String(x.pedido_id)) ?? "" }));
  }

  async doacoes_pendentes(jogador: string) {
    const r = await this.linhas(
      this.cliente.from("ordem_doacao").select("id, material, quantidade").eq("para_id", jogador).eq("aplicada", false), "doacoes");
    return r.map((d) => ({ id: Number(d.id), material: String(d.material), quantidade: Number(d.quantidade) }));
  }

  async doado_no_dia(jogador: string, dia: number) {
    const r = await this.linhas(this.cliente.from("ordem_doacao").select("quantidade").eq("de_id", jogador).eq("dia", dia), "doado");
    return r.reduce((t, d) => t + Number(d.quantidade), 0);
  }

  async jogador_por_codigo(codigo: string) {
    const { data, error } = await this.cliente.from("jogador_publico").select("jogador_id, nome").eq("codigo", codigo).maybeSingle();
    if (error) throw new Error("codigo: " + error.message);
    return data ? { jogador_id: String(data.jogador_id), nome: String(data.nome) } : null;
  }

  async silenciado_ate(jogador: string) {
    const { data, error } = await this.cliente.from("silenciamento").select("ate").eq("jogador_id", jogador).maybeSingle();
    if (error) throw new Error("silenciamento: " + error.message);
    return data ? Math.floor(Date.parse(String(data.ate)) / 1000) : null;
  }

  async torneio(semana: number, limite: number) {
    const { data, error } = await this.cliente.rpc("torneio_da_semana", { p_semana: semana, p_limite: limite });
    if (error) throw new Error("torneio: " + error.message);
    return ((data ?? []) as Dados[]).map((x) => ({ ordem_id: String(x.ordem_id), nome: String(x.nome), vitorias: Number(x.vitorias) }));
  }

  async amigos(jogador: string) {
    const r = await this.linhas(this.cliente.from("amigo").select("amigo_id").eq("jogador_id", jogador), "amigos");
    return r.map((x) => String(x.amigo_id));
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
