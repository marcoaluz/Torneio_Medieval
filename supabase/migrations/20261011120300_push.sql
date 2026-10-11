-- Torneio Medieval · 3.23 · Push pelo servidor (RASCUNHO, aplicar junto com o resto)
-- O aparelho registra o token (FCM no Android, APNs no iOS) com as
-- preferências de notificação; uma Edge Function agendada (cron do banco)
-- manda os avisos que só o servidor sabe: pedido de ajuda da ordem e fim de
-- temporada. Os avisos de timer continuam locais (o celular agenda).

create table if not exists public.dispositivo_push (
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	token text not null check (char_length(token) between 10 and 4096),
	plataforma text not null check (plataforma in ('android', 'ios')),
	preferencias jsonb not null default '{}'::jsonb,
	atualizado_em timestamptz not null default now(),
	primary key (jogador_id, token)
);

alter table public.dispositivo_push enable row level security;

create policy "push le o proprio" on public.dispositivo_push
	for select to authenticated using ((select auth.uid()) = jogador_id);
create policy "push cria o proprio" on public.dispositivo_push
	for insert to authenticated with check ((select auth.uid()) = jogador_id);
create policy "push atualiza o proprio" on public.dispositivo_push
	for update to authenticated using ((select auth.uid()) = jogador_id) with check ((select auth.uid()) = jogador_id);
create policy "push apaga o proprio" on public.dispositivo_push
	for delete to authenticated using ((select auth.uid()) = jogador_id);
