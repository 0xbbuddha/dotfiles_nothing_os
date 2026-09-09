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
  components/apps/             Essential Apps renderer (AppHost, AppBlock,
                               AppSlot, expr.js)
  modules/                     bar, launcher, settings, game bar…
  services/                    brightness, net, notifs, shot, recorder…
  assets/apps/*.json           bundled Essential Apps, seeded on first run
  shaders/dotfield.frag        settings field (compile with scripts/compile-shaders.sh)
scripts/                       install, session, screenshots, icons
scripts/essential.py           Essential Space vault + Gemini helpers
scripts/essential-app.py       Essential Apps: generate, validate, store
scripts/dot-wallpaper.py       any picture -> a dot-matrix wallpaper
scripts/make-fetch-logos.sh    rebuild the fastfetch dot logos
scripts/fetch-logo.sh          pick or alternate the fastfetch logo
theme/                         Dolphin / GTK / portal / icon seeds
config/                        kitty, fish, starship, fastfetch, mpv, fontconfig
install                        public installer
```

## Notes

**~/.config.** `./install` copies Hyprland, hypridle, the
Quickshell shell, `scripts/`, `theme/`, kitty, mpv, fontconfig,
fastfetch and starship into the user config dirs (rsync/cp, no
symlinks). Previous files are kept as `*.bak-<stamp>`. `custom.lua`
and an existing `fish/config.fish` are created once and never
overwritten; `fish/conf.d/nothing.fish` is refreshed. Re-run
`./install --files` after pulling.

**Idle.** hypridle reads one config file when it starts and has no
runtime interface, so `services/Idle.qml` generates
`~/.config/nothing/hypridle.conf` from the four timings in Settings and
restarts the daemon. `hypr/hyprland/execs.lua` uses that file when it
exists and falls back to `hypr/hypridle.conf`, so a session that has
never opened Settings still idles. The restart is deliberately
lock-free and self-correcting: it kills, waits for the process to be
gone, starts one, then trims to a single daemon. Two overlapping
restarts used to leave two hypridle running, and two of them fire every
timeout twice.

**Bluetooth.** `Bluetooth.defaultAdapter` is null for the first couple
of seconds after the shell starts, and `Net.scanBt()` on a null adapter
silently does nothing. The flyout therefore renews discovery on a timer
rather than only on open, which also covers BlueZ giving up on its own
after a few minutes and leaving the list looking frozen. Devices are
sorted connected, then paired, then the rest: unsorted, a passing phone
outranked your headphones. `Net.btGlyph()` maps BlueZ's icon name to a
glyph, so `audio-card` reads as a speaker rather than a headset.

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
`eval`. Do not name a function `unique`. Do not declare a property named
`left` or `right` on an `Item`: those are FINAL anchor lines and the
override is refused at load. `services/MiniApps.qml` is deliberately not
called `EssentialApps`: `modules/` and `services/` are imported into the
same scope, and two files of one name shadow each other.

**Essential Apps.** A widget is a JSON spec, never code. The model
fills a *face* (stat, tracker, list, clock, media, note) or a custom
block tree; `scripts/essential-app.py` validates it, and `Widget.qml`
draws a 2×2 / 2×4 / 4×4 tile. The builder is a conversation: each
prompt is a chat turn, the live tile sits above the thread, then you
pin it to the desktop.

There is no store. An app only ever comes from a prompt or a bundled
preset on this machine.

An app reads the desktop through curated context objects only: `time`,
`weather`, `sys`, `media`, `net`, `audio`, `battery`, `updates`,
`notifs`, `desktop` and `vault`. Facts, never handles. Network reads
are declared as `fetch`; the shell runs `curl`.

Expressions are locked twice (validator + `expr.js`). Loops and
assignment are banned. Arrow functions are allowed.

`MiniApps.cancel()` stops a run in flight. Nothing is written until
`cmd_gen` returns.

Essential Apps opens as a side shelf, the same mechanics as
`Essential.qml`. It takes the edge opposite the vault.

Nothing a spec asks for may paint outside its tile. `Widget` clips.

State, ticks and fetches belong to `MiniApps`, not to the views. The
same widget can sit in the builder and on the desktop at once, and two
hosts each running the tick would count down twice as fast.

`AppBlock` cannot instantiate itself: the engine rejects recursive
instantiation statically. `AppSlot` grows a custom face through a
`Loader` whose source is a URL resolved at runtime.

Generating needs Gemini (Essential settings, shared with Mind). The six
bundled widgets under `quickshell/nothing/assets/apps/` are seeded on
first run, so the feature is usable with no key, and they double as
examples for the model.

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
