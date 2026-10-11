-- Torneio Medieval · RASCUNHO da economia no servidor (Parte 3, prompt 3.1)
-- NÃO APLICAR antes da 3.1. Mostra como o modelo do ServicoJogador
-- (docs/DADOS_JOGADOR.md) vira tabelas quando o servidor for o dono do
-- estado: o cliente só LÊ estas tabelas; toda escrita é por Edge Function
-- (chave de serviço), que valida, cobra e grava. Timers pelo relógio do banco.

create table if not exists public.cavaleiro (
	jogador_id uuid primary key references public.jogador (id) on delete cascade,
	nivel integer not null default 1 check (nivel between 1 and 100),
	xp bigint not null default 0 check (xp >= 0),
	forca smallint not null default 30 check (forca between 0 and 100),
	precisao smallint not null default 30 check (precisao between 0 and 100),
	equilibrio smallint not null default 30 check (equilibrio between 0 and 100),
	habilidade text not null default '',
	aparencia jsonb not null default '{}'::jsonb
);

create table if not exists public.carteira (
	jogador_id uuid primary key references public.jogador (id) on delete cascade,
	ouro bigint not null default 0 check (ouro >= 0),
	gemas bigint not null default 0 check (gemas >= 0),
	materiais jsonb not null default '{}'::jsonb
);

create table if not exists public.cavalo (
	id uuid primary key default gen_random_uuid(),
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	pelagem text not null,
	velocidade smallint not null check (velocidade between 0 and 100),
	folego smallint not null check (folego between 0 and 100),
	temperamento smallint not null check (temperamento between 0 and 100),
	vinculo smallint not null default 0 check (vinculo between 0 and 100),
	folego_valor smallint not null default 100,
	folego_em timestamptz not null default now(),
	ativo boolean not null default false
);
create index if not exists cavalo_jogador on public.cavalo (jogador_id);

create table if not exists public.item (
	id uuid primary key default gen_random_uuid(),
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	modelo text not null,
	nivel smallint not null default 0 check (nivel between 0 and 10),
	durabilidade integer not null check (durabilidade >= 0),
	criado_em timestamptz not null default now()
);
create index if not exists item_jogador on public.item (jogador_id);

create table if not exists public.equipamento (
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	espaco text not null,
	item_id uuid references public.item (id) on delete set null,
	item_visual_id uuid references public.item (id) on delete set null,
	primary key (jogador_id, espaco)
);

create table if not exists public.predio (
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	nome text not null,
	nivel smallint not null default 1 check (nivel between 1 and 20),
	primary key (jogador_id, nome)
);

create table if not exists public.timer (
	id uuid primary key default gen_random_uuid(),
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	tipo text not null,
	alvo text not null,
	dados jsonb not null default '{}'::jsonb,
	inicio_em timestamptz not null default now(),
	termina_em timestamptz not null
);
create index if not exists timer_jogador on public.timer (jogador_id);

create table if not exists public.pve_progresso (
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	torneio text not null,
	proxima smallint not null default 0,
	concluido boolean not null default false,
	estrelas jsonb not null default '{}'::jsonb,
	primary key (jogador_id, torneio)
);

-- RLS: o jogador lê só o que é dele; não há política de escrita para o
-- papel authenticated (só a chave de serviço das Edge Functions escreve).
do $$
declare t text;
begin
	foreach t in array array['cavaleiro', 'carteira', 'cavalo', 'item', 'equipamento', 'predio', 'timer', 'pve_progresso'] loop
		execute format('alter table public.%I enable row level security', t);
		execute format('create policy "le o proprio" on public.%I for select to authenticated using ((select auth.uid()) = jogador_id)', t);
	end loop;
end $$;
