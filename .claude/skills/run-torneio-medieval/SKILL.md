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
```

- `import`: termina com exit 0 se o projeto abre. Cria `.godot/` (ignorado pelo git) e os `.import` dos assets (esses entram no git).
- `script <res://x.gd>`: o script precisa `extends SceneTree`, fazer o trabalho em `_init()` e chamar `quit(codigo)`. É o caminho para testes da regra pura da justa (sem cena). Saída de teste: `print("... OK")` e exit code.
- `shot [cena] [quadros] [png]`: roda a cena de verdade (janela real, GPU) com o Movie Maker do Godot, grava os quadros e copia o último para o PNG pedido. Padrão: `smoke.tscn`, 10 quadros, `$TMPDIR/tm_shot.png`. **Olhe o PNG** (Read na imagem) para confirmar.
- Cena de fumaça `tests/smoke/smoke.tscn`: imprime no log `SMOKE viewport=960x540`, `SMOKE renderer=gl_compatibility`, `SMOKE filter=0` e injeta um toque em (480,270) que volta como `SMOKE touch=480,270`. Se esses quatro prints sumirem, a configuração de exibição ou a entrada quebrou.

Para tocar na tela de uma cena nova, injete eventos no próprio script de teste da cena com `Input.parse_input_event(InputEventScreenTouch ...)`, como o `smoke.gd` faz, e imprima o resultado com um prefixo fácil de filtrar (`| grep PREFIXO`).

## Caminho humano

Abra a pasta do projeto no editor do Godot e use F5/F6. Inútil para agente: abre janela e espera.

## Gotchas

- O PNG do `shot` sai em **1280×720**, não 960×540: o `project.godot` tem `window_width_override=1280`/`height=720` para facilitar o teste no desktop, e `--resolution` não muda o tamanho do filme. O viewport lógico continua 960×540 (o smoke imprime isso). A escala 1,33× não é inteira, então bordas de 1 px podem aparecer com espessuras diferentes na captura; não é bug.
- `shot` abre uma janela de verdade por 1 a 2 segundos na tela do usuário. Não funciona com `--headless` (sem renderização).
- `--quit-after N` conta quadros, não segundos. Com `--fixed-fps 30`, 10 quadros ≈ 0,3 s de jogo.
- O Movie Maker também grava um `.wav` ao lado; o driver apaga a pasta temporária.
- Cena de teste em `res://` obrigatoriamente: o Godot não carrega `.tscn` fora do projeto.
- Ainda não existe cena principal (`run/main_scene` vazio): sempre passe a cena explicitamente até o prompt 1.1 criar a arena.

## Troubleshooting

Só erros vistos até agora: nenhum. Primeira execução do `import` num clone novo leva alguns segundos a mais (cria `.godot/`).
