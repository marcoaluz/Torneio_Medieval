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
Atualizado em 2026-10-14. O detalhe completo de cada sistema está em `docs/ESTADO.md`; a decisão e o motivo de cada escolha, em `docs/DECISOES.md`.

- **Pedido do usuário:** executar **todos** os prompts de `docs/PACOTE_DE_PROMPTS.md` em sequência, sem parar para revisão; ele analisa tudo depois.
- **Parar e perguntar antes de:** gastar crédito ou mexer em serviço externo. Isso inclui PixelLab, ElevenLabs, criar projeto ou aplicar migração no Supabase, Firebase, AdMob e lojas. Tudo o que é local, faça direto.
- **Feito:**
  - Parte 1: código 1.0–1.10. O 1.9 (APK) já exporta: `--headless --path . --export-debug "Android" build/android/torneio_medieval.apk`, com JDK 17 e SDK em `D:\DEV\Android\` (ver `docs/ANDROID.md`); falta testar num celular real.
  - Parte 2: 2.1–2.11; 2.12 ligado ao projeto Supabase `Torneio_Medieval` (2026-10-13, migrações `contas_e_save` e `metricas` aplicadas); falta só o CAPTCHA no painel.
  - Parte 3: 3.12–3.25, todos locais. PvP, ordens, chat, compras e anúncios estão simulados ou com provedor de teste até o servidor existir.
- **Próximo, em ordem:**
  0. **Arte e som gerados (2026-10-14/15)** com o crédito autorizado pelo usuário: todos os sons, a voz do arauto (`00x0gOIgUbOG6wYRHdVH`), prédios, retratos, cavaleiro/cavalo/7 conjuntos em camadas nos 3 tamanhos, arena, chão da vila e interface (`docs/PERSONAGEM.md` > Geração automática; `tools/gerar_personagem*.py`, `gerar_arena.py`, `gerar_ui.py`). Geradores: `tools/gerar_sons.py`, `tools/gerar_arte.py`, `tools/montar_folhas_vila.gd`; chaves em `.chaves.env` na raiz (fora do git; nunca ler nem mostrar). Gerar de novo gasta crédito: perguntar antes. A cota do PixelLab do mês acabou em 2026-10-15; faltam 7 caparações das peças novas (`tools/gerar_pecas_novas.py`, ver ESTADO).
  1. **Servidor 3.1–3.11: escrito e testado, nada publicado** (`docs/SERVIDOR.md`, `docs/OPERACAO.md`, `docs/AUDITORIA.md`):
     - regra e economia em TypeScript em `supabase/functions/_shared/`, testadas com Node 24 (`cd supabase && node --test "tests/regra/*.test.ts"`) contra `tests/shared/*.json` e os cenários gravados pelo GDScript;
     - migrações em `supabase/migrations/` (rascunho, não aplicadas) e Edge Functions escritas; só publicar/aplicar o que o usuário autorizar;
     - **cliente chamando `acao` pronto e testado (2026-10-14), desligado** em `servidor.json > usar_acao`; falta PvP e social pelo servidor antes de ligar, aplicar `economia_so_servidor`, publicar na branch e a Parte 4.
  2. **Supabase já existe** (usuário criou): falta ligar CAPTCHA e apagar os usuários de teste (ver `docs/NUVEM.md`). `push` e `economia_rascunho` seguem sem aplicar. Migração nova passa por branch a partir do primeiro jogador real.
  3. **Parte 4** (4.1–4.3: espada, arco, mêlée).
- **Fica com o usuário:** a chave do PixelLab e do ElevenLabs (em `.chaves.env`) e a curadoria do que for gerado; o personagem em camadas (A*/B*) segue o processo manual de `docs/PERSONAGEM.md`.
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
- **Comando público novo no `ServicoJogador`:** escreva como `_cmd_<nome>` e acrescente o invólucro na seção "comandos públicos" (é ele que avisa `acao_feita` para a fila do servidor); o nome tem que existir em `PUBLICOS` no TypeScript.
- **Som:** todo som entra primeiro em `game/data/audio/sons.json`; o jogo acha `<pasta>/<id>_NN.(ogg|mp3|wav)`. Sem arquivo, não toca.
  - **Som dos prédios:** som de prédio só com a tela dele aberta e fade de 0,3 s ao sair; na vila, só a trilha e o ambiente da vila.
  - **Gerenciador único:** todo som passa pelo autoload `Audio` (música, ambiente por tela, efeitos por tela, interface); nunca `AudioStreamPlayer` em cena.
  - **Prédio ou tela nova:** ambiente em `sons.json > telas` e um caso em `tests/audio/som_telas_check.gd` (skill `som`).
