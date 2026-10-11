# Estado atual

**Parte 1 — Protótipo · prompt 1.0 (Estrutura do projeto): concluído.**

## Concluído
- Estrutura de pastas, `project.godot` (960×540, Compatibility, nearest, snap de pixel, landscape), `icon.svg`, `.gitignore`, `.gitattributes`.
- `CLAUDE.md` com regras fixas e a seção Continuidade entre sessões.
- `docs/DECISOES.md`, `docs/SESSOES.md`; skills `passagem` e `retomar` em `.claude/skills/`.
- Git inicializado.
- Pacote de Prompts movido para `docs/PACOTE_DE_PROMPTS.md`.

## Funcionando e testado
- Skill `run-torneio-medieval` (`.claude/skills/run-torneio-medieval/`): `driver.sh import | script | shot`, todos rodados e verificados nesta máquina. `shot` gerou PNG conferido visualmente (borda, cerca, toque injetado). Cena de fumaça em `tests/smoke/`.
- Plugin GodotPrompter 1.15.0 instalado (escopo usuário, só nesta conta). Hook de SessionStart auditado: local, sem rede; oferece uma vez adicionar seção `## GodotPrompter` ao CLAUDE.md (só com concordância). Skills do plugin só aparecem a partir da próxima sessão.
- `Godot_v4.7.2 --headless --path . --import` abre e importa o projeto sem erros (exit 0). Ainda não há cena principal, então nada foi executado visualmente nem testado em celular.

## Pendências / bugs
- GDD agora em `docs/GDD.md` (renomeado do arquivo exportado). Conferido contra a estrutura: sem divergências; pastas, tamanhos de sprite (justa 128-160 px, Equipamentos ~256 px) e 960×540 batem.
- Pendências abertas do próprio GDD (seção Plano de produção e pendências): nome do jogo e do protagonista, enredo, planilha de economia (será a 3.12), mecânica da mêlée, quantidade de formas/símbolos/cores do editor de brasão, divisão PixelLab × Claude Code, lista de habilidades especiais do lançamento.
- Pastas vazias têm `.gitkeep`; remover conforme forem ocupadas.
- Traduções ainda não registradas no `project.godot` (criar `game/i18n/` CSV no primeiro prompt que tiver texto, 1.2 ou 1.7).
- Não instaladas ainda: skill-creator (`/plugin install skill-creator@claude-plugins-official`) e as skills do projeto `estilo-arte`, `som`, `balanceamento`, `regra-da-justa`, `supabase-jogo`.

## Próximo passo
1. Na próxima sessão, confirmar que as skills `godot-prompter:*` aparecem e responder à oferta de adicionar a seção ao CLAUDE.md.
2. Em cada outra conta do Claude: rodar `claude plugins marketplace add jame581/skillsmith` e `claude plugins install godot-prompter@skillsmith` (plugin é por conta, não vai no git).
3. Prompt 1.1 do Pacote (Cena da arena), Opus 5.5, medium. Resolução base 960×540. Ler antes a seção A justa do `docs/GDD.md`. Ao terminar, validar com `driver.sh shot res://game/scenes/arena/<cena>.tscn`.
