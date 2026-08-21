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
  components/apps/             Essential Apps renderer (AppHost, AppBlock,
                               AppSlot, expr.js)
  modules/                     bar, launcher, settings, game bar…
  services/                    brightness, net, notifs, shot, recorder…
  assets/apps/*.json           bundled Essential Apps, seeded on first run
  shaders/dotfield.frag        settings field (compile with scripts/compile-shaders.sh)
scripts/                       install, session, screenshots, icons
scripts/essential.py           Essential Space vault + Gemini helpers
scripts/essential-app.py       Essential Apps: generate, validate, store
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

**Essential Apps.** An app is a JSON spec, never code. The model writes
it, `scripts/essential-app.py` validates it, and a fixed renderer draws
it, so a generated app cannot execute anything and cannot look off-brand.

There is no store and no import: an app only ever comes from a prompt
typed on this machine, which is what keeps the whole thing safe without
a sandbox.

An app reads the desktop through curated context objects only: `time`,
`weather`, `sys`, `media`, `net`, `audio`, `battery`, `updates`,
`notifs`, `desktop` and `vault`. Facts, never handles, so a spec can
show the volume but not change it. `EXPR_ROOTS` is derived from
`SOURCES` rather than retyped: when it was not, adding `battery` made
`battery.percent` render as that literal text, because
`quote_if_literal()` did not recognise the root.

Arrow functions are allowed. Blocking `=>` was a side effect of the
anti-assignment rule and it cost `sort`, `filter`, `map` and `reduce`,
which is most of what a list widget needs, for no security gain: an
arrow body sees the same stripped scope. Loops are banned instead,
since a braced arrow body needs no semicolon and `while(1){}` would
hang the render thread. Name checks run with string literals blanked
out, so a caption reading "for you" is not mistaken for a loop, and
`obj["constructor"]` is refused alongside `obj.constructor`.

Expressions inside a spec are locked twice. The validator rejects `Qt`,
`Function`, `constructor`, every assignment and every statement
separator; `components/apps/expr.js` then compiles what survives into a
function whose only arguments are the context objects. QML singletons
live in component scope, not on the global object, so a spec has nothing
to reach for even if the first lock were bypassed.

Network reads are declared, never performed by the spec: `fetch` names
an https URL and an interval, and `services/MiniApps.qml` runs the
`curl` itself, one at a time, exactly like `Weather.qml`.

Nothing the model says about an endpoint is trusted. `ground()` fetches
every URL it proposed, in order, and keeps the one that answers; the
model is told to supply `fetch.candidates` whenever it is unsure. If
none answer it gets the HTTP errors and picks different providers. Once
one answers, `shape_of()` hands it the response it will really receive
and it rewrites `pick` and every field name against that. The second
call is skipped when `missing_fields()` finds that everything the draft
reads already exists in the payload, so a first-try hit costs nothing.

Asked for the latest from Nothing Community, the model answered with an
RSS-to-JSON proxy pointed at a third-party blog. That answers, is on
topic and is fresh, so every check passed, and it was still not the
thing asked for: nothing.community runs Flarum and publishes its own
JSON at `/api/discussions`. `prefer_official()` takes the host the model
puts in `home` and probes the well-known paths for Flarum, Discourse,
NodeBB and WordPress; when one yields items, the app is redrafted
against it with a catalogue of its real fields. Conventions, not a list
of sites. The proxy is now described to the model as the fallback for a
site that publishes nothing of its own.

The probe and the shell's `curl` must send the same `User-Agent`, for
the same reason they must send the same `Accept`: a bare tool agent is
refused by enough sites that the probe would bless what the shell cannot
fetch. Both send a Mozilla-compatible token that still names the app.

Two ways an app passes every mechanical check and is still useless, so
`quality_gate()` runs both before saving.

`freshness_check()` costs no model call: for a request that mentions
news, latest, a feed or a community, it finds the newest dated entry in
the payload and refuses a source that went quiet. 9to5google's Nothing
tag is a real feed with real fields whose last post was a fortnight old,
which every other check happily accepted. It only runs on requests that
ask for recency, so a holidays or standings feed is never flagged. The
model is also told to sort by date rather than trust the order items
arrive in, using `Date.parse(x)`, since `new` is not available.

`prefer_official()` re-runs discovery even when the spec is already on
the right host, because a refine kept handing back the bare path and
dropping `?sort=-createdAt`. That parameter decides which twenty items
the server sends, and sorting client-side cannot recover what was never
fetched. When only the query string differs, the discovered URL is
adopted outright rather than costing a redraft.

`OFFICIAL_PATHS` carries a third field: how one item of that platform
is addressed on the web, `/d/<slug>` for Flarum, `/t/<slug>/<id>` for
Discourse, the `link` field for WordPress. Without it the model lists
discussions correctly and gives no way to open one, which is most of
what a feed widget is for. It cannot be derived from the payload: the
API returns a slug, not a URL.

A fourth field names the publication date, `createdAt` for Flarum,
`created_at` for Discourse, `timestampISO` for NodeBB, `date` for
WordPress. Forums carry two dates and the wrong one is invisible: a
"latest posts" widget sorted by last reply put a thread from March at
the top because someone commented on it that morning. One item in
twenty also has a null activity date, having no replies at all.

`MiniApps.cancel()` stops a run in flight, from the square in the
composer or from Escape. Nothing is written until `cmd_gen` returns, so
a kill leaves no half-built app. The `cancelled` flag exists because the
process still emits an exit after being torn down, and without it that
exit was reported as "The generator failed" seconds after the user
deliberately stopped.

A rejection must never leave the user worse off. When the redraft's
endpoint reaches nothing, or fails the gate again, the original spec is
kept and the complaint is returned as a note: a stale feed still beats a
dead URL, and the first version of this swapped one for the other.

Answering and being correct are different things. `subject_check()`
reads the chosen feed back to the model against the original request,
because every mechanical check passes when the model reaches for a
neighbouring API: asked for MotoGP it used the F1 endpoint out of the
examples, the URL answered, and every field it named existed. A failed
check triggers one redraft told not to reuse a convenient endpoint, and
to ship without a feed rather than show someone else's data. The check
fails open, since a verifier that is merely down must not block an app.

Essential Apps opens as a side shelf, the same mechanics as
`Essential.qml`: a full-screen transparent window with a catcher behind,
a pane translated in on `reveal`, and `OnDemand` keyboard focus so a
click on another window hands typing back. It takes the edge opposite
the vault, which mirrors the bar, where the dot grid sits left of the
clock and the Essential Key sits right of it. One narrow column of
full-width cards, not a masonry: a card then shows an app at close to
the size it will have on the desktop. `AppsCard` owns the chrome and
`AppHost` has a `flat` mode, so the desktop column can render the same
app with no frame at all.

Nothing a spec asks for may paint outside its card. Blocks elide, every
`AppSlot` sets `Layout.minimumWidth: 0` because a nested layout takes
its children's implicit width as a hard minimum and one long value made
the whole chain refuse to shrink, and `AppHost` clips as a last resort.
`stat` gave up `Layout.fillWidth` on its value whenever a unit was
present, which is how a race name ran straight out of the frame.
`NPillButton` grew a `maxWidth` that defaults to 0, so the other 28
buttons in the shell still size to their label.

The correction is re-checked, twice at most, and a spec that still reads
absent fields is saved with a note rather than silently. Both mattered:
the first anime app written here pointed a Kitsu URL at Jikan's field
names (`it.title`, `it.episodes`), the mismatch was detected, the repair
call hit a 503, and the broken spec was saved without a word. What the
model is handed to fix it is `flat_paths()`, a flat catalogue of real
paths with sample values (`it.attributes.canonicalTitle = "One Piece"`),
which beats a truncated JSON dump. Dicts keyed by numbers are collapsed:
Kitsu's 19-entry `ratingFrequencies` otherwise crowded out the episode
count, which was the field being asked for.
This is not belt and braces: Jikan answered 504 to everything for an
hour while this was being written, and was back an hour later.

`Accept` must be the same string in `http_get()` and in the shell's
`curl`, or the probe blesses URLs the shell cannot fetch. A bare
`application/json` earns a 406 from JSON:API feeds like Kitsu. The
`curl` also needs `-g`: without it `page[limit]=5` is read as a glob.

Every field in a spec is an expression, and models reliably forget it
and write `"caption": "CURRENTLY AIRING"`, which is a syntax error and
renders blank. `quote_if_literal()` takes a bare run of words as the
string it obviously is, while leaving anything starting at a known root
(`state`, `data`, `it`, `fmt`, `Math`…) alone.

State, ticks and fetches belong to `MiniApps`, not to the views. The
same app can sit in the panel and on the desktop at once, and two hosts
each running the tick would count down twice as fast.

`AppBlock` cannot instantiate itself: the engine rejects recursive
instantiation statically, whatever `Component` or `Repeater` it is
buried in. `AppSlot` grows the tree through a `Loader` whose source is a
URL resolved at runtime, which is what breaks the static cycle.

`gemini_text()` in `scripts/essential.py` walks its model list and used
to stop at the first failure. A model out of quota answers 429 while the
next one in the list answers fine, so every caller reported "Gemini is
busy" with a healthy fallback one line away. Quota and overload errors
now fall through to the next model. This is why a repair call could
quietly give up: the verifier was never really down.

Generating needs Gemini or Ollama (Essential settings, shared with
Mind). The six bundled apps under `quickshell/nothing/assets/apps/` are
seeded on first run, so the feature is usable with no key at all, and
they double as the examples handed to the model.

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
