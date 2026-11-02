#!/usr/bin/env bash
# Tests the version-match extraction that apply-spicetify.sh uses to pick
# `spicetify apply` (versions match) vs `spicetify backup apply` (stale or
# unreadable backup). Mirrors the exact sed patterns at
# apply-spicetify.sh:251-254 - keep both in sync if that script changes.
set -euo pipefail

extract_backup_version() {
    sed -n 's/^version[[:space:]]*=[[:space:]]*//p' \
        <(sed -n '/^\[Backup\]/,$p' <<<"$1") | head -1
}
extract_live_version() {
    sed -n 's/^Spotify version \([^,]*\),.*/\1/p' <<<"$1"
}

CONF_MATCH=$'[Setting]\nfoo = bar\n[Backup]\nversion = 1.2.96.518\n[Other]\nx=1'
LIVE_MATCH='Spotify version 1.2.96.518, 64-bit unofficial'
bv="$(extract_backup_version "$CONF_MATCH")"
lv="$(extract_live_version "$LIVE_MATCH")"
[[ "$bv" == "1.2.96.518" ]] || { echo "FAIL: backup_version got '$bv'"; exit 1; }
[[ "$lv" == "1.2.96.518" ]] || { echo "FAIL: live_version got '$lv'"; exit 1; }
[[ "$bv" == "$lv" ]] || { echo "FAIL: matching versions should compare equal (picks plain apply)"; exit 1; }

CONF_STALE=$'[Backup]\nversion = 1.2.90.000'
LIVE_NEW='Spotify version 1.3.4.258.gc60b10b0946a, 64-bit unofficial'
bv2="$(extract_backup_version "$CONF_STALE")"
lv2="$(extract_live_version "$LIVE_NEW")"
[[ "$bv2" != "$lv2" ]] || { echo "FAIL: a stale backup must not compare equal to a newer live version (must pick backup apply)"; exit 1; }

echo "spicetify: version-match extraction picks apply vs backup-apply correctly"
