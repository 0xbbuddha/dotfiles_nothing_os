#!/usr/bin/env bash
# Mind: enrich an Essential Space entry.
#
# The vault calls this via `essential.py mind`. Default is a local stub
# (title + first lines). To use Gemini or Ollama, pick it in settings or:
#
#   echo 'BACKEND=gemini' >> ~/.config/nothing/mind.env
#   echo 'GEMINI_API_KEY=…' >> ~/.config/nothing/mind.env
#   echo 'MODEL=gemini-3.6-flash' >> ~/.config/nothing/mind.env
#
#   echo 'BACKEND=ollama' >> ~/.config/nothing/mind.env
#   echo 'MODEL=llama3.2' >> ~/.config/nothing/mind.env
#
# Drop a custom ~/.config/nothing/mind.sh to replace this entirely
# (stdin/argv stay the same: mind.sh <id> [backend]).
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
USER_HOOK="${HOME}/.config/nothing/mind.sh"
if [[ -x "$USER_HOOK" && "$USER_HOOK" != "$(readlink -f "${BASH_SOURCE[0]}")" ]]; then
    exec "$USER_HOOK" "$@"
fi
exec python3 "$ROOT/scripts/essential.py" mind "$@"
