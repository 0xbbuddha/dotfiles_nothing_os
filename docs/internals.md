# Internals

For people hacking on the rice. Users can stay on the [README](../README.md).

## Layout

```
hypr/hyprland.lua              Hyprland entry (require hypr/hyprland/)
hypr/hyprland/variables.lua    apps, palette, ipc()
hypr/hyprland/env.lua          environment
hypr/hyprland/monitors.lua     outputs
hypr/hyprland/execs.lua        startup
hypr/hyprland/general.lua      gaps, decoration, input
hypr/hyprland/animations.lua   curves
hypr/hyprland/keybinds.lua     binds
hypr/hyprland/rules.lua        window / layer rules
hypr/wallpaper.png             default wallpaper
hypr/hyprlock.conf             lock screen
hypr/hypridle.conf             idle / sleep
hypr/lockstatus.sh             lock-screen status line
hypr/custom.lua.example        sample binds -> ~/.config/hypr/custom.lua
hypr/passthrough.lua           keyboard passthrough for the nested session
hypr/local.lua                 fallback if ~/.config/hypr/local.lua is missing
quickshell/nothing/
  shell.qml                    entry point
  Theme.qml                    colours, type, geometry, timings
  Config.qml                   ~/.config/nothing/config.json
  GlobalState.qml              state shared across windows
  components/                  primitives, Glyph Matrix, widgets
  modules/                     bar, launcher, settings, game bar…
  services/                    brightness, net, notifs, shot, recorder…
  shaders/dotfield.frag        settings field (compile with scripts/compile-shaders.sh)
scripts/                       install, session, screenshots, icons
theme/                         Dolphin / GTK / portal / icon seeds
config/                        kitty, fish, starship, fastfetch, mpv, fontconfig
install                        public installer
```

## Notes

**~/.config.** `./install` copies Hyprland, hypridle, hyprlock, the
Quickshell shell, `scripts/`, `theme/`, kitty, mpv, fontconfig,
fastfetch and starship into the user config dirs (rsync/cp, no
symlinks). Previous files are kept as `*.bak-<stamp>`. `custom.lua`
and an existing `fish/config.fish` are created once and never
overwritten; `fish/conf.d/nothing.fish` is refreshed. Re-run
`./install --files` after pulling.

**WARP.** The control-centre tile is hidden until `warp-cli` exists.
`./install --deps` offers AUR `cloudflare-warp-bin` and enables
`warp-svc`. First connect registers via `warp-cli registration new`.

**SDDM.** `scripts/install-session.sh` installs the launcher in
`/usr/local/bin/nothing-session` and the greeter theme
`sddm-astronaut-theme` (Hyprland Kath) under `/usr/share/sddm/themes/`.
SDDM runs as `sddm` before login; if home is `0710` it cannot `TryExec`
a script inside the repo.

**start-hyprland.** `nothing-session.sh` uses it when present (watchdog,
dbus, systemd scope), with a fallback to `Hyprland -c …`.

**dbus / portals.** `hypr/hyprland/execs.lua` runs
`dbus-update-activation-environment --systemd --all` first, then
`scripts/setup-portals.sh`. FileChooser is `kde;gtk` in
`theme/xdg-desktop-portal/hyprland-portals.conf` because
xdg-desktop-portal-hyprland does not implement it.

**Hyprland Lua.** `hyprctl dispatch` and `Hyprland.dispatch()` parse
**Lua**. `dispatch("workspace 3")` is a no-op. Write
`dispatch("hl.dsp.focus({ workspace = 3 })")`.
`hyprctl keyword` refuses the Lua parser; live options go through
`hyprctl eval 'hl.config({ ... })'`.

**Special workspace.** `gotoWorkspaceSafe()` in `hypr/hyprland/keybinds.lua` closes it
before switching, so the overview does not look stuck.

**Scale.** This config forces `scale = 1` on the laptop panel (`auto`
picked 1.5 here). UI sizes go through `Theme.px()`.

**QML names.** Do not call a singleton `Keys`. Do not name a method
`eval`. Do not name a function `unique`.

**Google Lens.** `scripts/lens.sh` uploads the selection to `uguu.se`
for a public URL. Do not select anything confidential.

**Weather.** On by default, `wttr.in` every 15 minutes. Toggle on the
Interface settings page.

**hyprshot.** The packaged `getopt` treats `-r` as taking an argument.
Scripts use `-o DIR -f NAME` instead.

**Language.** UI, comments and docs are English. Dates use `en_GB` via
`services/Time.qml`.

Verify the compositor config:

```bash
Hyprland --verify-config -c hypr/hyprland.lua
```
