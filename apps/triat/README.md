# Triat

A small music player for this rice. It plays music from YouTube, without
ads, and skips the non-music parts of videos with SponsorBlock. It is built
with GTK4 and libadwaita, and it tries to look like the rest of the shell:
matte black, small type, the red dot, dots everywhere.

> Heads up: this app was vibe coded. I described what I wanted and an AI
> (Claude) wrote most of the code, then I tested it on my own machine. The
> code comments and some notes are in French, sorry about that.

## What it does

- Search YouTube, play songs, queue, shuffle, repeat, radio when the queue ends
- Keeps playing when you close the window (Ctrl+Q quits for real)
- Playlists, favourites, history, and a few "smart" playlists
- Import a `.txt` of YouTube links or an `.m3u`, export back out
- Synced lyrics (LRCLIB), SponsorBlock, 10-band equaliser
- Offline downloads, a mini player, full screen with the clip or a dot matrix
- Optional YouTube cookies from your browser for your own recommendations
- MPRIS, so media keys and `playerctl` work

## Bar module

It adds a **Triat** item to the bar catalogue. It is not placed by default:
open the bar layout editor in Settings and drop it where you like (the
installer below puts it in the centre for you).

- left click: a small panel with the cover, progress and controls
- middle click: play / pause, right click: next, scroll: next / previous
- `qs ipc call triat panel` opens the panel from a keybind

## Install

Needs Arch-style packages first:

```sh
sudo pacman -S python-gobject gtk4 libadwaita mpv python-cairo
```

Then, from this folder:

```sh
bash packaging/nothing-os/install.sh
```

It installs the app in `~/.local/share/triat` with its own Python venv,
adds a launcher (`triat`), a desktop entry, the Hyprland rules in
`~/.config/hypr/triat.lua`, and the bar module. `--uninstall` removes it.

Keybinds it adds (picked to not clash with the rice):

| Keys | Action |
|---|---|
| `SUPER+M` | open or bring back Triat |
| `SUPER+CTRL+M` | mini player |
| `SUPER+ALT+↓` | play / pause |
| `SUPER+ALT+←/→` | previous / next |

## Run it from source

```sh
python -m venv --system-site-packages .venv
.venv/bin/pip install -r requirements.txt
./run.sh
.venv/bin/python -m pytest -q      # about 400 tests, no network
```

## Things to know

- Your library lives in `~/.local/share/triat`, your settings in
  `~/.config/triat`. Nothing is sent anywhere except YouTube, SponsorBlock
  and LRCLIB (and ListenBrainz if you turn it on).
- When YouTube changes something, extraction can break. Updating yt-dlp
  usually fixes it: `~/.local/share/triat/venv/bin/pip install -U yt-dlp`.
- `triat doctor` prints a quick health check.
