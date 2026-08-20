#!/usr/bin/env bash
# Compile Quickshell shaders (dot field in settings).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRAG="$ROOT/quickshell/nothing/shaders/dotfield.frag"
OUT="$FRAG.qsb"

QSB=""
if [[ -x /usr/lib/qt6/bin/qsb ]]; then
    QSB=/usr/lib/qt6/bin/qsb
elif command -v qsb >/dev/null 2>&1; then
    QSB=qsb
else
    echo "qsb not found (pacman -S qt6-shadertools)" >&2
    exit 1
fi

"$QSB" --glsl 100es,120,150 --hlsl 50 --msl 12 -o "$OUT" "$FRAG"
echo "wrote $OUT"
