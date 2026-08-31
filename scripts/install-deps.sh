#!/usr/bin/env bash
# Arch / EndeavourOS dependencies for the Nothing session.
# Sourced by ./install, or run on its own:
#   ./scripts/install-deps.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC2034  # read by lib.sh when it is sourced
NOTHING_ROOT="$ROOT"
# shellcheck source=lib.sh
source "$ROOT/scripts/lib.sh"

# Set by ./install so the heading matches its plan; 1 when run on its own.
step "${NOTHING_STEP:-1}" "packages"

# Skip names that are not in the sync DB so one missing package
# does not abort the whole `pacman -S` line.
filter_sync() {
    local p out=()
    for p in "$@"; do
        if pacman -Si "$p" >/dev/null 2>&1; then
            out+=("$p")
        else
            warn "not in official repos, skipping: $p"
        fi
    done
    printf '%s\n' "${out[@]}"
}

need_root_denied

if ! have pacman; then
    die "pacman not found. This installer targets Arch Linux and EndeavourOS."
fi

# Refresh the databases. A full -Syu is opt-in: rice installers that
# upgrade the world tend to surprise people mid-session.
run sudo pacman -Sy --needed --noconfirm archlinux-keyring

PACMAN_PKGS=(
    # greeter
    sddm qt6-virtualkeyboard gst-libav
    # compositor + shell
    hyprland hypridle hyprlock hyprpicker hyprcursor hyprsunset
    xdg-desktop-portal xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk xdg-desktop-portal-kde
    qt6-base qt6-declarative qt6-wayland qt6-svg qt6-multimedia
    qt6-5compat qt6-shadertools
    # session
    polkit-kde-agent gnome-keyring
    networkmanager bluez bluez-utils
    # look
    kitty dolphin
    fish starship fastfetch mpv eza
    ttf-jetbrains-mono-nerd
    inter-font
    adw-gtk-theme
    breeze
    librsvg
    # audio / backlight / media
    pipewire pipewire-pulse wireplumber pavucontrol-qt
    playerctl upower brightnessctl cava
    # tools the shell actually calls
    wl-clipboard cliphist grim slurp swappy hyprshot tesseract
    tesseract-data-eng tesseract-data-fra wf-recorder
    jq imagemagick libqalculate rsync songrec
    python python-pillow python-numpy python-opencv
    git
)

# hyprshot and songrec used to live here; both are in extra now, so they
# go through pacman and no longer need yay to be present.
AUR_PKGS=(
    ttf-nothing-font-git
    bibata-cursor-theme-bin
    darkly-bin
)

# Qogir supplies the application icons the Nothing icon theme inherits, so
# without it every app falls back to breeze-dark's near-monochrome set. The
# package name is not the same everywhere: EndeavourOS ships it as
# eos-qogir-icons, plain Arch has it only in the AUR.
if pacman -Si eos-qogir-icons >/dev/null 2>&1; then
    PACMAN_PKGS+=(eos-qogir-icons)
elif pacman -Si qogir-icon-theme >/dev/null 2>&1; then
    PACMAN_PKGS+=(qogir-icon-theme)
else
    AUR_PKGS+=(qogir-icon-theme)
fi

# Quickshell: extra as `quickshell`, otherwise the git package.
if pacman -Si quickshell >/dev/null 2>&1; then
    PACMAN_PKGS+=(quickshell)
else
    AUR_PKGS+=(quickshell-git)
fi

