#!/usr/bin/env bash
# Captura todos os menus da vila em 16:9 e 20:9.  Uso: bash tools/capturar_menus.sh <pasta>
# (ex.: build/capturas_menus/antes). Precisa de janela (não roda headless).
set -euo pipefail
GODOT="${GODOT:-/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe}"
cd "$(dirname "$0")/.."
saida="${1:-build/capturas_menus/depois}"
trap 'rm -f override.cfg' EXIT
for tam in 1920x1080 2400x1080; do
  printf '[display]\n\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\n' "${tam%x*}" "${tam#*x}" > override.cfg
  TM_SAIDA="$saida" "$GODOT" --path . --rendering-driver opengl3 --resolution "$tam" res://tools/capturar_menus.tscn 2>&1 | grep -E "CAPTURAS|SCRIPT ERROR" || true
done
