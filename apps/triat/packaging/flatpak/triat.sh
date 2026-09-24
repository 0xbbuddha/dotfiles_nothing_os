#!/bin/sh
# Lanceur Flatpak de Triat.
set -eu
export PYTHONPATH="/app/share/triat:${PYTHONPATH:-}"
# Pas d'écriture de .pyc dans un préfixe en lecture seule.
export PYTHONDONTWRITEBYTECODE=1
exec python3 -m triat "$@"
