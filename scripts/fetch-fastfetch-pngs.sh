#!/usr/bin/env bash
# Fastfetch logo is the user's Tamaki PNG (~/.config/fastfetch/pngs/tamaki.png).
# Do not download wiki portraits: they would overwrite that file.
set -euo pipefail
DEST="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/pngs}"
mkdir -p "$DEST"
if [[ -s "$DEST/tamaki.png" ]]; then
    echo "  fastfetch logo: $DEST/tamaki.png"
    exit 0
fi
echo "  no tamaki.png in $DEST (drop one there if you want a logo)"
