-- Torneio Medieval · 3.1 · Banco completo e regras de acesso (RASCUNHO: NÃO APLICADO)
--
-- Modelo (decisão em docs/DECISOES.md, 2026-10-13): o ESTADO DO JOGADOR é um
-- documento versionado (save_jogador.dados, o mesmo JSON do ServicoJogador),
-- e o servidor é o dono dele: o cliente só lê; toda mudança entra por Edge
-- Function (chave de serviço), que aplica o mesmo comando em TypeScript
-- (supabase/functions/_shared/), confere e grava com a revisão certa.
-- Dados compartilhados entre jogadores (ranking, PvP, ordens, chat, amigos,
-- denúncias, compras) são tabelas relacionais, para consulta e índice.
--
-- Regras para todas as tabelas daqui (skill supabase-jogo):
--  * RLS ligada na criação; o jogador lê só o que é dele (auth.uid()) e NUNCA
--    escreve em economia, ranking, compras nem partidas;
--  * escrita só pela chave de serviço (Edge Function) ou por função
--    security definer com search_path vazio;
--  * tempo pelo relógio do banco (now()), nunca pelo do celular.
--
-- Pré-requisitos já aplicados: 20261011120000_contas_e_save (jogador,
-- save_jogador) e 20261011120200_metricas (evento_metrica).

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

-- ------------------------------------------------------------------ geral

-- Balanceamento remoto (3.3): uma linha por arquivo de dados e versão.
-- O jogo baixa a versão ativa ao abrir e guarda em cache. `publico = false`
-- (parâmetros do servidor, como os limites do anticheat) só a Edge Function lê.
create table if not exists public.balanceamento (
	nome text not null check (char_length(nome) between 1 and 40),
	versao integer not null check (versao >= 1),
	dados jsonb not null,
	ativa boolean not null default false,
	publico boolean not null default true,
	criado_em timestamptz not null default now(),
	primary key (nome, versao)
);
create unique index if not exists balanceamento_uma_ativa on public.balanceamento (nome) where ativa;
alter table public.balanceamento enable row level security;
create policy "balanceamento ativo e publico" on public.balanceamento
	for select to authenticated using (ativa and publico);

-- Idempotência (3.2): cada ação do cliente leva um uuid; repetir devolve a
-- resposta guardada e nunca entrega duas vezes. Só a Edge Function acessa.
create table if not exists public.acao_log (
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	id uuid not null,
	tipo text not null check (char_length(tipo) <= 40),
	resposta jsonb not null,
	criado_em timestamptz not null default now(),
	primary key (jogador_id, id)
);
create index if not exists acao_log_criado on public.acao_log (criado_em);
alter table public.acao_log enable row level security;

-- Limite de chamadas por jogador (3.2): contador por minuto (janela = minutos
-- desde 1970). Sem chave estrangeira: conta antes de o jogador existir.
create table if not exists public.limite_chamada (
	jogador_id uuid not null,
	janela bigint not null,
	chamadas integer not null default 0,
	primary key (jogador_id, janela)
);
alter table public.limite_chamada enable row level security;

-- Silenciamento automático ou manual (3.8).
create table if not exists public.silenciamento (
	jogador_id uuid primary key references public.jogador (id) on delete cascade,
	ate timestamptz not null,
	motivo text not null default ''
);
alter table public.silenciamento enable row level security;
create policy "silenciamento le o proprio" on public.silenciamento
	for select to authenticated using ((select auth.uid()) = jogador_id);

-- -------------------------------------------------- perfil público e ranking

-- O que os outros jogadores podem ver (ranking, perfil público, pareamento).
-- Escrita só pela Edge Function, a partir do estado autoritativo.
create table if not exists public.jogador_publico (
	jogador_id uuid primary key references public.jogador (id) on delete cascade,
	codigo text not null unique check (codigo ~ '^TM-[A-Z2-9]{6}$'),
	nome text not null default '',
	casa text not null default '',
	nivel integer not null default 1,
	poder integer not null default 0,
	pontos integer not null default 0 check (pontos >= 0),
	liga text not null default 'bronze',
	melhor_liga text not null default 'bronze',
	aparencia jsonb not null default '{}'::jsonb,
	brasao jsonb not null default '{}'::jsonb,
	titulo text not null default '',
	ordem_id uuid,
	idioma text not null default 'pt',
	atualizado_em timestamptz not null default now()
);
create index if not exists jogador_publico_ranking on public.jogador_publico (pontos desc);
create index if not exists jogador_publico_pareamento on public.jogador_publico (poder, pontos);
alter table public.jogador_publico enable row level security;
create policy "perfil publico e legivel" on public.jogador_publico
	for select to authenticated using (true);

