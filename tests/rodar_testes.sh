#!/usr/bin/env bash
# Roda todos os testes headless (tests/**/*_check.gd) e resume.
# Uso, da raiz do projeto: bash tests/rodar_testes.sh
# Cada script deve imprimir linhas "... OK"/"... FALHOU" e sair com 0 se passou.
set -uo pipefail
cd "$(dirname "$0")/.."
D=.claude/skills/run-torneio-medieval/driver.sh
bash $D import >/dev/null 2>&1 || { echo "IMPORT FALHOU"; exit 1; }
falhas=0
for f in $(find tests -name '*_check.gd' | sort); do
  saida="$(timeout 120 bash $D script "res://$f" 2>&1)"; cod=$?
  if [ $cod -eq 0 ]; then
    echo "PASSOU  $f ($(grep -c ' OK$' <<<"$saida") checagens)"
  else
    falhas=$((falhas+1))
    echo "FALHOU  $f (código $cod)"
    grep -E "FALHOU|SCRIPT ERROR|Parse Error|ERROR:" <<<"$saida" | grep -v "Unreferenced static" | head -20 | sed 's/^/    /'
  fi
done
# Regra em TypeScript (servidor): mesmos casos de tests/shared/, Node 24 roda .ts direto.
if command -v node >/dev/null 2>&1; then
  saida_ts="$(cd supabase && timeout 120 node --test "tests/regra/*.test.ts" 2>&1)"; cod_ts=$?
  if [ $cod_ts -eq 0 ]; then
    echo "PASSOU  supabase/tests/regra ($(grep -E '^ℹ pass' <<<"$saida_ts" | grep -oE '[0-9]+') checagens, TypeScript)"
  else
    falhas=$((falhas+1)); echo "FALHOU  supabase/tests/regra (TypeScript)"
    grep -E "✖|AssertionError|Error" <<<"$saida_ts" | head -20 | sed 's/^/    /'
  fi
else
  echo "AVISO   node nao encontrado: testes TypeScript do servidor nao rodaram"
fi
[ $falhas -eq 0 ] && echo "TODOS OS TESTES PASSARAM" || echo "$falhas ARQUIVO(S) COM FALHA"
exit $falhas
