# Nothing

Hyprland + Quickshell rice inspired by **Nothing OS**: matte black,
concrete grey, red `#d71921`, tight radii, Ndot, and a Glyph Matrix.

Unofficial. Not affiliated with Nothing Technology Limited.

Written for **Arch / EndeavourOS**, **Hyprland ≥ 0.56** (Lua config) and
**Quickshell ≥ 0.3**.

## Screenshots

| Desktop | Nothing Launcher |
|:---:|:---:|
| ![Desktop](assets/global.png) | ![Nothing Launcher](assets/nothing-launcher.png) |
| **Settings** | **Settings, System** |
| ![Settings](assets/settings.png) | ![System](assets/settings-system.png) |
| **Glyph Bar** | **Glyph Strip** |
| ![Glyph Bar](assets/glyph-bar.png) | ![Glyph Strip](assets/glyph-strip.png) |
| **Glyph, in the launcher** | **Control centre** |
| ![Glyph settings](assets/glyph-settings.png) | ![Control centre](assets/cc.png) |
| **Essential Search** | **Essential Space + Key** |
| ![Essential Search](assets/essential-search.png) | ![Essential Space + Key](assets/essential-space-key.png) |
| **Essential Apps** | **Game bar** |
| ![Essential Apps](assets/essential-apps.png) | ![Game bar](assets/game-bar.png) |
| **Dolphin** | |
| ![File explorer](assets/file-explorer.png) | |

## Install

```bash
git clone https://github.com/<you>/nothing.git
cd nothing
./install
```

That writes the rice into **your** config dirs as **copies** (rsync/cp,
no symlinks):

| Path | From |
|---|---|
| `~/.config/hypr/hyprland.lua` | `hypr/hyprland.lua` (loader) |
| `~/.config/hypr/hyprland/` | env, keybinds, rules, … |
| `~/.config/hypr/wallpaper.png` | `hypr/wallpaper.png` (default wallpaper) |
| `~/.config/hypr/hypridle.conf` | idle |
| `~/.config/hypr/hyprlock.conf` | lock |
| `~/.config/quickshell/nothing/` | the shell |
| `~/.config/scripts/` | helpers |
| `~/.config/theme/` | Dolphin / GTK / portal seeds |
| `~/.config/kitty/` | terminal (Nothing colours) |
| `~/.config/fish/conf.d/nothing.fish` | greeting, starship, aliases |
| `~/.config/starship.toml` | prompt |
| `~/.config/fastfetch/` | fetch |
| `~/.config/mpv/` | player |
| `~/.config/fontconfig/` | Inter / JetBrains, greyscale AA |
| `~/.config/hypr/custom.lua` | your binds (created once) |

Whatever was already there is moved to `*.bak-<date>`. After a `git pull`,
run `./install --files` again to refresh the copies. The installer also
applies the Dolphin/GTK theme, file-picker portals, and an SDDM session
named **Nothing** with the **astronaut** greeter (Hyprland Kath). Log out
and pick it (or the normal Hyprland entry: it now reads the same
`hyprland.lua`).

| Flag | What it does |
|---|---|
| *(none)* | packages + `~/.config` + SDDM |
| `--deps` | packages only |
| `--files` | `~/.config` + theme, skip pacman |
| `--uninstall` | restore the backups (not packages) |
| `--noconfirm` | no prompts |

Needs `sudo` for packages and the session file. Do not run the script
itself as root.

Without SDDM, from a TTY:

```bash
./scripts/nothing-session.sh
```

`SUPER+SHIFT+M` leaves that session.

### Nested (dev)

```bash
./scripts/run-nested.sh
```

The host compositor eats `SUPER`. Optional passthrough: source
`hypr/passthrough.lua` in the host config, then `SUPER+ALT+P`.

### Shell only

```bash
./scripts/run-shell.sh          # overlay on the current session
./scripts/run-shell.sh --solo   # pause an illogical-impulse shell
```

## What you get

- **Bar, dock, control centre, settings** - one scale slider, one accent
- **Desktop widgets** - 46 of them in 12 families: dot-matrix and dial
  clocks, date and calendar, Quick Look, weather, photos, media, a
  countdown on any of Nothing's twelve shapes, breathing exercises,
  battery, network, screen time, world clock. A different look is a
  separate widget, never a setting, so nothing changes size underneath you
