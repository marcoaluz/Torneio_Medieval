# Decisões técnicas

Formato: data · decisão · motivo.

- **2026-10-11 · Motor: Godot 4.7.2, GDScript.** Versão instalada em `D:\DEV\Godot`. Pacote de Prompts prevê Godot 4.
- **2026-10-11 · Renderer Compatibility (OpenGL).** Melhor compatibilidade e desempenho em celular Android de entrada; o jogo é 2D.
- **2026-10-11 · Resolução base 960×540**, stretch `canvas_items`, aspect `expand`. Motivo: arte detalhada (retrato de Equipamentos com 256 px ocuparia mais de 70% da altura em 360); 960×540 dobra certinho em 1080p. Substitui a ideia inicial de 640×360. Consequência: fundo da arena (A5 do Pacote) deve ser gerado em 960×540 (ou 640×360 só se ampliado 1,5×, o que não é inteiro; preferir 960×540).
- **2026-10-11 · Pixel art:** filtro de textura nearest, snap de transformações e vértices ao pixel.
- **2026-10-11 · Orientação landscape** fixa.
- **2026-10-11 · Estrutura: código e assets em `game/`**, testes em `tests/`, docs em `docs/`, na raiz só `project.godot`, `icon.svg`, `CLAUDE.md`.
- **2026-10-11 · Regra da justa em `game/scripts/rules/`**, módulo puro e determinístico; casos de teste em `tests/shared/` para GDScript e TypeScript (Parte 3).
- **2026-10-11 · Godot fora do PATH:** o caminho completo fica registrado no `CLAUDE.md`, sem alterar o PATH do Windows.
