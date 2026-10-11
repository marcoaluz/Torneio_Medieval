---
name: supabase-jogo
description: Regras de servidor do Torneio Medieval (Supabase): nunca escrever economia pelo cliente, sempre Edge Function, RLS em toda tabela nova, migrações testadas na branch antes da produção, timers pelo relógio do servidor e compras validadas. Use SEMPRE que for criar ou mudar tabela, migração, política RLS, Edge Function, login, save na nuvem, baú, forja, compra, PvP, liga, chat ou qualquer dado de jogador no servidor, mesmo que pareça "só uma tabela simples".
---

# Supabase do jogo

O servidor manda em tudo que vale algo: ouro, gemas, itens, timers, resultados de PvP e compras. O celular só mostra e envia ações. O jogo vai ter jogadores tentando trapacear e dinheiro de verdade envolvido; cada regra abaixo fecha uma brecha concreta. Visão geral em `docs/GDD.md` (seção Infraestrutura online). O Supabase é acessado pelo **conector já ligado à conta** (ferramentas `mcp__claude_ai_Supabase__*`), não por CLI.

## Regras

1. **Economia nunca pelo cliente.** O app nunca escreve diretamente ouro, gemas, itens, XP, timers, ranking nem compras. Isso passa por **Edge Function**, que valida tudo, confere permissão e grava.
2. **RLS em toda tabela nova, no mesmo migration que a cria.** Padrão: o jogador lê só os próprios dados (`auth.uid()`) e **não tem permissão de escrita** em nada de economia ou ranking. Tabela sem RLS é tabela aberta. Depois de criar, rode `get_advisors` (segurança) e corrija os alertas.
3. **Chave pública no app, chave de serviço só nas Edge Functions.** Nunca coloque `service_role` nem segredo no cliente, no repositório ou em logs. Segredos de função via `create_edge_function_secret`.
4. **Timers pelo relógio do servidor.** Guarde horário de término; mudar a hora do celular não acelera nada. O cliente só mostra a contagem.
5. **Idempotência e limite de chamadas.** Repetir a mesma chamada (rede ruim, toque duplo, reenvio) não entrega duas vezes: use chave de idempotência por ação. Cada função limita chamadas por jogador.
6. **Justa e PvP recalculados no servidor** com a mesma regra do cliente (ver `regra-da-justa`); valores impossíveis são rejeitados antes de qualquer recompensa.
7. **Compras:** valide o recibo da Google Play ou App Store no servidor antes de entregar; trate reembolso, renovação e cancelamento do VIP, compra repetida e restaurar compras. Nada é entregue só porque o celular disse que pagou.
8. **Conexão fraca:** o cliente repete o envio e guarda a ação até confirmar; nunca se perde uma vitória por queda de conexão.

## Fluxo de mudança

1. Antes de mexer, inspecione o estado atual (`list_tables`, `list_migrations`).
2. Crie ou use uma **branch de teste** (`create_branch`); aplique as migrações nela com `apply_migration` e teste lá. Só depois faça merge para produção. Migração aplicada direto em produção é difícil de desfazer.
3. Toda alteração de esquema é migração com nome descritivo (nunca `execute_sql` para DDL).
4. Edge Functions em TypeScript (`deploy_edge_function`), com verificação de JWT ligada, exceto webhooks assinados de loja.
5. Depois da mudança: `get_advisors` (segurança e desempenho), `query_logs` se algo falhar, e `generate_typescript_types` para manter os tipos alinhados.
6. Registre decisões de esquema ou de segurança em `docs/DECISOES.md`.

## Mapa do GDD

Auth anônimo no primeiro acesso, vinculando Google Play Games ou Game Center depois sem perder progresso. Tabelas: jogador, cavaleiro, casa, cavalos, inventário, equipamento, vila, timers, PvE, baús, forja, ligas, temporadas, partidas, defesas de PvP, ordens, chat, amigos, denúncias, compras, eventos de métricas. Balanceamento remoto em tabelas versionadas (ver `balanceamento`). Tarefas agendadas por cron do banco (temporadas, campeonatos). Obrigações: exclusão de conta no app, política de privacidade, probabilidades dos baús visíveis, backup e registro de erros.
