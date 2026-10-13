# Conta e save na nuvem (Supabase)

O que foi feito no prompt 2.12 e o estado da ligação com o servidor.

## Estado do projeto (2026-10-13)

- **Projeto:** `Torneio_Medieval`, ref `zhecikwngzhqajlpydrp`, região `sa-east-1`, Postgres 17. URL e chave publicável já estão em `game/data/servidor.json` (a chave publicável pode ir no repositório; a de serviço nunca).
- **Autenticação:** Anonymous sign-ins e Manual linking ligados no painel. Testado: o cadastro anônimo devolve sessão, e o RLS deixa cada um gravar só o próprio `jogador`/`save_jogador` (a `revisao` sobe sozinha 1, 2…; sem login, a leitura volta vazia). CAPTCHA (Turnstile) ainda não ligado.
- **Aplicado:** `contas_e_save` (`jogador`, `save_jogador`, RLS, gatilhos). `get_advisors` de segurança sem alertas.
- **Não aplicado:** `metricas` (a ferramenta de migração foi negada pelo modo automático; aplicar pelo conector com permissão ou colando o SQL no painel), `push` (falta Firebase) e `economia_rascunho` (Parte 3; o cliente não usa).
- **Sem branch de teste:** o projeto estava vazio e sem jogadores, e branch é recurso pago; a migração foi direto na produção (ver `docs/DECISOES.md`). A partir do primeiro jogador de verdade, toda mudança de esquema passa por branch.
- As migrações aplicadas pelo conector recebem a versão (data/hora) do momento da aplicação, não a do nome do arquivo local.
- Um usuário anônimo de teste (com uma linha em `jogador` e outra em `save_jogador`, `dados = {"teste": 2}`) ficou no projeto desse teste; pode apagar em Authentication → Users.

## Como funciona

- **Login anônimo no primeiro acesso** (`POST /auth/v1/signup` sem e-mail). O usuário anônimo usa o papel `authenticated`, então o RLS vale igual para anônimo e permanente.
- **Save na nuvem = o estado inteiro do jogador** (o JSON versionado do `ServicoJogador`) na tabela `save_jogador`, uma linha por conta. A coluna `revisao`, controlada pelo banco, cresce a cada envio.
- **Qual save vale:** a nuvem vence se o celular ainda não tem personagem (aparelho novo ou reinstalação) ou se a revisão da nuvem é maior que a última que este celular conhece (jogou em outro aparelho). Senão, o local é enviado.
- **Envio:** alguns segundos depois da última mudança (junta várias), com novas tentativas; se falhar, fica marcado como pendente e vai na próxima abertura.
- **Sessão:** guardada em `user://sessao.json`, separada do save. O token é renovado sozinho, inclusive ao receber 401.
- **Desligado:** sem `url` e `chave_publica` em `game/data/servidor.json`, o jogo funciona só com o save local.
- Código: `game/scripts/services/servico_nuvem.gd` (autoload **Nuvem**); a cena principal chama `Nuvem.iniciar()` antes de decidir a tela. Teste: `tests/services/nuvem_check.gd`, contra um Supabase falso em memória.

## Migrações (em `supabase/migrations/`)

1. `20261011120000_contas_e_save.sql` — tabelas `jogador` e `save_jogador`, com RLS (cada um lê e grava só o próprio), sem delete pelo cliente e com gatilhos que controlam `atualizado_em` e `revisao`. **Esta é a do 2.12.**
2. `20261011120100_economia_rascunho.sql` — **rascunho da Parte 3, não aplicar ainda.** Traz as tabelas de economia (`cavaleiro`, `carteira`, `cavalo`, `item`, `equipamento`, `predio`, `timer`, `pve_progresso`) com RLS só de leitura; quem escreve é a Edge Function. Na 3.1/3.2 o servidor vira o dono do estado e o save do cliente vira só cache.

## Para ligar (feito em 2026-10-13, menos o item 3)

1. ~~Criar um projeto~~ feito pelo usuário.
2. ~~Anonymous sign-ins e Manual linking~~ ligados.
3. Recomendado: CAPTCHA (Turnstile) para o login anônimo, que tem limite de 30 contas por hora por IP. **Pendente.**
4. ~~Aplicar a migração 1 e `get_advisors`~~ feito (sem branch, ver acima).
5. ~~Preencher `game/data/servidor.json`~~ feito.
6. Rodar o jogo de verdade (cena principal) e conferir no painel o usuário anônimo e a linha em `save_jogador`. **Pendente:** o teste feito foi pela API REST, com as mesmas chamadas do cliente.

## Vincular Google Play Games (sem perder o progresso)

O Supabase não tem Play Games como provedor pronto. O caminho planejado:

1. Plugin Android do Play Games Services v2 no Godot (build com Gradle), que entrega um *server auth code*.
2. Edge Function `vincular_play_games`, que troca o código com o Google, obtém o ID do jogador do Play Games e o liga ao usuário anônimo atual (identidade própria numa tabela `conta_vinculada`, com o ID do Google único). Num aparelho novo, a mesma função devolve uma sessão da conta já vinculada.
3. Alternativa mais simples: vincular **Google** (OAuth) com `linkIdentity`, abrindo o navegador e voltando por deep link.

Os dois caminhos usam o mesmo `user.id`, então o save continua o mesmo. Fica para quando o projeto existir e o plugin estiver instalado.

## Push pelo servidor (3.23)

Os avisos de timer (treino, cavalo, baú, forja, conserto, obra) são **locais**: o celular agenda pelo plugin de notificação (`docs/ANDROID.md`). Os avisos que só o servidor conhece (pedido de ajuda da ordem e fim de temporada) vão por push:

1. Plugin nativo de push (Firebase Cloud Messaging no Android; APNs no iOS) entrega o token do aparelho ao jogo.
2. O jogo chama `Nuvem.registrar_push(token, plataforma)`, que grava em `dispositivo_push` (migração `20261011120300_push.sql`, RLS só do próprio) o token e as preferências (as mesmas chaves da tela de Configurações, `estado.config.notificacoes`).
3. Uma Edge Function agendada (cron do banco) procura quem tem pedido de ajuda novo ou temporada acabando, respeita `preferencias` (tipo desligado = não manda; "todas" desligado = nada) e envia pela API do FCM, com a chave de serviço guardada como secret da função.

Nada disso está aplicado: depende do projeto Supabase e de uma conta Firebase (autorização do usuário).

