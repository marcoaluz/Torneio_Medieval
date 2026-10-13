// Registro de erros das Edge Functions (3.10): os logs do Supabase duram pouco,
// então o erro também vai para a tabela `erro_servidor` (consultada no painel).
// Nunca devolve detalhe ao cliente e nunca falha por causa do registro.

export interface ClienteErros {
  // deno-lint-ignore no-explicit-any
  from(tabela: string): any;
}

export async function registrar_erro(cliente: ClienteErros, funcao: string, erro: unknown, jogador?: string): Promise<void> {
  const mensagem = (erro instanceof Error ? `${erro.name}: ${erro.message}` : String(erro)).slice(0, 600);
  console.error(`[${funcao}]`, mensagem);
  try {
    await cliente.from("erro_servidor").insert({ funcao, mensagem, jogador_id: jogador ?? null });
  } catch (_e) {
    // sem registro não há o que fazer; o console.error acima já saiu
  }
}
