# Estado atual

**Parte 1 — Protótipo · prompt 1.0 (Estrutura do projeto): concluído, com uma pendência (GDD).**

## Concluído
- Estrutura de pastas, `project.godot` (960×540, Compatibility, nearest, snap de pixel, landscape), `icon.svg`, `.gitignore`, `.gitattributes`.
- `CLAUDE.md` com regras fixas e a seção Continuidade entre sessões.
- `docs/DECISOES.md`, `docs/SESSOES.md`; skills `passagem` e `retomar` em `.claude/skills/`.
- Git inicializado.
- Pacote de Prompts movido para `docs/PACOTE_DE_PROMPTS.md`.

## Funcionando e testado
- `Godot_v4.7.2 --headless --path . --import` abre e importa o projeto sem erros (exit 0). Ainda não há cena principal, então nada foi executado visualmente nem testado em celular.

## Pendências / bugs
- **`docs/GDD.md` ainda não existe (conferido de novo no fim da sessão; só há `DEEP_IRON_GDD.docx` na Desktop, que é de outro projeto).** O usuário deve exportar o Documento de Design em Markdown (download do próprio doc) e salvar nesse caminho. Os prompts 1.1 em diante dependem dele.
- Pastas vazias têm `.gitkeep`; remover conforme forem ocupadas.
- Traduções ainda não registradas no `project.godot` (criar `game/i18n/` CSV no primeiro prompt que tiver texto, 1.2 ou 1.7).
- Não instaladas ainda: skills de terceiros (GodotPrompter, skill-creator) e as skills do projeto `estilo-arte`, `som`, `balanceamento`, `regra-da-justa`, `supabase-jogo`.

## Próximo passo
1. Colocar `docs/GDD.md` no lugar (Markdown exportado do doc "Torneio Medieval — Documento de Design" no claude.ai, ou me dizer onde está para copiar).
2. Na próxima sessão: ler o GDD inteiro e conferir se a estrutura de pastas bate com ele (espaços de equipamento, prédios, regiões do PvE); ajustar o que divergir, commitar.
3. Rodar `/run-skill-generator` uma vez (Godot em `D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe`).
4. Prompt 1.1 do Pacote (Cena da arena), Opus 5.5, medium. Resolução base 960×540.
