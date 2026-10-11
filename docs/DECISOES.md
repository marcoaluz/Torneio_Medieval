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
- **2026-10-11 · Plugin GodotPrompter instalado por conta (escopo usuário).** Skills de plugin não ficam no repositório; cada conta roda os dois comandos de instalação. Conteúdo auditado antes (hook local, sem rede). Motivo: um só pacote Godot, como o Pacote recomenda.
- **2026-10-11 · Validação visual por Movie Maker do Godot** (`--write-movie`), via `driver.sh shot`: janela real, sem depender de xvfb/Playwright (Windows). PNG sai em 1280×720 por causa de `window_width_override`.
- **2026-10-11 · Convenções de arte e som propostas** nas skills `estilo-arte` e `som`: nomes em minúsculas com sublinhado, variações `_01`, estágios de dano `_d1.._d3`, OGG (WAV só para sons curtíssimos de interface), barramentos Master/Musica/SFX/Voz/Ambiente/UI, pico de efeitos −3 dBFS e música ≈ −14 LUFS. O Pacote não fixava esses valores; mude nas skills e aqui se discordar.
- **2026-10-11 · Fundo da arena em 960×540** (não 640×360 como no prompt A5 do Pacote), refletido em `estilo-arte`.
- **2026-10-11 · Traduções em CSV** (`game/i18n/textos.csv`, colunas `keys,pt_BR,en`, chaves em MAIÚSCULAS). O Godot 4.7 gera `textos.<idioma>.translation` ao lado do CSV; esses arquivos são versionados (saíram do `.gitignore`). pt_BR é o idioma de reserva.
- **2026-10-11 · Proporções de tela:** com `aspect=expand`, a altura lógica fica 540 e a largura cresce (16:9 → 960, 20:9 → 1200, 21:9 → ~1260). Testado em 16:9 e 20:9 (1600×720 → viewport 1200×540, nada cortado). Consequência: o essencial fica em 960×540, e fundos/cenários vão até 1280 de largura (substitui o 960×540 do fundo da arena registrado antes).
- **2026-10-11 · Câmera da justa: uma Camera2D com três planos e decaimento exponencial** (`CameraArena`). Descartados: Tween (difícil redirecionar com alvo em movimento) e o addon Phantom Camera (dependência extra). Zoom: aberto 1, seguir 2, foco 3.
- **2026-10-11 · Ajustes visuais (zoom da câmera, escala do rival 0.85, posições das pistas) ficam como `@export`/marcadores nas cenas**, não em `game/data/balance/`. Motivo: são apresentação, não regra de jogo. Velocidades e durações de jogo vão para os dados (1.2+).
- **2026-10-11 · Arte provisória desenhada por scripts `@tool` (`_draw`) dentro de nós-encaixe**, em vez de ColorRect. Motivo: ColorRect é Control e pode engolir toques; os encaixes já têm os nomes das camadas finais.
- **2026-10-11 · O brasão desfaz o espelhamento** (`Brasao.scale.x = direcao`), conforme o GDD; há um teste que confere isso.
- **2026-10-11 · Fases da justa: FSM por enum, pura, em `rules/` (`JustaFases`)**, que avança por `avancar(ms)` e devolve uma lista de eventos com instante exato. O nó `ControladorJusta` traduz em sinais, câmera e movimento. Descartada a FSM com um nó por estado: não cabe em `rules/` (sem nós) nem porta para TypeScript, e são só 5 fases com tempo fixo.
- **2026-10-11 · Tempos da regra em milissegundos inteiros**, para dar paridade exata com o TypeScript; o resultado não depende do tamanho do quadro (testado picando em 17 ms).
- **2026-10-11 · Passada extra:** até `passadas_extras_max` (1); se ainda empatar, a justa termina empatada. Derrubada encerra a justa no fim da passada, mesmo com placar contrário. Pendente de confirmação de design.
- **2026-10-11 · Câmera lenta da Mira é só visual** (os cavaleiros andam a 0.3 da velocidade); o tempo de jogo da Mira continua 2 s reais.
- **2026-10-11 · Entrada por toque:** `emulate_touch_from_mouse=true`; o jogo só trata eventos de toque, e o mouse do desktop vira toque.
- **2026-10-11 · Pedido do usuário: executar todos os prompts do Pacote em sequência**, parando só antes de gasto de crédito ou serviço externo.
