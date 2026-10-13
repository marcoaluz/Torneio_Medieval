# Servidor (Parte 3: 3.1–3.11)

Estado do lado servidor e o que ainda falta. **Nada aqui foi publicado** nas Edge Functions do projeto Supabase `Torneio_Medieval` (`zhecikwngzhqajlpydrp`); só as migrações `contas_e_save` e `metricas` foram aplicadas (ver `docs/NUVEM.md`). Regras do projeto para o servidor: skill `supabase-jogo`.

## Regra em TypeScript (3.4, feito e testado)

`supabase/functions/_shared/regra/` é o porte, arquivo por arquivo, de `game/scripts/rules/` e `game/scripts/ai/ia_rival.gd`:

| TypeScript | GDScript | Casos compartilhados |
| --- | --- | --- |
| `aleatorio.ts` | `rules/aleatorio.gd` | `galope.json` (campo `aleatorio`) |
| `justa_fases.ts` | `rules/justa_fases.gd` | `justa_fases.json` |
| `galope.ts` | `rules/galope.gd` | `galope.json` |
| `mira.ts` | `rules/mira.gd` | `mira.json` |
| `impacto.ts` | `rules/impacto.gd` | `impacto.json` |
| `ia_rival.ts` | `ai/ia_rival.gd` | `ia_rival.json` |
| `justa.ts` | `rules/justa.gd` | `justa_referencia.json`, `justa_referencia_ia.json` |
| `conjuntos.ts` | `rules/conjuntos.gd` | `conjuntos.json` |
| `forja.ts` | `rules/forja.gd` | `forja.json` |
| `bau.ts` | `rules/bau.gd` | `baus.json` |
| `liga.ts` | `rules/liga.gd` | `liga.json` |
| `pve.ts` | `rules/pve.gd` | `desafios_pve.json` |
| `ordem.ts` | `rules/ordem.gd` | `ordem.json` |

- **Como rodar:** `cd supabase && node --test "tests/regra/*.test.ts"` (Node 24 roda `.ts` direto, apagando os tipos; por isso nada de `enum`, `namespace` nem parâmetros-propriedade nos arquivos). `bash tests/rodar_testes.sh` roda os dois lados juntos.
- **Os dois lados rodam os mesmos arquivos** de `tests/shared/`. As gravações da justa (`justa_referencia*.json`) são o teste mais forte: o TypeScript tem que reproduzir, evento por evento (formato `tipo|chave=valor` do `str()` do GDScript), a justa que o GDScript gravou, inteira e picada em 1, 17 e 33 ms.
- **Mudou a regra?** Mude os dois lados, regere os casos com o oráculo Python (ver "Armadilhas" no `CLAUDE.md` e a skill `regra-da-justa`) e regrave as referências com `TM_GRAVAR=1`; o teste dos dois lados falha se ficarem diferentes.
- **Convenções do porte:** nomes iguais aos do GDScript (snake_case) para comparar linha a linha; só inteiros, divisão com `Math.trunc`; `tem()` (chave própria) no lugar de `in` ao consultar tabelas por nome vindo de fora (evita `"constructor"`); nada de `Date.now()`, `Math.random()` nem estado global.
- **O que o teste já pegou:** laço `for` com limite recalculado depois de esvaziar a lista (`ordens_simuladas`); o GDScript avalia o limite uma vez.

## Economia no servidor (3.1–3.3, escrito e testado; não publicado)

**Modelo.** O estado do jogador é UM documento versionado (`save_jogador.dados`, o mesmo JSON do `ServicoJogador`, ver `docs/DADOS_JOGADOR.md`) e o servidor é o dono dele. O cliente só lê. Toda mudança entra pela Edge Function `acao`, que aplica o comando em TypeScript sobre o estado do servidor, com o relógio do servidor. Dados compartilhados entre jogadores (ranking, PvP, ordens, chat, amigos, denúncias, compras) são tabelas relacionais.

| Peça | Arquivo | Para quê |
| --- | --- | --- |
| Esquema (3.1) | `supabase/migrations/20261013120000_servidor_completo.sql` | tabelas com RLS em todas, funções `aplicar_acao`, `guardar_resposta_acao`, `contar_chamada` |
| Escrita só do servidor | `supabase/migrations/20261013120100_economia_so_servidor.sql` | tira a escrita do cliente em `save_jogador`/`jogador`; aplicar junto com o app que chama `acao` |
| Comandos (3.2) | `supabase/functions/_shared/servidor/jogador.ts`, `pve.ts` | porte do `ServicoJogador` (economia solo): vila, treino, cavalos, conserto, forja, metas, loja, anúncios, baús, PvE, tutorial |
| Despacho e limites | `comandos.ts`, `esquema.ts`, `handler.ts` | comandos públicos x internos, validação de argumentos, idempotência por `id`, limite por minuto, concorrência por revisão |
| Justa conferida (3.4) | `disputa.ts` | `iniciar_disputa` (semente do servidor) e `concluir_disputa_conferida` (refaz a justa com as entradas) |
| Função do Supabase | `supabase/functions/acao/index.ts`, `banco_supabase.ts` | liga o handler ao banco (chave de serviço só dentro da função) |
| Balanceamento (3.3) | tabela `balanceamento`, `supabase/seed/balanceamento.sql`, `tools/exportar_balanceamento.py` | números mudam no painel, sem lançar versão; cliente baixa e guarda em cache (`Nuvem.baixar_balanceamento`, `Balanceamento.aplicar_cache_remoto`) |