- **Nothing Launcher** (`SUPER+ALT+L`, or the dot button on the dock) -
  where widgets and the Glyph are chosen. Every preview is the real widget
  at its real size, not a drawing of one
- **Glyph Interface** - three surfaces, one lit at a time:
  - **Matrix**, the 489-dot disc, running toys (clock, battery, dice, cava…)
  - **Bar**, six segments and the camera light, Phone (4a)
  - **Strip**, three arcs around where the camera would be, Phone (3a)

  The Bar and the Strip are dark until something happens. Which events may
  light them, and the rhythm each one plays, is yours to set: nine rhythms
  ship, and you can tap your own on the pads. `SUPER+SHIFT+G` cycles them
- **Launcher** (`SUPER`) - search on top, 10-workspace overview under it.
  `#` lists every Nothing app and surface
- **Essential Apps** (`SUPER+ALT+A`, or the dot grid left of the clock) -
  a shelf on the opposite edge to Essential Space, mirroring the bar.
  Describe a widget in a sentence and the model writes it: a race
  countdown, a tea timer, the anime airing this season with their
  posters. It reads any public JSON API, plus the desktop's own battery,
  volume, updates, notifications, workspace and Essential Space vault.
  Six are bundled, so it works with no API key. Yours sit in the right
  column of the desktop, the rice's widgets keep the left one
- **Game bar** (`SUPER+G`) - overlay widgets you pin over a game
- **Screenshots** - click a window, drag a rect, or click empty for the output
- Notifications with an **Open message** action for Vesktop / Discord
- Optional **WARP** (1.1.1.1) tile in the control centre if `warp-cli` is
  installed - `./install` offers the AUR package `cloudflare-warp-bin`
- On an Asus ROG machine, `./install` offers the three asus-linux tools.
  It never touches your kernel
- Dolphin / GTK / Qt themed to match; file pickers go through xdg-desktop-portal
- **kitty**, **fish** + starship, **fastfetch**, **mpv**, and **fontconfig** (which fonts apps pick, and greyscale anti-aliasing)

Settings live in `~/.config/nothing/config.json`.

## Shortcuts

| Keys | Action |
|---|---|
| `SUPER` (tap) | launcher + workspaces |
| `SUPER+Enter` / `SUPER+T` | terminal |
| `SUPER+E` | file manager |
| `SUPER+W` | browser |
| `SUPER+D` / `SUPER+F` | maximise / fullscreen |
| `SUPER+N` | control centre |
| `SUPER+B` | notifications |
| `SUPER+I` | settings |
| `SUPER+A` | Essential Space |
| `SUPER+ALT+A` | Essential Apps |
| `SUPER+ALT+L` | Nothing Launcher |
| `SUPER+SHIFT+G` | next Glyph surface |
| `SUPER+G` | game bar |
| `SUPER+V` / `SUPER+.` | clipboard / emoji |
| `SUPER+SHIFT+S` | region capture |
| `SUPER+SHIFT+X` | OCR |
| `SUPER+SHIFT+R` | record a region |
| `SUPER+Esc` | session menu |
| `SUPER+L` | lock |

Apps (terminal, browser, editor) are detected among what is installed.

Stock binds: `hypr/hyprland/keybinds.lua`. Personal ones go in
`~/.config/hypr/custom.lua` (created on install). Throwaway tests:
`~/.config/hypr/local.lua`.

## Fonts

```bash
yay -S ttf-nothing-font-git    # Ndot77 + Inter - pulled by ./install
```

Without that package the UI still runs, on system fonts.

## Uninstall

```bash
./install --uninstall
```

Packages are left installed. App theme revert:

```bash
./scripts/apply-app-theme.sh --revert
```

## Credits

- [Nothing OS](https://nothing.tech) for the language (again: unofficial)
- [end-4 / illogical-impulse](https://github.com/end-4/dots-hyprland) -
  that was my daily rice. I got used to a handful of its behaviours, and
  those habits steered the direction Nothing took.
- [Quickshell](https://quickshell.outfoxxed.me/)

Internals (file map, Hyprland Lua notes): [docs/internals.md](docs/internals.md).