log "Official repositories"
mapfile -t PACMAN_OK < <(filter_sync "${PACMAN_PKGS[@]}")
if ((${#PACMAN_OK[@]})); then
    run sudo pacman -S --needed --noconfirm "${PACMAN_OK[@]}"
fi

if ! have yay; then
    warn "yay is not installed. AUR packages will be skipped:"
    printf '    %s\n' "${AUR_PKGS[@]}"
    warn "Install yay, then re-run: ./install --deps"
else
    log "AUR packages"
    for p in "${AUR_PKGS[@]}"; do
        if [[ "$p" == bibata-cursor-theme-bin ]] \
            && [[ -d /usr/share/icons/Bibata-Modern-Classic ]]; then
            ok "Bibata cursor already installed, skipping $p"
            continue
        fi
        run yay -S --needed --noconfirm "$p" || warn "could not install $p"
    done
fi

# Backs the "Nothing X" launcher entry: ANC, equaliser, battery and
# firmware for Nothing and CMF earbuds. Offered rather than installed
# outright: it is 28 MiB and it is worth nothing without the hardware.
# Declining costs nothing either, because the entry carries TryExec and
# hides itself when the binary is absent.
offer_ear_native() {
    if have ear-native; then
        ok "ear-native already present (the Nothing X entry works)"
        return
    fi
    log "Nothing X"
    printf '%s\n' \
        "  This rice ships a \"Nothing X\" launcher entry for Nothing and" \
        "  CMF earbuds: ANC, equaliser, battery and firmware. It is backed" \
        "  by ear-native (AUR), about 28 MiB, and the entry stays hidden" \
        "  until that binary exists."
    if ! have yay; then
        warn "yay is not installed. Later: yay -S ear-native"
        return
    fi
    if ! ask_yn "Install ear-native for the Nothing X app?" y; then
        warn "Skipped. Later: yay -S ear-native"
        return
    fi
    run yay -S --needed --noconfirm ear-native \
        || { warn "could not install ear-native"; return; }
    ok "Nothing X is ready. Find it in the launcher, or type # for the lot."
}

# The three ROG userspace tools from asus-linux.org: fan curves and power
# profiles (asusd), the hybrid graphics switch (supergfxd), and the panel
# that drives both.
#
# Deliberately no kernel. The guide also offers linux-g14; swapping
# someone's kernel is not something a desktop rice gets to do, and this
# machine is fine without it.
#
# No third-party repository is added either. These live in the official
# repos on some setups, in chaotic-aur or the g14 repo on others, and in
# the AUR everywhere; the installer uses whichever is already reachable
# rather than editing pacman.conf behind your back.
offer_rog() {
    # Anything else would be guessing at hardware we cannot see.
    local vendor=""
    [[ -r /sys/class/dmi/id/sys_vendor ]] \
        && vendor="$(tr -d '\0' < /sys/class/dmi/id/sys_vendor)"
    # "ASUSTeK COMPUTER INC." already contains ASUS, one pattern is enough.
    case "$vendor" in
        *ASUS*) ;;
        *) return ;;
    esac

    if have asusctl && have supergfxctl; then
        ok "ROG tools already present (asusctl, supergfxctl)"
        return
    fi

    log "ASUS ROG"
    printf '%s\n' \
        "  This looks like an ASUS machine. asus-linux.org ships three" \
        "  userspace tools: asusctl for fan curves and power profiles," \
        "  supergfxctl for the hybrid graphics switch, and" \
        "  rog-control-center to drive both. No kernel is touched."

    if ! ask_yn "Install the ASUS ROG tools?" y; then
        warn "Skipped. See https://asus-linux.org/guides/arch-guide/"
        return
    fi

    local from_repo=() from_aur=() p
    for p in asusctl supergfxctl rog-control-center; do
        if pacman -Si "$p" >/dev/null 2>&1; then
            from_repo+=("$p")
        else
            from_aur+=("$p")
        fi
    done

    # Tracked, because a run that failed every step used to finish by
    # announcing the tools were ready.
    local failed=0
    if ((${#from_repo[@]})); then
        run sudo pacman -S --needed --noconfirm "${from_repo[@]}" \
            || { warn "could not install ${from_repo[*]}"; failed=1; }
    fi
    if ((${#from_aur[@]})); then
        if have yay; then
            run yay -S --needed --noconfirm "${from_aur[@]}" \
                || { warn "could not install ${from_aur[*]}"; failed=1; }
        else
            warn "not in your repos and yay is missing: ${from_aur[*]}"
            warn "add the g14 repo from asus-linux.org, or install yay"
            failed=1
        fi
    fi

    if (( failed )); then
        warn "ROG tools not installed. See https://asus-linux.org/guides/arch-guide/"
        return
    fi

    # Enabled only when the unit really exists: these are the names
    # asus-linux documents, but a rename should leave a note here rather
    # than a failed command.
    local svc
    for svc in asusd supergfxd; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^$svc\.service"; then
            run sudo systemctl enable --now "$svc.service" \
                || warn "could not start $svc"
        else
            warn "$svc.service not found; enable it by hand if the tool needs it"
        fi
    done

    ok "ROG tools are ready. rog-control-center is in the launcher."
}

offer_warp() {
    if have warp-cli; then
        ok "warp-cli already present (WARP tile in the control centre)"
        return
    fi
    log "Cloudflare WARP"
    printf '%s\n' \
        "  The control centre has a WARP (1.1.1.1) toggle. It stays hidden" \
        "  until warp-cli is installed (AUR: cloudflare-warp-bin)."
    if ! have yay; then
        warn "yay is not installed. Later: yay -S cloudflare-warp-bin"
        return
    fi
    if ! ask_yn "Install Cloudflare WARP from the AUR?" y; then
        warn "Skipped. Later: yay -S cloudflare-warp-bin"
        return
    fi
    run yay -S --needed --noconfirm cloudflare-warp-bin \
        || { warn "could not install cloudflare-warp-bin"; return; }
    if systemctl list-unit-files warp-svc.service >/dev/null 2>&1; then
        run sudo systemctl enable --now warp-svc.service \
            || warn "could not start warp-svc"
    fi
    ok "WARP is ready. Toggle it from the control centre (SUPER+N)."
}

offer_ear_native
offer_rog
offer_warp

ok "Dependencies are in place."
