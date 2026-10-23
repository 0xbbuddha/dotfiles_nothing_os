#!/usr/bin/env bash
# Kept for the instructions already given: the targeted copy it used to do
# could leave the shell half-updated when the installed rice was older than
# this checkout. update-nothing.sh compares every file instead.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/update-nothing.sh" "$@"
