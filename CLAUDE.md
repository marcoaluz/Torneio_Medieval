# Torneio Medieval

Jogo mobile de carreira de cavaleiro de torneio. Godot 4.7 + GDScript, pixel art 2D, landscape, servidor Supabase no lançamento. Design completo em `docs/GDD.md`; roteiro de trabalho em `docs/PACOTE_DE_PROMPTS.md`.

## Continuidade entre sessões
- Ao começar qualquer sessão: leia docs/ESTADO.md e as últimas
  entradas de docs/SESSOES.md antes de fazer qualquer coisa.
- Ao terminar qualquer tarefa: rode /passagem.
- Se o limite de uso estiver perto, pare no próximo ponto estável e
  rode /passagem antes de qualquer outra coisa.
- Nunca deixe trabalho sem commit no fim de uma sessão.

## Regras fixas
- **Textos do jogo nunca no código.** Sempre em `game/i18n/` (pt_BR e en).
- **Números de balanceamento nunca no código.** Sempre em `game/data/balance/`.
- **Lógica da justa separada da apresentação.** `game/scripts/rules/` é puro: sem nós, cenas, tempo real nem aleatoriedade global; mesma entrada + mesma semente = mesmo resultado. Vai ser portado para TypeScript (Edge Function) e os dois lados rodam os casos de `tests/shared/`.
- **Economia nunca escrita direto na tela.** Só em `game/scripts/services/`, que depois viram chamadas ao servidor. Timers guardados como horário de término.
- Todo dado salvo tem versão.
- Arte provisória (retângulos) até a Parte 2; nós já preparados para trocar por sprites.

## Onde fica cada coisa
| Caminho | Conteúdo |
| --- | --- |
| `game/scenes/{arena,village,ui,common}` | Cenas |
| `game/scripts/rules` | Regra pura da justa e demais regras determinísticas |
| `game/scripts/presentation` | Câmera, efeitos, ligação com sinais |
| `game/scripts/services` | Save, economia, futuras chamadas ao servidor |
| `game/scripts/ai` | IA do rival |
| `game/data/balance`, `game/data/crests` | Dados (JSON/Resource) |
| `game/i18n` | Traduções |
| `game/art`, `game/audio` | Arte e som (estilo: ver Guia de estilo no Pacote) |
| `tests/` | Testes; `tests/shared/` = casos compartilhados GDScript/TypeScript |
| `docs/` | GDD, ESTADO, DECISOES, SESSOES, Pacote de Prompts |
| `.claude/skills/` | Skills do projeto (`passagem`, `retomar`, e as demais do Pacote) |

## Pixel art / resolução
Base 960×540, stretch `canvas_items`, aspect `expand`, filtro nearest, snap de pixel ligado, renderer Compatibility. Ver `docs/DECISOES.md`.

## Godot nesta máquina
Executável (não está no PATH): `D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe`
- Importar/validar: `"D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --import`
- Rodar cena: `... --path . res://caminho/cena.tscn`
- Rodar script de teste: `... --headless --path . -s res://tests/<script>.gd`

## Rodar e validar
Use a skill `/run-torneio-medieval` (`.claude/skills/run-torneio-medieval/driver.sh`): `import`, `script <res://x.gd>` para testes headless, `shot <cena>` para PNG da cena real.

## GodotPrompter
- Antes de implementar qualquer sistema Godot (câmera, entrada, máquina de estados, UI, animação, save etc.), procure a skill `godot-prompter:*` correspondente e siga-a. Vale também para subagentes.
- Diga qual padrão escolheu e qual alternativa descartou, e por quê, antes de construir.
- Se o plugin não estiver instalado nesta conta: `claude plugins marketplace add jame581/skillsmith` e `claude plugins install godot-prompter@skillsmith`.

## Onde paramos (para quem retomar)
Atualizado em 2026-10-13. O detalhe completo de cada sistema está em `docs/ESTADO.md`; a decisão e o motivo de cada escolha, em `docs/DECISOES.md`.

- **Pedido do usuário:** executar **todos** os prompts de `docs/PACOTE_DE_PROMPTS.md` em sequência, sem parar para revisão; ele analisa tudo depois.
- **Parar e perguntar antes de:** gastar crédito ou mexer em serviço externo. Isso inclui PixelLab, ElevenLabs, criar projeto ou aplicar migração no Supabase, Firebase, AdMob e lojas. Tudo o que é local, faça direto.
- **Feito:**
  - Parte 1: código 1.0–1.10. O 1.9 (APK) depende de instalar JDK, SDK e templates Android.
  - Parte 2: 2.1–2.11; 2.12 ligado ao projeto Supabase `Torneio_Medieval` (2026-10-13, migrações `contas_e_save` e `metricas` aplicadas); falta só o CAPTCHA no painel.
  - Parte 3: 3.12–3.25, todos locais. PvP, ordens, chat, compras e anúncios estão simulados ou com provedor de teste até o servidor existir.
