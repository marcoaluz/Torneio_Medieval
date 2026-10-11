#!/usr/bin/env bash
# Driver do Torneio Medieval: importar, rodar scripts headless, capturar tela.
# Uso (a partir da raiz do projeto):
#   driver.sh import                       importa/valida o projeto (headless)
#   driver.sh script res://tests/x.gd      roda um script de teste (headless, extends SceneTree)
#   driver.sh shot [cena] [quadros] [png]  renderiza a cena e salva o ultimo quadro em PNG
# Godot: variavel GODOT ou o caminho padrao desta maquina.
set -euo pipefail
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
cd "$(dirname "$0")/../../.."
cmd="${1:-}"; shift || true
case "$cmd" in
  import)
    "$GODOT" --headless --path . --import ;;
  script)
    "$GODOT" --headless --path . -s "${1:?informe res://...gd}" ;;
  shot)
    scene="${1:-res://tests/smoke/smoke.tscn}"
    frames="${2:-10}"
    out="${3:-${TMPDIR:-/tmp}/tm_shot.png}"
    tmp="$(mktemp -d)"
    "$GODOT" --path . --rendering-driver opengl3 --resolution 960x540 \
      --write-movie "$tmp/f.png" --fixed-fps 30 --quit-after "$frames" "$scene"
    last="$(ls "$tmp"/f0*.png | sort | tail -1)"
    cp "$last" "$out"
    rm -rf "$tmp"
    echo "SHOT $out" ;;
  *)
    echo "uso: driver.sh import | script <res://x.gd> | shot [cena] [quadros] [png]"; exit 2 ;;
esac
