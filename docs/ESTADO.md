# Estado atual

**Parte 1 — Protótipo · prompt 1.0 (Estrutura do projeto): concluído.**

## Concluído
- Estrutura de pastas, `project.godot` (960×540, Compatibility, nearest, snap de pixel, landscape), `icon.svg`, `.gitignore`, `.gitattributes`.
- `CLAUDE.md` com regras fixas e a seção Continuidade entre sessões.
- `docs/DECISOES.md`, `docs/SESSOES.md`; skills `passagem` e `retomar` em `.claude/skills/`.
- Git inicializado.
- Pacote de Prompts movido para `docs/PACOTE_DE_PROMPTS.md`.

## Funcionando e testado
- Traduções: `game/i18n/textos.csv` registrado no `project.godot`; `tests/smoke/headless_check.gd` confere a chave `JOGO_TITULO` em pt_BR e en (passa).
- Proporções: `SIZE=1600x720 driver.sh shot` (20:9) dá viewport 1200×540 sem corte; 16:9 dá 960×540. Toque injetado chega certo nos dois.
- Skill `run-torneio-medieval` (`.claude/skills/run-torneio-medieval/`): `driver.sh import | script | shot`, todos rodados e verificados nesta máquina. `shot` gerou PNG conferido visualmente (borda, cerca, toque injetado). Cena de fumaça em `tests/smoke/`.
- Plugin GodotPrompter 1.15.0 instalado (escopo usuário, só nesta conta). Hook de SessionStart auditado: local, sem rede; oferece uma vez adicionar seção `## GodotPrompter` ao CLAUDE.md (só com concordância). Skills do plugin só aparecem a partir da próxima sessão.
- `Godot_v4.7.2 --headless --path . --import` abre e importa o projeto sem erros (exit 0). Ainda não há cena principal, então nada foi executado visualmente nem testado em celular.

## Pendências / bugs
- GDD agora em `docs/GDD.md` (renomeado do arquivo exportado). Conferido contra a estrutura: sem divergências; pastas, tamanhos de sprite (justa 128-160 px, Equipamentos ~256 px) e 960×540 batem.
- Pendências abertas do próprio GDD (seção Plano de produção e pendências): nome do jogo e do protagonista, enredo, planilha de economia (será a 3.12), mecânica da mêlée, quantidade de formas/símbolos/cores do editor de brasão, divisão PixelLab × Claude Code, lista de habilidades especiais do lançamento.
- Pastas vazias têm `.gitkeep`; remover conforme forem ocupadas.
- Skills do projeto criadas em `.claude/skills/`: `estilo-arte`, `som`, `balanceamento`, `regra-da-justa`, `supabase-jogo` (referência, sem benchmark; valores marcados com (*) em `som` e convenções de nomes em `estilo-arte` são propostas minhas). O skill-creator usado foi o que já vem disponível na conta; o plugin `skill-creator@claude-plugins-official` não foi instalado.
- O script de simulação citado em `balanceamento` e os testes compartilhados citados em `regra-da-justa` ainda não existem (nascem em 3.12 e 1.5).

## Próximo passo
1. Abrir nova sessão (as skills `godot-prompter:*` só aparecem nela) e responder à oferta do plugin sobre o CLAUDE.md.
2. Nas outras contas: `claude plugins marketplace add jame581/skillsmith` e `claude plugins install godot-prompter@skillsmith`.
3. Prompt 1.1 do Pacote (Cena da arena), Opus 5.5, medium. Lembrar: área segura 960×540, cenário estendido até 1280 de largura, câmera `Camera2D` centralizada; textos via `game/i18n/textos.csv`. Validar com `driver.sh shot` em 16:9 e com `SIZE=1600x720`.
