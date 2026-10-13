// Exclusão de conta dentro do app (3.9; LGPD/GDPR e regras das lojas): o
// jogador pede, confirma, e o servidor apaga tudo dele.
//
// Ordem (importa): 1) preparar_exclusao_conta passa a liderança da ordem a
// outro membro (ou apaga a ordem vazia) e anonimiza o que precisa ser mantido
// (compras ficam sem dono, para a contabilidade); 2) apaga o usuário do Auth,
// e o `on delete cascade` leva estado, métricas, defesa, partidas como
// atacante, mensagens, amizades e o resto.

export interface ClienteExclusao {
  // deno-lint-ignore no-explicit-any
  rpc(nome: string, args: Record<string, unknown>): Promise<{ data: any; error: { message: string } | null }>;
  auth: { admin: { deleteUser(id: string): Promise<{ error: { message: string } | null }> } };
}

export const FRASE_DE_CONFIRMACAO = "EXCLUIR";

export async function excluir_conta(
  cliente: ClienteExclusao, jogador_id: string, confirmacao: unknown,
): Promise<{ ok: boolean; erro: string }> {
  if (confirmacao !== FRASE_DE_CONFIRMACAO) return { ok: false, erro: "confirmacao_invalida" };
  const p = await cliente.rpc("preparar_exclusao_conta", { p_jogador: jogador_id });
  if (p.error) return { ok: false, erro: "falha_ao_preparar" };
  const r = await cliente.auth.admin.deleteUser(jogador_id);
  if (r.error) return { ok: false, erro: "falha_ao_excluir" };
  return { ok: true, erro: "" };
}