- **Próximo, em ordem:**
  1. **Servidor 3.1–3.11: escrito e testado, nada publicado** (`docs/SERVIDOR.md`, `docs/OPERACAO.md`, `docs/AUDITORIA.md`):
     - regra e economia em TypeScript em `supabase/functions/_shared/`, testadas com Node 24 (`cd supabase && node --test "tests/regra/*.test.ts"`) contra `tests/shared/*.json` e os cenários gravados pelo GDScript;
     - migrações em `supabase/migrations/` (rascunho, não aplicadas) e Edge Functions escritas; só publicar/aplicar o que o usuário autorizar;
     - falta: o **cliente chamar `acao`** (fila de ações pendentes, estado do servidor vence; auditoria A1), publicar na branch e a Parte 4.
  2. **Supabase já existe** (usuário criou): falta ligar CAPTCHA e apagar os usuários de teste (ver `docs/NUVEM.md`). `push` e `economia_rascunho` seguem sem aplicar. Migração nova passa por branch a partir do primeiro jogador real.
  3. **Parte 4** (4.1–4.3: espada, arco, mêlée).
- **Fica com o usuário:** os prompts de arte (A*/B*/C*, PixelLab) e de som (S*, ElevenLabs), porque gastam crédito.
- **Fim de cada prompt:** rodar a suíte, atualizar ESTADO, DECISOES e SESSOES, e fazer commit, como faz a skill `/passagem`.

### Armadilhas já conhecidas
- **Scripts Python de edição:** grave com a ferramenta Write num arquivo do scratchpad e rode com `python -I arquivo.py`. Heredoc no Bash quebra com aspas, barras invertidas e acentos.
- **Números do JSON:** o Godot lê todo número do JSON como float, e `[6.0].has(6)` é falso. Compare com `int(x) == n`.
- **Autoload e classe:** os nomes não podem ser iguais. Por exemplo, o autoload `Fluxo` tem a classe `FluxoTelas`, e o autoload `Acessibilidade` tem a classe `OpcoesAcessibilidade`.
- **Leitura de dados:**
  - `Balanceamento.ler(nome)` e `ler_json(caminho)` devolvem um cache somente leitura (alterar dá erro);
  - `Balanceamento.carregar(nome)` devolve uma cópia;
  - em caminho quente, use `ler`.
- **Servidor em TypeScript:** mudou regra ou economia do GDScript? Mude o porte em `supabase/functions/_shared/`, regrave os cenários (`tools/gravar_cenarios.gd`) e rode os testes dos dois lados; sem enum/namespace/parâmetro-propriedade nos `.ts` (Node só apaga tipos). O relógio do GDScript pode ser parado com `ServicoTempo.fixo` (só para gravações).
- **Versão do save:** hoje é 11 (`ServicoJogador.VERSAO`). Todo campo novo no save ganha um passo em `migrar()` e uma linha em `docs/DADOS_JOGADOR.md`.
- **Mudança na regra da justa:**
  - regere os casos compartilhados com o oráculo Python correspondente;
  - regrave as gravações com `TM_GRAVAR=1` em `tests/rules/justa_simulacao_check.gd` e `tests/ai/ia_justa_check.gd`.

  Os oráculos ficavam no scratchpad da sessão e podem não existir mais. Nesse caso, reescreva o oráculo a partir da especificação no topo do arquivo da regra.
- **Demos e capturas:** `tests/fluxo/modo_demo.tscn` com as variáveis `TM_TELA`, `TM_ABA`, `TM_TORNEIO` e outras, listadas no topo de `modo_demo.gd`, mais `driver.sh shot` para gerar o PNG.
- **Desempenho:** `tools/benchmark.tscn`. **Economia:** `tools/simular_economia.gd`. Rode a simulação de novo se mexer em `economia.json`.

## Nunca
- Colocar texto ou número de balanceamento fixo no código.
- Dar à regra da justa dependência de cena, nó ou tempo real.
- Escrever economia ou ranking pelo cliente (a partir da Parte 3, sempre Edge Function + RLS).
