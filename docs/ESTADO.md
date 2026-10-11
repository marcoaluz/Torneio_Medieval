# Estado atual

**Parte 1 — Protótipo · prompt 1.1 (Cena da arena): concluído.** Próximo: 1.2.

## Concluído
- Estrutura de pastas, `project.godot` (960×540, Compatibility, nearest, snap de pixel, landscape), `icon.svg`, `.gitignore`, `.gitattributes`.
- `CLAUDE.md` com regras fixas e a seção Continuidade entre sessões.
- `docs/DECISOES.md`, `docs/SESSOES.md`; skills `passagem` e `retomar` em `.claude/skills/`.
- Git inicializado.
- Pacote de Prompts movido para `docs/PACOTE_DE_PROMPTS.md`.

## Funcionando e testado
- **Arena (1.1):** `game/scenes/arena/arena.tscn` é a cena principal. Vista lateral elevada; a cerca fica em y≈236–292, o rival na pista de cima (pés y=270, `escala` 0.85, espelhado, indo para a esquerda) e o jogador na de baixo (pés y=470, indo para a direita). Ordem de desenho: Fundo (céu, arquibancada, chão), Rival, Cerca, Jogador. Os marcadores `Pistas/{Jogador,Rival}/{Inicio,Fim}` ficam em x 90↔870. O cenário vai de x −160 a 1120 (1280 de largura) e os limites da câmera são iguais.
- **Cavaleiro:** `game/scenes/arena/cavaleiro.tscn` + `game/scripts/presentation/cavaleiro.gd`, quadro 160×160 com origem no chão. Encaixes para sprites: `Visual/Cavalo`, `Visual/Cavalo/Manta`, `Visual/Cavaleiro/{Peito,Capacete,Escudo}` (também os alvos da mira, via `ponto_alvo()`) e `Visual/Lanca`. O `Brasao` desfaz o espelho e nunca sai invertido. Os retângulos provisórios usam `RetanguloProvisorio`, `ArquibancadaProvisoria` e `CercaProvisoria` (`game/scripts/presentation/provisorio/`); para trocar a arte, basta apagar esses nós e pôr o Sprite2D no encaixe.
- **Câmera:** `CameraArena` (`camera_arena.gd`) com `plano_aberto()`, `seguir(alvo)` e `focar(ponto, zoom)`, sinal `plano_mudou`, zoom 1/2/3 e transição exponencial (`rapidez`). Os ajustes visuais são `@export` na cena; não há número de jogo.
- Testes: `tests/arena/arena_check.gd` passa 13/13 (pontas, espelho, escala, brasão, ordem de desenho, três planos). As capturas de `tests/arena/arena_camera_demo.tscn` (`TM_CAMERA=aberto|seguir|focar`) e a do 20:9 foram conferidas no PNG.
- Traduções: `game/i18n/textos.csv` registrado no `project.godot`; `tests/smoke/headless_check.gd` confere a chave `JOGO_TITULO` em pt_BR e en (passa).
- Proporções: `SIZE=1600x720 driver.sh shot` (20:9) dá viewport 1200×540 sem corte; 16:9 dá 960×540. Toque injetado chega certo nos dois.
- Skill `run-torneio-medieval` (`.claude/skills/run-torneio-medieval/`): `driver.sh import | script | shot`, todos rodados e verificados nesta máquina. `shot` gerou PNG conferido visualmente (borda, cerca, toque injetado). Cena de fumaça em `tests/smoke/`.
- Plugin GodotPrompter 1.15.0 instalado (escopo usuário, só nesta conta). Hook de SessionStart auditado: local, sem rede; oferece uma vez adicionar seção `## GodotPrompter` ao CLAUDE.md (só com concordância). Skills do plugin só aparecem a partir da próxima sessão.
- `Godot_v4.7.2 --headless --path . --import` abre e importa o projeto sem erros (exit 0). Ainda não há cena principal, então nada foi executado visualmente nem testado em celular.

## Pendências / bugs
- Seção `## GodotPrompter` adicionada ao CLAUDE.md (aceita pelo usuário em 2026-10-11).
- GDD agora em `docs/GDD.md` (renomeado do arquivo exportado). Conferido contra a estrutura: sem divergências; pastas, tamanhos de sprite (justa 128-160 px, Equipamentos ~256 px) e 960×540 batem.
- Pendências abertas do próprio GDD (seção Plano de produção e pendências): nome do jogo e do protagonista, enredo, planilha de economia (será a 3.12), mecânica da mêlée, quantidade de formas/símbolos/cores do editor de brasão, divisão PixelLab × Claude Code, lista de habilidades especiais do lançamento.
- Pastas vazias têm `.gitkeep`; remover conforme forem ocupadas.
- Skills do projeto criadas em `.claude/skills/`: `estilo-arte`, `som`, `balanceamento`, `regra-da-justa`, `supabase-jogo` (referência, sem benchmark; valores marcados com (*) em `som` e convenções de nomes em `estilo-arte` são propostas minhas). O skill-creator usado foi o que já vem disponível na conta; o plugin `skill-creator@claude-plugins-official` não foi instalado.
- O script de simulação citado em `balanceamento` e os testes compartilhados citados em `regra-da-justa` ainda não existem (nascem em 3.12 e 1.5).

- Rival em escala 0.85 (não inteira): com sprites de verdade, os pixels do rival podem ficar irregulares. Se incomodar, gerar o rival já no tamanho final ou usar 0.875 (140/160).
- Os escudos dos dois estão do mesmo lado do desenho, porque o GDD pede só espelhar. Na justa real, o escudo fica do lado da cerca; rever no polimento.
- Os cavaleiros ainda não se movem na arena (o movimento só existe no demo de teste); a corrida entra no 1.2/1.3.

## Próximo passo
Prompt 1.2 do Pacote (Fases da passada), Opus 5.5, medium: máquina de estados Apresentação → Largada → Corrida → Mira → Impacto, com durações em `game/data/balance/` (arquivo versionado), 3 passadas e uma passada extra no empate, e um sinal por fase. A câmera usa `CameraArena`: aberto (Apresentação/Largada), `seguir(jogador)` (Corrida), `focar(rival.ponto_alvo(...))` (Mira/Impacto). Os cavaleiros saem dos marcadores `Inicio` para os `Fim`. Validar com `arena_check.gd` e `driver.sh shot`.
