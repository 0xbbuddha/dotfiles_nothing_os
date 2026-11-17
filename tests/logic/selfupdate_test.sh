#!/usr/bin/env bash
# Tests check-update.sh's behind-detection and self-update.sh's
# fast-forward pull against a throwaway local git remote - no network,
# no touching this checkout.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../../scripts"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git init -q --bare "$WORK/remote.git"
git clone -q "$WORK/remote.git" "$WORK/repo1"
cd "$WORK/repo1"
git config user.email t@t
git config user.name t
git checkout -q -b main
echo a > f.txt
mkdir -p scripts
cp "$SCRIPTS/check-update.sh" "$SCRIPTS/self-update.sh" scripts/
git add -A
git commit -q -m init
git push -q -u origin main

git clone -q "$WORK/remote.git" "$WORK/repo2"

out="$(cd "$WORK/repo2" && bash scripts/check-update.sh)"
[[ "$out" == "up-to-date" ]] || { echo "FAIL: expected up-to-date, got: $out"; exit 1; }

cd "$WORK/repo1"
echo b >> f.txt
git commit -q -am "second commit"
git push -q

out="$(cd "$WORK/repo2" && bash scripts/check-update.sh)"
[[ "$out" =~ ^behind\ 1\ [0-9a-f]+\ second\ commit$ ]] \
    || { echo "FAIL: expected 'behind 1 <sha> second commit', got: $out"; exit 1; }

before="$(git -C "$WORK/repo2" rev-parse HEAD)"
(cd "$WORK/repo2" && bash scripts/self-update.sh >/dev/null 2>&1) || true
after="$(git -C "$WORK/repo2" rev-parse HEAD)"
[[ "$before" != "$after" ]] || { echo "FAIL: self-update.sh did not fast-forward"; exit 1; }

echo "selfupdate: 3 checks passed"
