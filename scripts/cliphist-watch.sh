#!/usr/bin/env bash
# Relay wl-paste --watch → cliphist. The type (text|image) is passed as argument.
#
# Chromium/Helium copies sometimes arrive as UTF-16 (NUL between each
# letter). GTK and Qt stop at the first zero: paste looks empty.
# Convert them to UTF-8 before storing, and rewrite the current clipboard
# if needed. Images are left untouched (binary PNG).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kind="${1:-text}"

if [[ "$kind" == "text" ]]; then
    python3 -c '
import subprocess, sys
data = sys.stdin.buffer.read()
if b"\x00" in data:
    data = data.replace(b"\x00", b"")
    subprocess.run(["wl-copy", "--type", "text/plain"], input=data)
subprocess.run(["cliphist", "store"], input=data)
'
else
    cliphist store
fi

qs -p "$ROOT/quickshell/nothing" ipc call clipboard update >/dev/null 2>&1 || true