-- -------------------------------------------------------------- PvP (3.5)

-- Retrato da defesa (cavalo, equipamento, habilidades) salvo pelo jogador.
-- O atacante não lê isto: o pareamento (Edge Function) monta o fantasma.
create table if not exists public.defesa_pvp (
	jogador_id uuid primary key references public.jogador (id) on delete cascade,
	retrato jsonb not null,
	poder integer not null,
	salva_em timestamptz not null default now()
);
alter table public.defesa_pvp enable row level security;
create policy "defesa le a propria" on public.defesa_pvp
	for select to authenticated using ((select auth.uid()) = jogador_id);

-- Registro de cada partida (investigar denúncias): semente e entradas bastam
-- para refazer a justa com a mesma regra.
create table if not exists public.partida_pvp (
	id bigint generated always as identity primary key,
	atacante_id uuid not null references public.jogador (id) on delete cascade,
	defensor_id uuid references public.jogador (id) on delete set null,
	campeonato_id bigint,
	semente bigint not null,
	entradas jsonb not null,
	venceu boolean not null,
	pontos_atacante integer not null default 0,
	pontos_defensor integer not null default 0,
	criado_em timestamptz not null default now()
);
create index if not exists partida_pvp_atacante on public.partida_pvp (atacante_id, criado_em desc);
create index if not exists partida_pvp_defensor on public.partida_pvp (defensor_id, criado_em desc);
alter table public.partida_pvp enable row level security;
create policy "partida le as proprias" on public.partida_pvp
	for select to authenticated using ((select auth.uid()) in (atacante_id, defensor_id));

-- -------------------------------------------------- temporadas e campeonatos (3.6)

create table if not exists public.temporada (
	numero integer primary key,
	inicio timestamptz not null,
	fim timestamptz not null,
	fechada boolean not null default false,
	check (fim > inicio)
);
alter table public.temporada enable row level security;
create policy "temporada e publica" on public.temporada
	for select to authenticated using (true);

create table if not exists public.campeonato (
	id bigint generated always as identity primary key,
	semana integer not null unique,
	chave jsonb not null default '[]'::jsonb,
	aberto_em timestamptz not null,
	fecha_em timestamptz not null,
	fechado boolean not null default false
);
alter table public.campeonato enable row level security;
create policy "campeonato e publico" on public.campeonato
	for select to authenticated using (true);

create table if not exists public.campeonato_participante (
	campeonato_id bigint not null references public.campeonato (id) on delete cascade,
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	rodada smallint not null default 0,
	eliminado boolean not null default false,
	primary key (campeonato_id, jogador_id)
);
alter table public.campeonato_participante enable row level security;
create policy "campeonato le o proprio" on public.campeonato_participante
	for select to authenticated using ((select auth.uid()) = jogador_id);

-- ---------------------------------------------------------------- ordens (3.8)

create table if not exists public.ordem (
	id uuid primary key default gen_random_uuid(),
	nome text not null unique check (char_length(nome) between 3 and 20),
	brasao jsonb not null default '{}'::jsonb,
	idioma text not null default 'pt',
	criada_em timestamptz not null default now()
);
alter table public.ordem enable row level security;
create policy "ordem e publica" on public.ordem
	for select to authenticated using (true);

create table if not exists public.ordem_membro (
	ordem_id uuid not null references public.ordem (id) on delete cascade,
	jogador_id uuid not null unique references public.jogador (id) on delete cascade,
	cargo text not null default 'membro' check (cargo in ('lider', 'oficial', 'membro')),
	entrou_em timestamptz not null default now(),
	primary key (ordem_id, jogador_id)
);
create index if not exists ordem_membro_ordem on public.ordem_membro (ordem_id);
-- Um líder por ordem.
create unique index if not exists ordem_um_lider on public.ordem_membro (ordem_id) where cargo = 'lider';
alter table public.ordem_membro enable row level security;

