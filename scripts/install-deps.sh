#!/usr/bin/env bash
# Arch / EndeavourOS dependencies for the Nothing session.
# Sourced by ./install, or run on its own:
#   ./scripts/install-deps.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/scripts/lib.sh"
NOTHING_ROOT="$ROOT"

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
    qogir-icon-theme
    breeze
    # audio / backlight / media
    pipewire pipewire-pulse wireplumber pavucontrol-qt
    playerctl upower brightnessctl cava
    # tools the shell actually calls
    wl-clipboard cliphist grim slurp swappy tesseract
    tesseract-data-eng tesseract-data-fra wf-recorder
    jq imagemagick libqalculate rsync
    python python-pillow python-numpy python-opencv
    git
)

AUR_PKGS=(
    ttf-nothing-font-git
    bibata-cursor-theme-bin
    hyprshot
    songrec
    darkly-bin
)

# Quickshell: extra as `quickshell`, otherwise the git package.
if pacman -Si quickshell >/dev/null 2>&1; then
    PACMAN_PKGS+=(quickshell)
else
    AUR_PKGS+=(quickshell-git)
fi

log "Official packages"
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

offer_warp

ok "Dependencies are in place."
