-- Torneio Medieval · 2.13 · Métricas de jogo
-- Eventos para ver onde os jogadores param (tutorial, justas, prédios,
-- desistências). O cliente só INSERE os próprios eventos; ninguém lê pelo
-- app (análise pelo painel/SQL com a chave de serviço).

create table if not exists public.evento_metrica (
	id bigint generated always as identity primary key,
	jogador_id uuid not null default auth.uid() references public.jogador (id) on delete cascade,
	evento text not null check (char_length(evento) between 1 and 40),
	dados jsonb not null default '{}'::jsonb,
	sessao text not null default '' check (char_length(sessao) <= 40),
	criado_em_cliente timestamptz,
	recebido_em timestamptz not null default now(),
	constraint evento_dados_tamanho check (pg_column_size(dados) < 4096)
);

create index if not exists evento_metrica_evento_recebido on public.evento_metrica (evento, recebido_em);
create index if not exists evento_metrica_jogador on public.evento_metrica (jogador_id);

alter table public.evento_metrica enable row level security;

create policy "jogador registra os proprios eventos" on public.evento_metrica
	for insert to authenticated with check ((select auth.uid()) = jogador_id);

-- Sem política de select/update/delete para authenticated: o app não lê nem muda.

-- Consultas úteis (rodar no painel):
-- Onde param no tutorial:
--   select dados->>'passo' as passo, count(distinct jogador_id)
--   from public.evento_metrica where evento = 'tutorial_passo' group by 1 order by 1;
-- Desistência por fase da justa:
--   select dados->>'fase' as fase, count(*) from public.evento_metrica
--   where evento = 'desistencia' group by 1 order by 2 desc;
