#!/usr/bin/env bash
# Arms a session action from the lock screen, and reports what is armed.
#
# The lock screen never acts on a click. Clicking only writes an intent;
# scripts/lock.sh carries it out after hyprlock exits cleanly, which only
# happens once the password has been accepted. Someone walking past a
# locked machine can press these all they like and nothing happens.
set -u

STATE="${XDG_RUNTIME_DIR:-/tmp}/nothing-lock-action"

# A single '#': the doubled form is hyprlang's escape inside the config
# file, and this output is handed straight to pango at runtime.
RED='#d71921'
DIM='#8a8a8a'
FAINT='#454545'

armed() { cat "$STATE" 2>/dev/null || true; }

glyph() {
    case "$1" in
        logout)   printf '\U000F0343' ;;   # mdi-logout
        reboot)   printf '\U000F0709' ;;   # mdi-restart
        shutdown) printf '\U000F0425' ;;   # mdi-power
    esac
}

case "${1:-}" in
    toggle)
        want="${2:-}"
        [ -n "$want" ] || exit 0

        # A press delivered twice would toggle twice and look like a
        # button that never disarms. Ignore a repeat within 300 ms.
        GUARD="$STATE.guard"
        now=$(date +%s%3N)
        last=$(cat "$GUARD" 2>/dev/null || echo 0)
        printf '%s' "$now" > "$GUARD"
        [ $((now - last)) -lt 300 ] && exit 0

        if [ "$(armed)" = "$want" ]; then
            rm -f "$STATE"
        else
            printf '%s' "$want" > "$STATE"
        fi
        ;;
    icon)
        what="${2:-}"
        # Padded: these glyphs carry a wide advance, and without the
        # spaces hyprlock measured the label short and clipped the icon.
        if [ "$(armed)" = "$what" ]; then
            printf '<span foreground="%s"> %s </span>' "$RED" "$(glyph "$what")"
        else
            printf '<span foreground="%s"> %s </span>' "$DIM" "$(glyph "$what")"
        fi
        ;;
    status)
        # Always says something: the whole point of these buttons is that
        # they defer, and a silent row of icons would not say so.
        case "$(armed)" in
            logout)   printf '<span foreground="%s">LOG OUT AFTER UNLOCK</span>' "$RED" ;;
            reboot)   printf '<span foreground="%s">RESTART AFTER UNLOCK</span>' "$RED" ;;
            shutdown) printf '<span foreground="%s">SHUT DOWN AFTER UNLOCK</span>' "$RED" ;;
            *)        printf '<span foreground="%s">PASSWORD REQUIRED</span>' "$FAINT" ;;
        esac
        ;;
    read)
        armed
        ;;
    clear)
        rm -f "$STATE" "$STATE.guard"
        ;;
esac
