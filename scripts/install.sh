#!/usr/bin/env bash
# Back-compat: the public entry is now ./install at the repo root.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/install" "$@"
