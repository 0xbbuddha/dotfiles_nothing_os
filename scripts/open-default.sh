#!/usr/bin/env bash
# open-default.sh <category> <fallback command...>
# Opens the app chosen in Settings > Dock > Default apps for <category>
# (see mime-defaults.py), launched by the shell the way its launcher does;
# with none chosen, or no shell answering, runs the fallback instead.
# SUPER+W uses it with category "web", so the key follows that setting.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cat="$1"; shift
# Only a choice made by you (~/.config/mimeapps.list): the system-wide
# default would silently change what the key opened before.
id="$(python3 -I "$here/mime-defaults.py" get "$cat" --user 2>/dev/null)"
if [[ -n "$id" ]] && [[ "$(qs -p "$here/../quickshell/nothing" ipc call apps launch "$id" 2>/dev/null)" == ok ]]; then
    exit 0
fi
exec "$@"
