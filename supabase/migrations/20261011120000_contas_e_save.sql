-- Torneio Medieval · 2.12 · Contas e save na nuvem
-- Login anônimo no primeiro acesso (Supabase Auth); o jogador anônimo usa o
-- papel "authenticated", então o RLS vale igual para anônimo e permanente.
-- Nesta etapa a nuvem guarda o ESTADO DO JOGADOR inteiro (o mesmo JSON do
-- save local, com versão). Economia no servidor é a Parte 3 (3.1/3.2): lá
-- este save deixa de ser escrito pelo cliente e as tabelas de economia
-- (migração 20261011120100_economia_rascunho.sql) viram a fonte da verdade.

create table if not exists public.jogador (
	id uuid primary key references auth.users (id) on delete cascade,
	criado_em timestamptz not null default now(),
	atualizado_em timestamptz not null default now(),
	nome text not null default '' check (char_length(nome) <= 20),
	casa text not null default '' check (char_length(casa) <= 20)
);

comment on table public.jogador is 'Um registro por conta (anônima ou vinculada). Nome e casa repetidos aqui para ranking e social; a validação de nome ofensivo é refeita na Edge Function da Parte 3.';

create table if not exists public.save_jogador (
	jogador_id uuid primary key references public.jogador (id) on delete cascade,
	versao integer not null check (versao >= 1),
	revisao bigint not null default 0 check (revisao >= 0),
	dados jsonb not null,
	atualizado_em timestamptz not null default now(),
	constraint save_tamanho check (pg_column_size(dados) < 512 * 1024)
);

comment on table public.save_jogador is 'Estado do jogador (JSON versionado do ServicoJogador). revisao cresce a cada envio; o cliente usa para escolher entre o save local e o da nuvem.';

alter table public.jogador enable row level security;
alter table public.save_jogador enable row level security;

-- jogador: cada um lê e cria/atualiza só o próprio registro.
create policy "jogador le o proprio registro" on public.jogador
	for select to authenticated using ((select auth.uid()) = id);
create policy "jogador cria o proprio registro" on public.jogador
	for insert to authenticated with check ((select auth.uid()) = id);
create policy "jogador atualiza o proprio registro" on public.jogador
	for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- save: cada um lê e grava só o próprio save (até a Parte 3).
create policy "save le o proprio" on public.save_jogador
	for select to authenticated using ((select auth.uid()) = jogador_id);
create policy "save cria o proprio" on public.save_jogador
	for insert to authenticated with check ((select auth.uid()) = jogador_id);
create policy "save atualiza o proprio" on public.save_jogador
	for update to authenticated using ((select auth.uid()) = jogador_id) with check ((select auth.uid()) = jogador_id);

-- Sem delete pelo cliente: excluir a conta (3.9) apaga o usuário do Auth e
-- o cascade leva jogador e save.

-- atualizado_em e revisao controlados pelo banco, não pelo cliente.
create or replace function public.tocar_save()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
	new.atualizado_em := now();
	if tg_op = 'UPDATE' then
		new.revisao := old.revisao + 1;
	else
		new.revisao := 1;
	end if;
	return new;
end;
$$;

create trigger save_jogador_tocar
	before insert or update on public.save_jogador
	for each row execute function public.tocar_save();

create or replace function public.tocar_jogador()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
	new.atualizado_em := now();
	return new;
end;
$$;

create trigger jogador_tocar
	before update on public.jogador
	for each row execute function public.tocar_jogador();
