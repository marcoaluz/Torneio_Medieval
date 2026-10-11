# Conta e save na nuvem (Supabase)

O que foi feito no prompt 2.12 e o que falta para ligar de verdade. **Nada foi criado nem aplicado no Supabase**: criar um projeto pode ter custo e é uma ação externa, e isso fica para você autorizar. Na conta conectada só existe o projeto "Agro GFI", que não é deste jogo.

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

## Para ligar (precisa da sua autorização)

1. Criar um projeto para o jogo no Supabase, na organização "Projetos Marco Luz", região `sa-east-1`. Confira o plano e o custo; posso fazer pelo conector quando você autorizar.
2. Em **Authentication → Sign In / Providers**, ligar **Anonymous sign-ins** e **Manual linking** (este último para vincular conta depois).
3. Recomendado pela documentação: ligar CAPTCHA (Turnstile) para o login anônimo, que tem limite de 30 contas por hora por IP.
4. Aplicar a migração 1, de preferência numa branch de teste primeiro (skill `supabase-jogo`), e rodar `get_advisors` de segurança.
5. Preencher `game/data/servidor.json` com a URL do projeto e a **chave publicável** (anon/publishable). Nunca a de serviço.
6. Rodar o jogo; o painel do Supabase deve mostrar o usuário anônimo e a linha em `save_jogador`.

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

