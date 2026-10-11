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

## Nunca
- Colocar texto ou número de balanceamento fixo no código.
- Dar à regra da justa dependência de cena, nó ou tempo real.
- Escrever economia ou ranking pelo cliente (a partir da Parte 3, sempre Edge Function + RLS).
