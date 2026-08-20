#!/usr/bin/env bash
# Back-compat name; copies live in install-config.sh.
exec "$(cd "$(dirname "$0")" && pwd)/install-config.sh" "$@"