**Paridade com o GDScript.** O `ServicoJogador` é a referência. `tools/gravar_cenarios.gd` roda cenários escritos à mão (`tests/shared/cenarios_servico_entrada.json`, 6 cenários, 229 passos) e grava resultado e o que mudou no estado de cada passo (`tests/shared/cenarios_servico.json`, relógio parado); `supabase/tests/regra/cenarios.test.ts` reexecuta tudo em TypeScript e exige o mesmo resultado e a mesma mudança de estado. Regravar: `bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/gravar_cenarios.gd` (depois de mudar o GDScript de propósito; os cenários ficam em `tools/gerar_cenarios_entrada.py`, que gera `cenarios_servico_entrada.json`).

**O que o servidor decide sozinho** (o cliente não escolhe): a semente da justa (`iniciar_disputa`) e a da disputa automática (`disputa_automatica` sem semente no formato público); o relógio; quem ganha (a justa é refeita pela regra); a validade do anúncio premiado (comprovante conferido antes de entregar; VIP dispensa).

**Segurança embutida.**
- Comandos internos (`ganhar_bau`, `entregar_compra`, `registrar_justa`, `adicionar_cavalo`, `concluir_disputa`) não existem para o cliente.
- Argumentos: tipo, tamanho, profundidade e chaves perigosas (`__proto__`, `constructor`, `prototype`) são recusados antes de chegar à regra; `tem()` (chave própria) em toda consulta por nome.
- Conferência da justa: entradas em ordem, toques com no mínimo 40 ms entre si, tempo real maior que a soma das fases (`tempo_impossivel`), disputa guardada no estado com o retrato dos dois lados (balanceamento que mudou no meio não desalinha).
- Estado e resposta da ação gravados na mesma transação: nunca há entrega sem registro (nem registro sem entrega).
- Parâmetros do anticheat e da lista de palavras ficam em tabelas `publico = false`, que só a função lê.

## PvP, ligas, compras, social e obrigações (3.5–3.11, escrito e testado; não publicado)

| Peça | Arquivo | Para quê |
| --- | --- | --- |
| PvP e ligas (3.5/3.6) | `liga.ts` | defesa como retrato (`defesa_pvp`), adversário real pareado pela regra ou fantasma do servidor, partida conferida (justa refeita), pontos do defensor, temporada **global** (grade fixa, virada preguiçosa por jogador), resumo público (`jogador_publico`) |
| Efeitos relacionais | `aplicar_efeitos`, `aplicar_ops_sociais`, `candidatos_pvp` (SQL) | tudo que não é o documento do jogador sai em `resultado._efeitos` e é gravado **na mesma transação** do estado |
| Compras (3.7) | `compras.ts`, `loja_google.ts`, `webhook.ts`, `functions/loja_webhook` | recibo conferido, entrega única, reembolso/renovação/cancelamento por webhook; Apple e SSV de anúncios ainda não existem |
| Social (3.8) | `social.ts` | ordem (criar, entrar, cargos, líder, editar), ajuda e doação aplicadas por quem recebe, torneio semanal real, loja da ordem, chat (ordem e global por idioma, filtro, limite, silenciamento), amigos por código; denúncia e bloqueio direto por RLS + gatilho de silenciamento |
| Obrigações (3.9) | `excluir_conta.ts`, `functions/excluir_conta`, `tela_privacidade`, Configurações | exclusão de conta no app (servidor e aparelho), política e termos com aceite por versão, consentimento de anúncios personalizados |
| Operação (3.10) | `docs/OPERACAO.md`, views `painel_*`, `erro_servidor`, autoload `Registro` | branch, backup, registro de erros do jogo e das funções, painel |
| Auditoria (3.11) | `docs/AUDITORIA.md`, `migracoes.test.ts` | achados e correções; guarda estática de RLS e privilégios |

**Falta:** o **cliente chamar `acao`** (hoje ele aplica local e grava o save direto; ver A1 na auditoria): fila de ações pendentes em `Nuvem`, estado do servidor vence na sincronização, justa de PvE e PvP com `iniciar_disputa`/`procurar_adversario` e envio das entradas, tela social ligada às funções reais (no lugar das simuladas) e a migração `economia_so_servidor`. Depois, publicar (ver `docs/OPERACAO.md`) com a autorização do usuário.
