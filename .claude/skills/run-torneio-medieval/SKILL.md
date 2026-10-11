---
name: run-torneio-medieval
description: Roda, valida, testa e tira screenshot do jogo Torneio Medieval (Godot 4.7). Use para "rodar o jogo", "abrir a cena X", "capturar tela", "rodar os testes da regra da justa" ou confirmar que uma mudança funciona no app real.
---

# Rodar o Torneio Medieval

Jogo Godot 4.7.2 (GDScript), 2D, 960×540, renderer Compatibility. O Godot **não está no PATH**: o driver usa `D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe` (ou a variável `GODOT`). Todos os caminhos abaixo são relativos à raiz do projeto, e os comandos rodam no Git Bash (o mesmo que a ferramenta Bash do Claude Code usa no Windows).

## Caminho do agente: o driver

`.claude/skills/run-torneio-medieval/driver.sh`

```bash
D=.claude/skills/run-torneio-medieval/driver.sh

bash $D import                                   # importa e valida o projeto (headless)
bash $D script res://tests/smoke/headless_check.gd   # roda script de teste (headless)
bash $D shot res://tests/smoke/smoke.tscn 10 /tmp/out/smoke.png   # renderiza e salva PNG
SIZE=1600x720 bash $D shot res://tests/smoke/smoke.tscn 10 /tmp/out/s209.png   # mesma coisa em 20:9

# Todos os testes headless de uma vez (resumo PASSOU/FALHOU por arquivo)
bash tests/rodar_testes.sh

# Arena (prompt 1.1)
timeout 60 bash $D script res://tests/arena/arena_check.gd    # montagem + 3 planos da câmera; espera "ARENA TUDO OK"
TM_CAMERA=seguir bash $D shot res://tests/arena/arena_camera_demo.tscn 60 /tmp/out/seguir.png  # aberto | seguir | focar
bash $D shot res://tests/arena/justa_robo_demo.tscn 170 /tmp/out/corrida.png   # justa com robô tocando (log ROBO)
```

- `import`: termina com exit 0 se o projeto abre. Cria `.godot/` (ignorado pelo git) e os `.import` dos assets (esses entram no git).
- `script <res://x.gd>`: o script precisa `extends SceneTree`, fazer o trabalho em `_init()` e chamar `quit(codigo)`. É o caminho para testes da regra pura da justa (sem cena). Saída de teste: `print("... OK")` e exit code.
- `shot [cena] [quadros] [png]`: roda a cena de verdade (janela real, GPU) com o Movie Maker do Godot, grava os quadros e copia o último para o PNG pedido. Padrão: `smoke.tscn`, 10 quadros, `$TMPDIR/tm_shot.png`. **Olhe o PNG** (Read na imagem) para confirmar.
- `SIZE=LxA`: abre a janela nesse tamanho via `override.cfg` temporário (apagado no fim; o driver recusa rodar se já existir um). Use para testar proporções: 1600x720 (20:9) deve dar `SMOKE viewport=1200x540`.
- Cena de fumaça `tests/smoke/smoke.tscn`: imprime `SMOKE viewport=960x540`, `SMOKE window=... screen=...`, `SMOKE renderer=gl_compatibility`, `SMOKE filter=0` e injeta um toque em (480,270) que volta como `SMOKE touch=480,270`. Se algum print sumir ou mudar, a configuração de exibição ou a entrada quebrou.

Para tocar na tela de uma cena nova, injete eventos com `get_viewport().push_input(evento, true)` (coordenadas do viewport), como o `smoke.gd` faz, e imprima o resultado com um prefixo fácil de filtrar (`| grep PREFIXO`).

## Caminho humano

Abra a pasta do projeto no editor do Godot e use F5/F6. Inútil para agente: abre janela e espera.

## Gotchas

- O PNG do `shot` sai em **1280×720**, não 960×540: o `project.godot` tem `window_width_override=1280`/`height=720` para facilitar o teste no desktop, e `--resolution` não muda o tamanho do filme. O viewport lógico continua 960×540 (o smoke imprime isso). A escala 1,33× não é inteira, então bordas de 1 px podem aparecer com espessuras diferentes na captura; não é bug.
- `shot` abre uma janela de verdade por 1 a 2 segundos na tela do usuário. Não funciona com `--headless` (sem renderização).
- `Input.parse_input_event` usa coordenadas da **janela**: em 20:9 o toque em (480,270) chegou como (244,137). Use `get_viewport().push_input(ev, true)` para coordenadas do viewport.
- `--resolution` não muda o tamanho da janela (o `window_width_override` do projeto vence); por isso o `SIZE` usa `override.cfg`.
- Janela maior que o monitor é cortada pelo Windows (2400x1080 virou 2400x1061 num monitor 2560x1080, viewport 1221x540 e captura deslocada). Use tamanhos que caibam na tela: 1600x720 para 20:9.
- Com `aspect=expand` e sem câmera, a sobra de largura aparece à **direita** (origem no canto superior esquerdo). Com `Camera2D`, a sobra se divide pelos dois lados.
- `--quit-after N` conta quadros, não segundos. Com `--fixed-fps 30`, 10 quadros ≈ 0,3 s de jogo.
- O Movie Maker também grava um `.wav` ao lado; o driver apaga a pasta temporária.
- Cena de teste em `res://` obrigatoriamente: o Godot não carrega `.tscn` fora do projeto.
- Cena principal: `res://game/scenes/arena/arena.tscn` (prompt 1.1). Mesmo assim passe a cena explicitamente no `shot`.
- **Erro de script em teste headless trava o Godot** (imprime `SCRIPT ERROR` e não chama `quit`). Rode com `timeout 60 bash $D script ...` e não filtre a saída com `grep` sem timeout, senão parece que não saiu nada.
- Em script `extends SceneTree`, o `_ready` de uma cena adicionada em `_initialize()` só roda depois de `await process_frame`.
- O mesmo vale para os autoloads (`Jogador`): o `_ready` deles roda depois do `_initialize`. Dê `await process_frame` antes de trocar `Jogador.caminho_save`/`estado`, senão o `_ready` recria o estado por cima. Teste que salva usa uma pasta própria em `user://teste_*/` (nunca o save real).
- O heredoc do Bash às vezes estraga barras invertidas e aspas (`\p` virou `\p`; comandos com `'''` falharam no parse). Para arquivos com regex, CSV com aspas ou muito texto, use a ferramenta Write e só rode pelo shell.

## Troubleshooting

Só erros vistos até agora: nenhum. Primeira execução do `import` num clone novo leva alguns segundos a mais (cria `.godot/`).
