# Operação do servidor (3.10)

Como publicar, observar e socorrer o servidor do Torneio Medieval. **Nada disto foi executado ainda**: o projeto Supabase (`Torneio_Medieval`, ref `zhecikwngzhqajlpydrp`, sa-east-1) só tem aplicadas as migrações `contas_e_save` e `metricas`. As regras de segurança estão na skill `supabase-jogo`; o desenho, em `docs/SERVIDOR.md`; os riscos, em `docs/AUDITORIA.md`.

## Ambientes

| Ambiente | Para quê | Como |
| --- | --- | --- |
| **Branch de teste** | aplicar migrações e testar funções antes da produção | `create_branch` do conector (tem custo por hora); aplicar as migrações e o seed na branch, publicar as funções com os segredos de teste, rodar o app apontando para a branch |
| **Produção** | jogadores | só recebe o que já passou na branch; `merge_branch` leva as migrações |

Regra: **a partir do primeiro jogador real, nenhuma migração vai direto para produção.** Hoje o projeto está vazio, então a exceção da `contas_e_save` foi aceita (`docs/DECISOES.md`).

## Ordem de publicação (primeira vez)

1. **Branch**: criar, aplicar `supabase/migrations/*.sql` na ordem dos nomes, **menos** `20261013120100_economia_so_servidor.sql` (só entra com o app novo).
2. **Seed**: `python -I tools/exportar_balanceamento.py` e aplicar `supabase/seed/balanceamento.sql` (tabela `balanceamento`).
3. **Segredos das funções** (`create_edge_function_secret`): `GOOGLE_PLAY_PACOTE`, `GOOGLE_PLAY_CLIENT_EMAIL`, `GOOGLE_PLAY_PRIVATE_KEY`, `LOJA_WEBHOOK_SEGREDO`. **Nunca** `PERMITIR_LOJA_TESTE=1` em produção (só em desenvolvimento).
4. **Funções**: `acao` e `excluir_conta` (com verificação de JWT, o padrão) e `loja_webhook` (`--no-verify-jwt`, protegida pelo segredo na URL).
5. **Conferir**: `get_advisors` (segurança e desempenho), `query_logs`, um jogador de teste fazendo cada ação.
6. **Produção**: `merge_branch`; depois, no mesmo dia do app novo, aplicar `20261013120100_economia_so_servidor.sql`.
7. **CAPTCHA** (Turnstile) no login anônimo e **Anonymous sign-ins** ligado (painel).
8. **Rotinas**: cron (`pg_cron` + `pg_net`) para `limpar_logs_de_acao` (diário) e, se houver, chamadas às funções de rotina.

## Backup

- Plano pago do Supabase: backup diário automático (7 dias no Pro) e **PITR** como opção. Ligar PITR antes do lançamento (consta em `get_project`/painel > Database > Backups).
- Antes de qualquer migração destrutiva em produção: `pg_dump` pelo painel (Database > Backups > Download) ou uma branch de ensaio.
- Teste de restauração: restaurar para uma branch uma vez antes do lançamento.

## Registro de erros

- **Funções**: `console.error` (logs do Supabase, curtos) e a tabela `erro_servidor` (persistente). Consultar: `select * from public.painel_erros_recentes;`.
- **Jogo**: autoload `Registro` (`registro_erros.gd`) manda `erro_jogo` pelas métricas (até 20 por sessão, sem repetir arquivo:linha) e entra no mesmo painel.
- `query_logs` do conector para logs de `edge-function`, `postgres` e `auth`.

## Painel (consultas prontas)

Views criadas pela migração, só acessíveis pelo painel do Supabase (e chave de serviço):

| View | Mostra |
| --- | --- |
| `painel_jogadores_ativos_dia` | jogadores distintos com `sessao` por dia |
| `painel_novos_jogadores_dia` | contas criadas por dia |
| `painel_compras_dia` | compras por dia, loja, produto e estado (reembolsos) |
| `painel_denuncias_abertas` | fila de denúncias, a mais denunciada primeiro |
| `painel_funil_tutorial` | jogadores por passo do tutorial |
| `painel_desistencias` | onde desistem (fase da justa) |
| `painel_erros_recentes` | erros do servidor e do jogo |

## Rotinas de socorro

- **Revisar denúncia**: `update public.denuncia set status = 'revisada' where id = ...`; para punir: `insert into public.silenciamento (jogador_id, ate, motivo) values (..., now() + interval '7 days', 'revisao')`.
- **Banir conta**: `auth.admin.deleteUser` (apaga tudo) ou desativar o usuário no painel (Authentication > Users).
- **Desfazer ganho indevido** (bug de economia): corrigir o estado com `update public.save_jogador set dados = jsonb_set(...)` numa transação; o gatilho sobe a revisão e o app recebe o estado novo na próxima ação.
- **Compra reembolsada que o webhook perdeu**: `update public.compra set estado = 'reembolsada' ...` e ajustar o estado do jogador (gemas/VIP) pelo mesmo comando acima.
- **Balanceamento errado no ar**: inserir a versão anterior como nova linha (`versao + 1`, `ativa = true`) e desativar a ruim; o app pega na próxima abertura.
- **Função com bug**: `deploy_edge_function` da versão boa; o estado é só documento versionado (nada a migrar).

## Variáveis e limites que mexem na operação

`game/data/balance/servidor.json` (tabela `balanceamento`, privada): ações por minuto, mensagens por minuto, denúncias para silenciar, espera entre disputas, limites do anticheat. Mudar no painel (nova versão ativa) vale sem lançar o app.
