-- Torneio Medieval · 3.2 · O servidor passa a ser o dono do estado (RASCUNHO: NÃO APLICADO)
--
-- Aplicar JUNTO com o lançamento do aplicativo que chama as Edge Functions de
-- ação (supabase/functions/acao) em vez de gravar o save direto. Antes disso o
-- cliente ainda escreve em save_jogador (2.12) e esta migração o quebraria.
--
-- Depois dela, o papel authenticated só LÊ o próprio save; quem grava é a
-- chave de serviço das Edge Functions, que aplica o comando em TypeScript,
-- confere e grava com a revisão certa (o gatilho tocar_save continua
-- controlando atualizado_em e revisao).

drop policy if exists "save cria o proprio" on public.save_jogador;
drop policy if exists "save atualiza o proprio" on public.save_jogador;
drop policy if exists "jogador cria o proprio registro" on public.jogador;
drop policy if exists "jogador atualiza o proprio registro" on public.jogador;

-- Tira também o privilégio de tabela (defesa em profundidade: sem política
-- e sem privilégio, uma política criada por engano não reabre a escrita).
revoke insert, update, delete on public.save_jogador from authenticated, anon;
revoke insert, update, delete on public.jogador from authenticated, anon;