-- Pertence à ordem? (security definer evita recursão de RLS)
create or replace function public.sou_da_ordem(p_ordem uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
	select exists (
		select 1 from public.ordem_membro m
		where m.ordem_id = p_ordem and m.jogador_id = (select auth.uid())
	);
$$;
revoke all on function public.sou_da_ordem(uuid) from public;
grant execute on function public.sou_da_ordem(uuid) to authenticated;

create policy "membros da minha ordem" on public.ordem_membro
	for select to authenticated using (public.sou_da_ordem(ordem_id));

create table if not exists public.ordem_pedido_ajuda (
	id uuid primary key default gen_random_uuid(),
	ordem_id uuid not null references public.ordem (id) on delete cascade,
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	timer_id text not null,
	tipo text not null,
	ajudas smallint not null default 0,
	ajudas_max smallint not null default 4,
	criado_em timestamptz not null default now(),
	expira_em timestamptz not null
);
create index if not exists ordem_pedido_ajuda_ordem on public.ordem_pedido_ajuda (ordem_id, expira_em);
alter table public.ordem_pedido_ajuda enable row level security;
create policy "pedidos da minha ordem" on public.ordem_pedido_ajuda
	for select to authenticated using (public.sou_da_ordem(ordem_id));

create table if not exists public.ordem_ajuda (
	pedido_id uuid not null references public.ordem_pedido_ajuda (id) on delete cascade,
	ajudante_id uuid not null references public.jogador (id) on delete cascade,
	em timestamptz not null default now(),
	primary key (pedido_id, ajudante_id)
);
alter table public.ordem_ajuda enable row level security;
create policy "ajudas le as proprias" on public.ordem_ajuda
	for select to authenticated using ((select auth.uid()) = ajudante_id);

create table if not exists public.ordem_doacao (
	id bigint generated always as identity primary key,
	ordem_id uuid not null references public.ordem (id) on delete cascade,
	de_id uuid not null references public.jogador (id) on delete cascade,
	para_id uuid not null references public.jogador (id) on delete cascade,
	material text not null,
	quantidade integer not null check (quantidade > 0),
	dia integer not null,
	criado_em timestamptz not null default now()
);
create index if not exists ordem_doacao_de_dia on public.ordem_doacao (de_id, dia);
alter table public.ordem_doacao enable row level security;
create policy "doacoes le as proprias" on public.ordem_doacao
	for select to authenticated using ((select auth.uid()) in (de_id, para_id));

-- Torneio de Ordens: vitórias de PvP por jogador na semana (a soma é da ordem).
create table if not exists public.ordem_torneio (
	semana integer not null,
	ordem_id uuid not null references public.ordem (id) on delete cascade,
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	vitorias integer not null default 0 check (vitorias >= 0),
	primary key (semana, ordem_id, jogador_id)
);
alter table public.ordem_torneio enable row level security;
create policy "torneio da minha ordem" on public.ordem_torneio
	for select to authenticated using (public.sou_da_ordem(ordem_id));

-- ----------------------------------------------------- chat, amigos, moderação

-- canal: 'ordem:<uuid>' ou 'global:<idioma>'. Realtime lê por RLS; a escrita
-- passa pela Edge Function (filtro de palavras, silenciamento, limite).
create table if not exists public.chat_mensagem (
	id bigint generated always as identity primary key,
	canal text not null check (char_length(canal) <= 60),
	de_id uuid not null references public.jogador (id) on delete cascade,
	de_nome text not null default '',
	texto text not null default '' check (char_length(texto) <= 200),
	chave text not null default '' check (char_length(chave) <= 40),
	criado_em timestamptz not null default now()
);
create index if not exists chat_mensagem_canal on public.chat_mensagem (canal, id desc);
alter table public.chat_mensagem enable row level security;
create policy "chat global por idioma" on public.chat_mensagem
	for select to authenticated using (canal like 'global:%');
create policy "chat da minha ordem" on public.chat_mensagem
	for select to authenticated using (
		canal like 'ordem:%' and public.sou_da_ordem(substr(canal, 7)::uuid)
	);

create table if not exists public.amigo (
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	amigo_id uuid not null references public.jogador (id) on delete cascade,
	desde timestamptz not null default now(),
	primary key (jogador_id, amigo_id),
	check (jogador_id <> amigo_id)
);
alter table public.amigo enable row level security;
create policy "amigos le os proprios" on public.amigo
	for select to authenticated using ((select auth.uid()) = jogador_id);
create policy "amigos remove o proprio vinculo" on public.amigo
	for delete to authenticated using ((select auth.uid()) = jogador_id);

-- Bloqueio é preferência do jogador (não é economia): ele mesmo insere e apaga.
create table if not exists public.bloqueio (
	jogador_id uuid not null default auth.uid() references public.jogador (id) on delete cascade,
	bloqueado_id uuid not null references public.jogador (id) on delete cascade,
	desde timestamptz not null default now(),
	primary key (jogador_id, bloqueado_id),
	check (jogador_id <> bloqueado_id)
);
alter table public.bloqueio enable row level security;
create policy "bloqueio le o proprio" on public.bloqueio
	for select to authenticated using ((select auth.uid()) = jogador_id);
create policy "bloqueio cria o proprio" on public.bloqueio
	for insert to authenticated with check ((select auth.uid()) = jogador_id);
create policy "bloqueio apaga o proprio" on public.bloqueio
	for delete to authenticated using ((select auth.uid()) = jogador_id);

-- Denúncias: o jogador só cria; a fila é revisada no painel do Supabase.
create table if not exists public.denuncia (
	id bigint generated always as identity primary key,
	denunciante_id uuid not null default auth.uid() references public.jogador (id) on delete cascade,
	alvo_id uuid not null references public.jogador (id) on delete cascade,
	motivo text not null check (motivo in ('ofensa', 'spam', 'outro')),
	canal text not null default '' check (char_length(canal) <= 60),
	trecho text not null default '' check (char_length(trecho) <= 200),
	status text not null default 'aberta' check (status in ('aberta', 'revisada', 'descartada')),
	criado_em timestamptz not null default now(),
	check (denunciante_id <> alvo_id)
);
create index if not exists denuncia_status on public.denuncia (status, criado_em);
create index if not exists denuncia_alvo on public.denuncia (alvo_id, criado_em);
alter table public.denuncia enable row level security;
create policy "denuncia cria a propria" on public.denuncia
	for insert to authenticated with check ((select auth.uid()) = denunciante_id);

-- ---------------------------------------------------------------- compras (3.7)

-- Só a Edge Function (depois de validar o recibo na loja) insere aqui.
create table if not exists public.compra (
	id bigint generated always as identity primary key,
	jogador_id uuid not null references public.jogador (id) on delete cascade,
	loja text not null check (loja in ('google', 'apple', 'teste')),
	produto text not null,
	recibo_hash text not null,
	estado text not null default 'validada' check (estado in ('validada', 'reembolsada', 'cancelada', 'expirada')),
	valido_ate timestamptz,
	criado_em timestamptz not null default now(),
	atualizado_em timestamptz not null default now(),
	unique (loja, recibo_hash)
);
create index if not exists compra_jogador on public.compra (jogador_id, criado_em desc);
alter table public.compra enable row level security;
create policy "compra le as proprias" on public.compra
	for select to authenticated using ((select auth.uid()) = jogador_id);

-- ------------------------------------------------------------ rotinas (3.6)

-- Tarefas agendadas chamam as Edge Functions (a regra fica em TypeScript, uma
-- só vez): temporada e campeonato. O segredo da chamada fica no Vault do
-- Supabase (nome 'cron_secret'), nunca no repositório.
-- Exemplo (aplicar na hora de publicar as funções, com a URL do projeto):
--   select cron.schedule('fechar-temporada', '5 3 * * *',
--     $$ select net.http_post(
--          url := 'https://<ref>.supabase.co/functions/v1/rotina',
--          headers := jsonb_build_object('Authorization', 'Bearer ' ||
--            (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')),
--          body := jsonb_build_object('tarefa', 'temporada')) $$);
--   select cron.schedule('campeonato-fim-de-semana', '0 3 * * 6,0', ... 'campeonato' ...);

-- Limpeza do que só serve para idempotência e limite (mantém 7 dias).
create or replace function public.limpar_logs_de_acao()
returns void
language sql
security definer
set search_path = ''
as $$
	delete from public.acao_log where criado_em < now() - interval '7 days';
	delete from public.limite_chamada
		where janela < (extract(epoch from now()) / 60)::bigint - 1440;
$$;
revoke all on function public.limpar_logs_de_acao() from public, anon, authenticated;

-- ---------------------------------------------------- funções da Edge Function de ação (3.2)
-- Só a chave de serviço chama estas funções (nada para anon/authenticated).

-- Conta uma chamada na janela (minuto) e devolve o total.
create or replace function public.contar_chamada(p_jogador uuid, p_janela bigint)
returns integer
language sql
security definer
set search_path = ''
as $$
	insert into public.limite_chamada (jogador_id, janela, chamadas)
	values (p_jogador, p_janela, 1)
	on conflict (jogador_id, janela)
	do update set chamadas = public.limite_chamada.chamadas + 1
	returning chamadas;
$$;
revoke all on function public.contar_chamada(uuid, bigint) from public, anon, authenticated;

-- Resposta sem mudança de estado (erro de regra): guarda para repetir igual.
-- Devolve false se o id já tinha resposta.
create or replace function public.guardar_resposta_acao(p_jogador uuid, p_id uuid, p_tipo text, p_resposta jsonb)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
	insert into public.jogador (id) values (p_jogador) on conflict (id) do nothing;
	insert into public.acao_log (jogador_id, id, tipo, resposta)
	values (p_jogador, p_id, p_tipo, p_resposta)
	on conflict (jogador_id, id) do nothing;
	return found;
end;
$$;
revoke all on function public.guardar_resposta_acao(uuid, uuid, text, jsonb) from public, anon, authenticated;

-- Efeitos relacionais de uma ação (decididos pela Edge Function, nunca pelo cliente):
--   publico  : upsert do resumo público do jogador (ranking, pareamento, perfil);
--   defesa   : retrato da defesa de PvP;
--   defensor : {id, delta} pontos para o defensor de uma partida;
--   partida  : registro da partida de PvP (investigação de denúncias);
--   compra   : registro da compra (recibo conferido); repetido desfaz a ação;
--   compra_estado : muda o estado de uma compra (reembolso, renovação...).
create or replace function public.aplicar_efeitos(p_jogador uuid, p_efeitos jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
	pub jsonb := p_efeitos -> 'publico';
	def jsonb := p_efeitos -> 'defesa';
	dfn jsonb := p_efeitos -> 'defensor';
	par jsonb := p_efeitos -> 'partida';
	cmp jsonb := p_efeitos -> 'compra';
	cmp_estado jsonb := p_efeitos -> 'compra_estado';
begin
	if pub is not null then
		insert into public.jogador_publico (jogador_id, codigo, nome, casa, nivel, poder, pontos, liga, melhor_liga,
			aparencia, brasao, titulo, atualizado_em)
		values (p_jogador, pub ->> 'codigo', pub ->> 'nome', pub ->> 'casa', (pub ->> 'nivel')::integer,
			(pub ->> 'poder')::integer, (pub ->> 'pontos')::integer, pub ->> 'liga', pub ->> 'melhor_liga',
			pub -> 'aparencia', pub -> 'brasao', coalesce(pub ->> 'titulo', ''), now())
		on conflict (jogador_id) do update set
			nome = excluded.nome, casa = excluded.casa, nivel = excluded.nivel, poder = excluded.poder,
			pontos = excluded.pontos, liga = excluded.liga, melhor_liga = excluded.melhor_liga,
			aparencia = excluded.aparencia, brasao = excluded.brasao, titulo = excluded.titulo,
			atualizado_em = now();
	end if;
	if def is not null then
		insert into public.defesa_pvp (jogador_id, retrato, poder, salva_em)
		values (p_jogador, def -> 'retrato', (def ->> 'poder')::integer, now())
		on conflict (jogador_id) do update set retrato = excluded.retrato, poder = excluded.poder, salva_em = now();
	end if;
	if dfn is not null then
		update public.jogador_publico
		set pontos = pontos + (dfn ->> 'delta')::integer
		where jogador_id = (dfn ->> 'id')::uuid;
	end if;
	if cmp is not null then
		-- recibo repetido (corrida): desfaz esta ação inteira; o chamador refaz e vê a compra já registrada
		insert into public.compra (jogador_id, loja, produto, recibo_hash, valido_ate)
		values (p_jogador, cmp ->> 'loja', cmp ->> 'produto', cmp ->> 'recibo_hash',
			case when cmp ->> 'valido_ate' is null then null else to_timestamp((cmp ->> 'valido_ate')::bigint) end)
		on conflict (loja, recibo_hash) do nothing;
		if not found then
			raise exception 'conflito_de_revisao';
		end if;
	end if;
	if cmp_estado is not null then
		update public.compra
		set estado = cmp_estado ->> 'estado',
			valido_ate = case when cmp_estado ->> 'valido_ate' is null then valido_ate
				else to_timestamp((cmp_estado ->> 'valido_ate')::bigint) end,
			atualizado_em = now()
		where loja = cmp_estado ->> 'loja' and recibo_hash = cmp_estado ->> 'recibo_hash';
	end if;
	if par is not null then
		insert into public.partida_pvp (atacante_id, defensor_id, semente, entradas, venceu, pontos_atacante, pontos_defensor)
		values (p_jogador, (par ->> 'defensor_id')::uuid, (par ->> 'semente')::bigint, par -> 'entradas',
			(par ->> 'venceu')::boolean, (par ->> 'pontos_atacante')::integer, (par ->> 'pontos_defensor')::integer);
	end if;
end;
$$;
revoke all on function public.aplicar_efeitos(uuid, jsonb) from public, anon, authenticated;

-- Candidatos de PvP: outros jogadores com defesa salva, na faixa de poder, mais
-- perto em pontos primeiro. O retrato sai só para a Edge Function (chave de serviço).
create or replace function public.candidatos_pvp(
	p_jogador uuid, p_pontos integer, p_poder integer, p_faixa integer, p_limite integer)
returns table (jogador_id uuid, nome text, pontos integer, poder integer, retrato jsonb, aparencia jsonb, brasao jsonb)
language sql
stable
security definer
set search_path = ''
as $$
	select p.jogador_id, p.nome, p.pontos, d.poder, d.retrato, p.aparencia, p.brasao
	from public.jogador_publico p
	join public.defesa_pvp d on d.jogador_id = p.jogador_id
	where p.jogador_id <> p_jogador
		and d.poder between p_poder - p_faixa and p_poder + p_faixa
	order by abs(p.pontos - p_pontos), p.jogador_id
	limit p_limite;
$$;
revoke all on function public.candidatos_pvp(uuid, integer, integer, integer, integer) from public, anon, authenticated;

-- Grava o estado E a resposta da ação na MESMA transação, com controle de
-- revisão. Devolve a nova revisão, -1 se o id já tinha resposta (repetida) ou
-- null se a revisão mudou (conflito: nada é gravado, nem o log).
create or replace function public.aplicar_acao(
	p_jogador uuid, p_estado jsonb, p_revisao_esperada bigint, p_id uuid, p_tipo text, p_resposta jsonb,
	p_efeitos jsonb default '{}'::jsonb)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
	nova bigint;
begin
	insert into public.jogador (id) values (p_jogador) on conflict (id) do nothing;
	begin
		insert into public.acao_log (jogador_id, id, tipo, resposta)
		values (p_jogador, p_id, p_tipo, p_resposta)
		on conflict (jogador_id, id) do nothing;
		if not found then
			return -1;
		end if;
		if p_revisao_esperada is null then
			insert into public.save_jogador (jogador_id, versao, dados)
			values (p_jogador, (p_estado ->> 'versao')::integer, p_estado)
			on conflict (jogador_id) do nothing
			returning revisao into nova;
		else
			update public.save_jogador
			set dados = p_estado, versao = (p_estado ->> 'versao')::integer
			where jogador_id = p_jogador and revisao = p_revisao_esperada
			returning revisao into nova;
		end if;
		if nova is null then
			raise exception 'conflito_de_revisao';
		end if;
		update public.jogador
		set nome = left(coalesce(p_estado -> 'cavaleiro' ->> 'nome', ''), 20),
			casa = left(coalesce(p_estado -> 'casa' ->> 'nome', ''), 20)
		where id = p_jogador;
		perform public.aplicar_efeitos(p_jogador, p_efeitos);
		return nova;
	exception when raise_exception then
		-- a subtransação desfaz o registro do log; o chamador refaz sobre o estado novo
		if sqlerrm = 'conflito_de_revisao' then
			return null;
		end if;
		raise;
	end;
end;
$$;
revoke all on function public.aplicar_acao(uuid, jsonb, bigint, uuid, text, jsonb, jsonb) from public, anon, authenticated;
