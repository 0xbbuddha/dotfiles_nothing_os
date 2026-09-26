#!/usr/bin/env bash
# Lance Musicapp depuis le venv du projet.
set -euo pipefail
cd "$(dirname "$0")"
exec .venv/bin/python -m triat "$@"
