# Estado atual

**Parte 1 — Protótipo · prompt 1.0 (Estrutura do projeto): concluído.**

## Concluído
- Estrutura de pastas, `project.godot` (960×540, Compatibility, nearest, snap de pixel, landscape), `icon.svg`, `.gitignore`, `.gitattributes`.
- `CLAUDE.md` com regras fixas e a seção Continuidade entre sessões.
- `docs/DECISOES.md`, `docs/SESSOES.md`; skills `passagem` e `retomar` em `.claude/skills/`.
- Git inicializado.
- Pacote de Prompts movido para `docs/PACOTE_DE_PROMPTS.md`.

## Funcionando e testado
- `Godot_v4.7.2 --headless --path . --import` abre e importa o projeto sem erros (exit 0). Ainda não há cena principal, então nada foi executado visualmente nem testado em celular.

## Pendências / bugs
- GDD agora em `docs/GDD.md` (renomeado do arquivo exportado). Conferido contra a estrutura: sem divergências; pastas, tamanhos de sprite (justa 128-160 px, Equipamentos ~256 px) e 960×540 batem.
- Pendências abertas do próprio GDD (seção Plano de produção e pendências): nome do jogo e do protagonista, enredo, planilha de economia (será a 3.12), mecânica da mêlée, quantidade de formas/símbolos/cores do editor de brasão, divisão PixelLab × Claude Code, lista de habilidades especiais do lançamento.
- Pastas vazias têm `.gitkeep`; remover conforme forem ocupadas.
- Traduções ainda não registradas no `project.godot` (criar `game/i18n/` CSV no primeiro prompt que tiver texto, 1.2 ou 1.7).
- Não instaladas ainda: skills de terceiros (GodotPrompter, skill-creator) e as skills do projeto `estilo-arte`, `som`, `balanceamento`, `regra-da-justa`, `supabase-jogo`.

## Próximo passo
1. Rodar `/run-skill-generator` uma vez (Godot em `D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe`).
2. Prompt 1.1 do Pacote (Cena da arena), Opus 5.5, medium. Resolução base 960×540. Ler antes a seção A justa do GDD.