- **Ferramentas de arte (PixelLab):** rodar com `python -E -P` (o Pillow está na pasta do usuário; `-I` a esconde). Cliente em `tools/pixellab_cliente.py` (cache em `game/art/fontes/cache/`, fora do git). Limites que já morderam: altura múltipla de 4; pixen até 768 de largura; edit/transfer de 160 px = 4/3 quadros por pedido; quadros em `{"image":…, "size":…}`; o servidor às vezes devolve 504 (o cliente reenvia).
- **Arena:** pistas em y=270 (rival, atrás da cerca) e y=340 (jogador, na frente).
  - A câmera de cada fase está em `controlador_justa.gd` (`_ao_entrar_na_fase`) e os zooms em `camera_arena.gd`/exports do controlador.
  - Corrida e Mira usam um plano só (`duelo`); o corte é só no acerto.
  - A pista desenhada sai de `px_por_unidade_corrida`/`fator_mira` (`_preparar_pista` → `Arena.ajustar_pista`), não das marcas da cena. Mexeu nas pistas? Confira as capturas de cada fase (16:9 e 20:9) e o `justa_check`.
- **Mudou a geometria do cavaleiro?** Meça as zonas na arte, atualize `mira.json`, os pontos fixos dos testes e regrave as referências (`TM_GRAVAR=1`) e os cenários (`tools/gravar_cenarios.gd`).
- **Versão do save:** hoje é 11 (`ServicoJogador.VERSAO`). Todo campo novo no save ganha um passo em `migrar()` e uma linha em `docs/DADOS_JOGADOR.md`.
- **Mudança na regra da justa:**
  - regere os casos compartilhados com o oráculo Python correspondente;
  - regrave as gravações com `TM_GRAVAR=1` em `tests/rules/justa_simulacao_check.gd` e `tests/ai/ia_justa_check.gd`.

  Impacto e IA têm oráculo no repositório: `tools/oraculo_impacto.py` e `tools/oraculo_ia_rival.py` (`gerar` embute os dados atuais e refaz o esperado; `conferir` só compara). Os demais ficavam no scratchpad da sessão e podem não existir mais; nesse caso, reescreva o oráculo a partir da especificação no topo do arquivo da regra.
- **Derrubada:** a base e o teto vêm da largada de quem bate (`impacto.json > derrubada > por_largada`). Mexeu nisso, nos modificadores ou na largada da IA (`ia_rival.json`)? Rode `tools/simular_derrubada.gd` e confira os alvos com status médios (capacete perto de 50–55%, 30% e 2%).
- **Demos e capturas:** `tests/fluxo/modo_demo.tscn` com as variáveis `TM_TELA`, `TM_ABA`, `TM_TORNEIO` e outras, listadas no topo de `modo_demo.gd`, mais `driver.sh shot` para gerar o PNG.
- **Nuvem só com o save real:** com o save fora de `ServicoJogador.SAVE_PADRAO` (teste, demo, ferramenta), a Nuvem real fica sem rede (`ServicoNuvem.isolado()`). Um personagem de teste já subiu pela sessão anônima do aparelho e voltou como save do jogador. Não abra `principal.tscn` com o save real sem querer falar com o Supabase.
- **Testes nunca tocam o `user://` real:** todo teste que usa um autoload (Nuvem, Metricas, Jogador) troca antes os caminhos (`caminho_save`, `caminho_sessao`, `caminho_cache_balanceamento`, `caminho_fila`) para uma pasta `user://teste_*`. Já aconteceu: `entrar()` baixou um balanceamento falso para o cache real e o jogo quebrou ao abrir (`folego_cavalo`).
- **Desempenho:** `tools/benchmark.tscn`. **Economia:** `tools/simular_economia.gd`. Rode a simulação de novo se mexer em `economia.json`.

## Nunca
- Colocar texto ou número de balanceamento fixo no código.
- Dar à regra da justa dependência de cena, nó ou tempo real.
- Escrever economia ou ranking pelo cliente (a partir da Parte 3, sempre Edge Function + RLS).
