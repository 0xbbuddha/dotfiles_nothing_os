#!/usr/bin/env bash
# Is this checkout behind its remote branch? One line, machine-readable:
#   up-to-date
#   behind <N> <short-sha> <summary of that commit>
#   error <message>
#
# Read-only: fetches (updates this repo's remote-tracking refs, same as
# any `git fetch`) but never touches the working tree.
#
#   scripts/check-update.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || { echo "error: could not find the checkout"; exit 0; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "error: not a git checkout"; exit 0; }

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
[[ -n "$branch" && "$branch" != "HEAD" ]] || { echo "error: not on a branch"; exit 0; }

remote="$(git config "branch.$branch.remote" 2>/dev/null)"
[[ -n "$remote" ]] || remote="origin"

ref="$remote/$branch"
if ! git fetch --quiet "$remote" "$branch" 2>/dev/null; then
    # origin is SSH, and this machine has no key for it set up - reading
    # (never pushing) needs none at all over HTTPS, so try that before
    # giving up.
    url="$(git remote get-url "$remote" 2>/dev/null)"
    https="${url/git@github.com:/https:\/\/github.com\/}"
    if [[ "$https" == "$url" ]] || ! git fetch --quiet "$https" "$branch" 2>/dev/null; then
        echo "error: could not reach $remote"
        exit 0
    fi
    ref="FETCH_HEAD"
fi

behind="$(git rev-list --count "HEAD..$ref" 2>/dev/null)"
if [[ -z "$behind" || "$behind" -eq 0 ]]; then
    echo "up-to-date"
else
    sha="$(git rev-parse --short "$ref")"
    summary="$(git log -1 --format=%s "$ref")"
    echo "behind $behind $sha $summary"
fi
