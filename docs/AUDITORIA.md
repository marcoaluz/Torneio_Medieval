# Auditoria de segurança do servidor (3.11)

Revisão do código e do esquema do servidor (`supabase/`) e do cliente (`game/scripts/services`) antes do lançamento. **Feita por leitura e por testes automáticos** (`supabase/tests/regra/`); nada foi exercitado contra um projeto Supabase real nem contra as lojas, por isso a seção "Abertos" não é opcional. Escopo: regras de acesso (RLS), Edge Functions, chaves, duplicação de itens e moedas, trapaça na justa e no PvP, abuso de chat e de compras.

Gravidade: **Alta** (dá vantagem ou dinheiro de graça, ou expõe dados), **Média** (abuso com esforço ou degradação), **Baixa** (higiene).

## Corrigidos nesta auditoria

| # | Gravidade | Problema | Correção | Teste |
| --- | --- | --- | --- | --- |
| 1 | Alta | **Re-sorteio da semente de PvE**: o cliente pedia `iniciar_disputa` quantas vezes quisesse, simulava cada semente com a mesma regra e só enviava a que dava 3 estrelas | iniciar de novo a mesma disputa devolve a **mesma** semente; abandonar zera a sequência e exige espera (`limites.cooldown_disputa_s`) | `servidor.test.ts` (auditoria) |
| 2 | Alta | **Espiar adversários de PvP de graça** até achar um fraco | procurar outro com um pendente conta como **derrota** (pontos e histórico, `abandonou`) | `pvp.test.ts` |
| 3 | Alta | **Loja de teste ligável por dado** (`aceitar_loja_teste` no balanceamento remoto): um erro de configuração entregaria compras de graça | removida do dado; só com variável de ambiente `PERMITIR_LOJA_TESTE=1` da função (nunca em produção) | `servidor.test.ts`, `compras.test.ts` |
| 4 | Média | `sou_da_ordem` ficava executável por `anon` (privilégio padrão do Supabase) | `revoke ... from public, anon`; guarda estática confere toda função privilegiada | `migracoes.test.ts` |
| 5 | Média | **Silenciar alguém com contas anônimas novas** (gratuitas): 5 denúncias de contas criadas agora calavam qualquer jogador | só contam denúncias de contas com mais de 1 dia e nível 3+ | revisão do SQL |
| 6 | Média | **Lixo nas métricas**: o cliente podia inserir sem limite em `evento_metrica` | gatilho: no máximo 600 eventos por jogador por hora | revisão do SQL |
| 7 | Média | **Chat sem limite próprio** (`chat_por_minuto` existia nos dados, mas não era aplicado) | contador por minuto no comando do chat | `social.test.ts` |
| 8 | Média | Corpo de requisição sem limite na função `acao` | recusa acima de 64 KB | revisão |
| 9 | Baixa | Erros das funções só nos logs curtos do Supabase | tabela `erro_servidor` + `registrar_erro` | `painel_erros_recentes` |

## O que já era seguro por desenho (verificado)

- **Toda tabela com RLS na criação** (22 tabelas novas + 4 anteriores) e **nenhuma política de escrita do cliente em economia, ranking, compras nem partidas** (a guarda estática `migracoes.test.ts` falha se alguém criar uma).
- **Chave de serviço só dentro das Edge Functions**; o app só tem a chave publicável (`game/data/servidor.json`).
- **Estado e resposta na mesma transação** (`aplicar_acao`): nunca entrega sem registro nem registra sem entregar; o `id` da ação torna a repetição inofensiva (`servidor.test.ts`).
- **Concorrência**: gravação com revisão esperada; conflito refaz sobre o estado novo (teste de conflito).
- **Argumentos**: formato por comando, tamanho, profundidade e chaves perigosas (`__proto__`, `constructor`, `prototype`) recusados antes da regra; consultas por nome usam chave própria (`tem`).
- **Comandos internos** (`ganhar_bau`, `entregar_compra`, `registrar_justa`...) inexistentes para o cliente.
- **Relógio e semente do servidor**: horário, semente da justa e da disputa automática; o cliente só manda entradas.
- **Justa refeita**: entradas em ordem, toques com no mínimo 40 ms, tempo real maior que a soma das fases; resultado vem da regra, nunca do cliente.
- **Compras**: recibo conferido com a loja por quem não é o celular, hash único (`loja`, `recibo_hash`), recibo de outro jogador é fraude, reembolso e renovação por webhook com segredo comparado em tempo constante.
- **Efeito em outro jogador só na ação dele**: ajuda e doação são gravadas na tabela e aplicadas por quem recebe, na próxima ação (o estado de outro jogador nunca é tocado por quem ajuda).
- **Tabelas privadas de balanceamento** (`servidor`, `nomes_proibidos`): limites do anticheat não saem para o app.

## Abertos (antes de lançar)

| # | Gravidade | Problema | O que fazer |
| --- | --- | --- | --- |
| A1 | **Alta** | **O cliente ainda grava o save direto** (2.12): enquanto `20261013120100_economia_so_servidor.sql` não for aplicada, qualquer um edita ouro e itens | trocar o cliente para chamar `acao` e aplicar a migração junto (fila de ações pendentes; o estado do servidor vence). **2026-10-14: cliente pronto e testado (`usar_acao`), falta PvP/social pelo servidor, aplicar a migração e publicar** |
| A2 | Alta | Verificador de recibos do **Google** nunca foi exercitado com a loja; **Apple** não existe | compra de teste licenciada (Play Console) ponta a ponta; implementar App Store Server API (JWS) antes de lançar no iOS |
| A3 | Média | Anúncios premiados: **SSV não implementado** (`verificar_anuncio` recusa tudo; só o VIP recebe) | assinatura SSV do AdMob na função, quando a conta existir |
| A4 | Média | **Contas anônimas gratuitas e sem limite por IP**: multi-conta, spam, fuga de silenciamento | CAPTCHA (Turnstile) no cadastro; limite por IP no Auth |
| A5 | Média | Anticheat de justa é só de **tempo e cadência**: um robô que toca e mira perfeito passa (a oscilação da mão é da apresentação e o servidor não a vê) | estatística no servidor (variância da mira, reação), banimento por padrão repetido; o `partida_pvp` guarda semente e entradas para investigar |
| A6 | Média | `chat_mensagem.texto` guarda o que o jogador escreve | o cliente mostra como texto simples (já faz); revisar se houver HTML/Markdown no futuro |
| A7 | Baixa | `anuncios.timers` e `loja.compras` crescem sem limite no documento (limite duro de 512 KB na tabela) | truncar os mais antigos numa migração do estado |
| A8 | Baixa | `jogador_publico.codigo` é único: colisão (≈ 1 em 1 bilhão) derrubaria uma ação | gerar o código no banco com repetição; hoje é raro demais para pesar |
| A9 | Baixa | Parte do GDScript depende de `OS.is_debug_build()` para compras de teste | em build de lançamento a loja devolve `loja_indisponivel` até o app novo chamar `comprar_recibo` |
| A10 | Info | CORS `*` nas funções (app móvel, sem cookies) | restringir se houver versão web |

## Como repetir

1. `cd supabase && node --test "tests/regra/*.test.ts"` (paridade, ações, PvP, compras, social, migrações).
2. `bash tests/rodar_testes.sh` (os dois lados).
3. Depois de publicar na branch: `get_advisors` (security e performance) e as consultas do painel; repetir os testes de abuso à mão com dois aparelhos (ajuda, doação, compra repetida, abandono de partida).
