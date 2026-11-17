#!/usr/bin/env bash
# Pulls this checkout's current branch (fast-forward only - never a merge
# commit, never touches history you made) then hands off to
# update-nothing.sh to apply the new files. Meant to be run from the
# Settings panel's Update button: no prompts, one line a human reads.
#
#   scripts/self-update.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || { echo "Could not find the checkout"; exit 1; }

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
    echo "Not on a branch - pull it yourself: cd $ROOT && git pull"
    exit 1
fi

if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    echo "This checkout has uncommitted changes - commit or stash them first: cd $ROOT"
    exit 1
fi

before="$(git rev-parse HEAD)"
if ! git pull --ff-only >/dev/null 2>&1; then
    echo "Could not fast-forward - pull by hand: cd $ROOT && git pull"
    exit 1
fi

if [[ "$(git rev-parse HEAD)" == "$before" ]]; then
    echo "Already up to date."
    exit 0
fi

exec "$ROOT/scripts/update-nothing.sh" --yes
