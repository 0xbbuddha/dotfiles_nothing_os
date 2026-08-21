#!/usr/bin/env python3
"""Essential Apps: mini apps described in a prompt, rendered by the shell.

An app is a JSON spec, never code. The shell has a fixed renderer for a
closed set of blocks, so a generated app cannot execute anything: the
worst a bad spec can do is look wrong. Network reads go through a
declared `fetch` the shell performs itself.

Commands:
  list                 every spec, newest first
  get ID
  gen                  prompt on stdin  -> {ok, id, name, error}
  refine ID            change request on stdin
  put ID               hand-edited JSON on stdin, validated the same way
  remove ID
  rename ID NAME...
  state ID             JSON patch on stdin, merged into the saved state
  reset ID             drop the saved state back to the spec defaults
  versions ID
  revert ID N
  seed                 copy the bundled presets in, once
  presets              list the bundled presets
  install NAME         copy one bundled preset in
  schema               print the schema handed to the model
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime
from email.utils import parsedate_to_datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from essential import gemini_text, parse_json_obj, read_env, have  # noqa: E402

DATA = Path(os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local/share"))
DIR = DATA / "nothing" / "apps"
STATE = DIR / "state"
VERSIONS = DIR / "versions"
SEEDED = DIR / ".seeded"
PRESETS = Path(__file__).resolve().parent.parent / "quickshell" / "nothing" / "assets" / "apps"

MAX_NODES = 160
MAX_DEPTH = 7
MAX_EXPR = 400
CAP = 40

BLOCKS = {
    "text", "stat", "row", "col", "grid", "card", "button", "toggle",
    "slider", "field", "progress", "ring", "dots", "bars", "list",
    "divider", "spacer", "icon", "image",
}

SOURCES = {"time", "weather", "sys", "media", "net", "vault", "notify",
           "audio", "battery", "updates", "notifs", "desktop"}

# An expression is evaluated by the shell in a stripped JS scope. These
# identifiers are the ones that would claw back out of it.
BANNED = re.compile(
    r"\b(Qt|Quickshell|XMLHttpRequest|Function|eval|import|require|globalThis"
    r"|window|document|process|constructor|prototype|__proto__|__defineGetter__"
    r"|setTimeout|setInterval|Component|Qt_signal)\b"
)
# Read-only: no assignment, no statement separator, no template literal.
# `=` followed by `>` is an arrow function, not an assignment: blocking it
# cost sort, filter, map and reduce, which is most of what a list widget
# needs, for no security gain. An arrow body sees the same stripped scope.
UNSAFE = re.compile(r"(?<![=!<>])=(?![=>])|;|`|\$\{")
# Loops belong to nothing here and can hang the render thread inside a
# braced arrow body, where no semicolon is needed.
LOOPS = re.compile(r"\b(while|for)\s*\(|\bdo\s*\{|\bfunction\b")
# `new Date(x)` is the reflex for date maths; Date.parse(x) does the same
# job without handing a spec a constructor.
CONSTRUCT = re.compile(r"\bnew\s+[A-Za-z]")
# obj["constructor"] is the same door as obj.constructor.
BRACKET_NAME = re.compile(r"\[\s*['\"]")
STRINGS = re.compile(r"'[^']*'|\"[^\"]*\"")


def out(obj) -> None:
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")


def fail(msg: str, code: int = 1) -> None:
    out({"ok": False, "error": msg})
    sys.exit(code)


def ensure() -> None:
    STATE.mkdir(parents=True, exist_ok=True)
    VERSIONS.mkdir(parents=True, exist_ok=True)


def slug(name: str) -> str:
    base = re.sub(r"[^a-z0-9]+", "-", (name or "app").lower()).strip("-")
    return (base or "app")[:28] + "-" + uuid.uuid4().hex[:4]


def now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S")


def spec_path(app_id: str) -> Path:
    return DIR / f"{app_id}.json"


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def load_spec(app_id: str) -> dict | None:
    data = read_json(spec_path(app_id))
    return data if isinstance(data, dict) else None


def save_spec(spec: dict) -> None:
    ensure()
    spec_path(spec["id"]).write_text(
        json.dumps(spec, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_state(app_id: str) -> dict:
    data = read_json(STATE / f"{app_id}.json")
    return data if isinstance(data, dict) else {}


def save_state(app_id: str, state: dict) -> None:
    ensure()
    (STATE / f"{app_id}.json").write_text(
        json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def archive(spec: dict) -> None:
    ensure()
    folder = VERSIONS / spec["id"]
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{int(spec.get('version') or 1)}.json").write_text(
        json.dumps(spec, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


# ── Validation ───────────────────────────────────────────────────────────
# The model is told the schema, but it is the validator that decides what
# reaches the renderer. Unknown blocks are dropped rather than rejected:
# one bad node should not cost the whole app.

class Budget:
    def __init__(self) -> None:
        self.nodes = 0
        self.errors: list[str] = []

    def note(self, msg: str) -> None:
        if len(self.errors) < 12:
            self.errors.append(msg)


# Roots an expression can legitimately start with. Anything else made of
# plain words was meant as text.
# Derived from SOURCES rather than retyped: adding a source and
# forgetting this set made `battery.percent` render as the literal text
# "battery.percent".
EXPR_ROOTS = SOURCES | {
    "state", "data", "it", "i", "fmt", "Math", "String", "Number", "Date",
    "isNaN", "parseInt", "parseFloat", "JSON", "Object", "Array",
    "true", "false", "null", "undefined", "NaN", "Infinity",
}
PLAIN_TEXT = re.compile(r"^[A-Za-z][A-Za-z0-9 _\-·•!?%,.:/]*$")


def quote_if_literal(text: str) -> str:
    """Caption "CURRENTLY AIRING" is a syntax error, not a caption.

    Models reliably forget that every field here is an expression, so a
    bare run of words is taken as the string it obviously is rather than
    silently rendering blank."""
    if not PLAIN_TEXT.match(text):
        return text
    head = re.split(r"[^A-Za-z0-9_]", text, maxsplit=1)[0]
    if head in EXPR_ROOTS:
        return text
    return "'" + text + "'"


def clean_expr(value, budget: Budget, where: str) -> str:
    text = str(value if value is not None else "").strip()
    if text == "":
        return ""
    text = quote_if_literal(text)
    if len(text) > MAX_EXPR:
        budget.note(f"{where}: expression too long")
        return ""
    # Name checks run on the code with string literals blanked out, so a
    # caption reading "for you" is not mistaken for a loop.
    bare = STRINGS.sub("''", text)
    if BANNED.search(bare) or BRACKET_NAME.search(bare):
        budget.note(f"{where}: expression uses a forbidden name")
        return ""
    if LOOPS.search(bare):
        budget.note(f"{where}: no loops, use map, filter or reduce")
        return ""
    if CONSTRUCT.search(bare):
        budget.note(f"{where}: no `new`, use Date.parse(x) for dates")
        return ""
    if UNSAFE.search(bare):
        budget.note(f"{where}: expressions are read-only, no assignment")
        return ""
    return text


def clean_key(value, budget: Budget, where: str) -> str:
    key = str(value or "").strip()
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,40}", key):
        budget.note(f"{where}: '{key}' is not a valid state key")
        return ""
    return key


def clean_steps(raw, budget: Budget, where: str) -> list:
    if not isinstance(raw, list):
        return []
    steps = []
    for item in raw[:20]:
        if not isinstance(item, dict):
            continue
        step: dict = {}
        if "set" in item:
            key = clean_key(item.get("set"), budget, where)
            expr = clean_expr(item.get("to"), budget, where)
            if key and expr:
                step = {"set": key, "to": expr}
        elif "inc" in item:
            key = clean_key(item.get("inc"), budget, where)
            expr = clean_expr(item.get("by", "1"), budget, where) or "1"
            if key:
                step = {"inc": key, "by": expr}
        elif "toggle" in item:
            key = clean_key(item.get("toggle"), budget, where)
            if key:
                step = {"toggle": key}
        elif "notify" in item:
            title = clean_expr(item.get("notify"), budget, where)
            if title:
                step = {"notify": title,
                        "body": clean_expr(item.get("body"), budget, where)}
        elif "copy" in item:
            expr = clean_expr(item.get("copy"), budget, where)
            if expr:
                step = {"copy": expr}
        elif "open" in item:
            expr = clean_expr(item.get("open"), budget, where)
            if expr:
                step = {"open": expr}
        elif "refetch" in item:
            step = {"refetch": True}
        elif "if" in item:
            cond = clean_expr(item.get("if"), budget, where)
            inner = clean_steps(item.get("do"), budget, where)
            if cond and inner:
                step = {"if": cond, "do": inner}
        if step:
            steps.append(step)
    return steps


def clean_block(raw, budget: Budget, depth: int) -> dict | None:
    if not isinstance(raw, dict):
        return None
    if depth > MAX_DEPTH or budget.nodes >= MAX_NODES:
        return None
    kind = str(raw.get("t") or "").strip()
    if kind not in BLOCKS:
        budget.note(f"unknown block '{kind}'")
        return None
    budget.nodes += 1
    block: dict = {"t": kind}
    where = kind

    def expr(field: str, default: str = "") -> str:
        return clean_expr(raw.get(field, default), budget, where)

    if kind in ("row", "col", "grid", "card"):
        kids = []
        for child in (raw.get("kids") or [])[:24]:
            node = clean_block(child, budget, depth + 1)
            if node:
                kids.append(node)
        block["kids"] = kids
        if kind == "grid":
            block["cols"] = max(1, min(4, int(raw.get("cols") or 2)))
        if raw.get("align"):
            block["align"] = str(raw["align"])[:12]
    elif kind == "text":
        block["value"] = expr("value")
        block["style"] = str(raw.get("style") or "body")[:12]
        block["align"] = str(raw.get("align") or "left")[:8]
        block["color"] = str(raw.get("color") or "")[:12]
        block["wrap"] = bool(raw.get("wrap"))
    elif kind == "stat":
        block["value"] = expr("value")
        block["unit"] = expr("unit")
        block["caption"] = expr("caption")
        block["size"] = str(raw.get("size") or "m")[:2]
    elif kind == "button":
        block["label"] = expr("label")
        block["on"] = str(raw.get("on") or "")[:40]
        block["style"] = str(raw.get("style") or "pill")[:10]
    elif kind == "toggle":
        block["key"] = clean_key(raw.get("key"), budget, where)
        block["label"] = expr("label")
    elif kind == "slider":
        block["key"] = clean_key(raw.get("key"), budget, where)
        block["label"] = expr("label")
        block["min"] = float(raw.get("min") or 0)
        block["max"] = float(raw.get("max") if raw.get("max") is not None else 100)
        block["step"] = float(raw.get("step") or 1)
    elif kind == "field":
        block["key"] = clean_key(raw.get("key"), budget, where)
        block["placeholder"] = str(raw.get("placeholder") or "")[:40]
        block["on"] = str(raw.get("on") or "")[:40]
    elif kind in ("progress", "ring"):
        block["value"] = expr("value", "0")
        block["label"] = expr("label")
    elif kind == "dots":
        block["value"] = expr("value", "0")
        block["count"] = max(1, min(60, int(raw.get("count") or 10)))
        block["label"] = expr("label")
    elif kind == "bars":
        block["of"] = expr("of")
        block["value"] = expr("value", "it")
        block["limit"] = max(1, min(40, int(raw.get("limit") or 12)))
    elif kind == "list":
        block["of"] = expr("of")
        block["limit"] = max(1, min(20, int(raw.get("limit") or 5)))
        block["empty"] = expr("empty")
        kids = []
        for child in (raw.get("item") or [])[:10]:
            node = clean_block(child, budget, depth + 1)
            if node:
                kids.append(node)
        block["item"] = kids
    elif kind == "icon":
        block["glyph"] = expr("glyph")
        block["size"] = str(raw.get("size") or "m")[:2]
        block["color"] = str(raw.get("color") or "")[:12]
    elif kind == "image":
        block["src"] = expr("src")
        block["height"] = max(16, min(240, int(raw.get("height") or 64)))
        block["width"] = max(0, min(240, int(raw.get("width") or 0)))
        block["fit"] = "contain" if str(raw.get("fit") or "") == "contain" else "cover"
        block["round"] = str(raw.get("round") or "chip")[:6]
    elif kind == "spacer":
        block["size"] = max(0, min(60, int(raw.get("size") or 8)))
    # divider carries nothing
    return block


def clean_fetch(raw, budget: Budget) -> dict | None:
    if not isinstance(raw, dict):
        return None
    url = str(raw.get("url") or "").strip()
    if not url.startswith("https://"):
        if url:
            budget.note("fetch: only https URLs are allowed")
        return None
    if len(url) > 500 or re.search(r"[\s\"'`$\\]", url):
        budget.note("fetch: malformed URL")
        return None
    pick = str(raw.get("pick") or "").strip()
    if pick and not re.fullmatch(r"[A-Za-z0-9_.\[\]]{0,120}", pick):
        budget.note("fetch: malformed pick path")
        pick = ""
    # Fallback endpoints the model is unsure about. They are probed, then
    # dropped: what reaches the shell is the one URL that answered.
    spare = []
    for alt in (raw.get("candidates") or [])[:5]:
        text = str(alt or "").strip()
        if (text.startswith("https://") and len(text) <= 500
                and not re.search(r"[\s\"'`$\\]", text) and text != url):
            spare.append(text)
    out_fetch = {
        "url": url,
        "pick": pick,
        "every": max(60, min(86400, int(raw.get("every") or 900))),
    }
    if spare:
        out_fetch["candidates"] = spare
    return out_fetch


def validate(raw, keep_id: str = "") -> tuple[dict | None, list[str]]:
    budget = Budget()
    if not isinstance(raw, dict):
        return None, ["the model did not return an object"]

    name = str(raw.get("name") or "").strip()[:36] or "Untitled"
    body = []
    for child in (raw.get("body") or [])[:24]:
        node = clean_block(child, budget, 1)
        if node:
            body.append(node)
    if not body:
        return None, budget.errors or ["the app has no body"]

    state = {}
    raw_state = raw.get("state")
    if isinstance(raw_state, dict):
        for key, value in list(raw_state.items())[:24]:
            clean = clean_key(key, budget, "state")
            if clean and isinstance(value, (int, float, str, bool)):
                state[clean] = value if not isinstance(value, str) else value[:200]

    actions = {}
    raw_actions = raw.get("actions")
    if isinstance(raw_actions, dict):
        for key, value in list(raw_actions.items())[:16]:
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,40}", str(key)):
                continue
            steps = clean_steps(value, budget, f"action {key}")
            if steps:
                actions[str(key)] = steps

    sources = [s for s in (raw.get("sources") or []) if s in SOURCES][:8]
    fetch = clean_fetch(raw.get("fetch"), budget)
    if fetch and "net" not in sources:
        sources.append("net")

    home = clean_host(raw.get("home"))
    spec = {
        "id": keep_id or slug(name),
        "name": name,
        "icon": str(raw.get("icon") or "󰀻")[:4],
        "size": str(raw.get("size") or "m")[:2],
        "sources": sources,
        "state": state,
        "body": body,
        "actions": actions,
        "tick": clean_steps(raw.get("tick"), budget, "tick"),
    }
    if fetch:
        spec["fetch"] = fetch
    if home:
        spec["home"] = home
    return spec, budget.errors


# ── The prompt ───────────────────────────────────────────────────────────

SCHEMA_DOC = """You write ONE mini app for a Nothing OS desktop shell, as JSON only.
The shell renders a fixed set of blocks. There is no code: anything not in
this schema is dropped.

TOP LEVEL
{
  "name": "<=36 chars",
  "icon": "<one Nerd Font glyph>",
  "size": "s" | "m" | "l",
  "sources": ["time","weather","sys","media","net","vault","notify"],
  "state": { "key": <number|string|bool> },     defaults, persisted
  "fetch": { "url": "https://...", "pick": "a.b.c", "every": <seconds> },
  "home": "<host>",                              see NETWORK below
  "body": [ <block>, ... ],
  "actions": { "name": [ <step>, ... ] },
  "tick": [ <step>, ... ]                        run once a second
}

BLOCKS  (field "t" picks the block)
  {"t":"text","value":<expr>,"style":"display|title|body|label|mono","align":"left|center|right","color":"red|dim|faint","wrap":bool}
  {"t":"stat","value":<expr>,"unit":<expr>,"caption":<expr>,"size":"s|m|l"}
  {"t":"row","kids":[...]}          horizontal
  {"t":"col","kids":[...]}          vertical
  {"t":"grid","kids":[...],"cols":2}
  {"t":"card","kids":[...]}         inner panel
  {"t":"button","label":<expr>,"on":"<action name>","style":"pill|square"}
  {"t":"toggle","key":"<state key>","label":<expr>}
  {"t":"slider","key":"<state key>","label":<expr>,"min":0,"max":100,"step":1}
  {"t":"field","key":"<state key>","placeholder":"...","on":"<action name>"}
  {"t":"progress","value":<expr 0..1>,"label":<expr>}
  {"t":"ring","value":<expr 0..1>,"label":<expr>}
  {"t":"dots","value":<expr 0..1>,"count":10,"label":<expr>}
  {"t":"bars","of":<expr array>,"value":"it","limit":12}
  {"t":"list","of":<expr array>,"limit":5,"empty":<expr>,"item":[<block>,...]}
  {"t":"image","src":<expr https URL>,"height":64,"width":0,"fit":"cover|contain","round":"chip|pill|tiny|none"}
        width 0 means fill the row. Feeds carry poster and thumbnail URLs:
        use them, a widget with artwork beats one without.
  {"t":"divider"}  {"t":"spacer","size":8}
  {"t":"icon","glyph":<expr>,"size":"s|m|l","color":"red|dim|faint"}

STEPS (inside actions and tick)
  {"set":"key","to":<expr>}   {"inc":"key","by":<expr>}   {"toggle":"key"}
  {"notify":<expr>,"body":<expr>}   {"copy":<expr>}   {"open":<expr>}
  {"refetch":true}   {"if":<expr>,"do":[<step>,...]}

EXPRESSIONS
JavaScript expressions, read-only, no assignment and no semicolon.
In scope:
  state.<key>            your persisted state
  data                   the fetch result after "pick" (null until it lands)
  time.h time.m time.s time.hhmm time.day time.dayShort time.dateLong
  time.week time.epoch   (epoch is seconds)
  weather.temp weather.hi weather.lo weather.desc weather.city
  sys.cpu sys.ram sys.gpu       (0..1)   sys.cpuTemp sys.gpuTemp   (celsius)
  media.title media.artist media.album media.playing media.active
  audio.volume audio.muted audio.micMuted          (volume 0..1)
  battery.percent battery.charging battery.present
  updates.count updates.urgent
  notifs.unread notifs.dnd notifs.count
  desktop.workspace desktop.monitor desktop.window
  net.kind net.name net.strength   (kind is wifi|ethernet|none, strength 0..100)
  vault.count vault.today vault.latest
  fmt.mmss(s) fmt.hms(s) fmt.pct(x) fmt.round(x,n) fmt.pad(n,w)
  fmt.date(iso) fmt.until(iso) fmt.ago(iso) fmt.num(x)
  Math, String, Number, Date, isNaN, parseInt, parseFloat
Inside a "list" item, `it` is the element and `i` its index.
Arrow functions ARE available: .map(), .filter(), .sort(), .reduce() and
.slice() all work, so sorting a feed or summing a column is fine. Loops
(for, while) are not, and nothing may be assigned.

RULES
- Return JSON and nothing else. No markdown fence, no comment.
- Keep it small: one screen, no scrolling, roughly 3 to 8 blocks.
- Prefer one "stat" as the focal point. That is the Nothing look.
- Every "on" must name a key that exists in "actions".
- Every "key" must exist in "state".
- Guard fetched data: it is null before the first response. Write
  (data && data[0] ? data[0].x : "-"), never data[0].x on its own.
- Use "tick" only when the app genuinely counts, and guard it with "if".
- Text is English, short, uppercase for captions.

NETWORK
Any public https JSON API is allowed. You are not limited to a list.
Think about which service actually publishes the data being asked for,
and reach for the one that needs no key, no token and no POST body.

Go to the source. When the request names a site, a forum, a community
or a brand's own space, that site is the answer, not someone writing
about it. Put its host in "home" (for example "nothing.community") and
the site's own API is probed for you and preferred over anything else.
Forums and CMSes publish JSON at well-known paths: Flarum at
/api/discussions, Discourse at /latest.json, NodeBB at /api/recent,
WordPress at /wp-json/wp/v2/posts. Set "home" whenever a site is named,
even if you are unsure it has an API. An RSS-to-JSON proxy or a
third-party blog is the fallback for when the site itself publishes
nothing usable, never the first choice.

You will be checked. Every URL you write is fetched for real before the
app is saved. So:
  - put your best guess in fetch.url
  - put two or three genuine alternatives in fetch.candidates, from
    different providers, whenever you are not certain the first is alive
  - if none of them answers you will be asked again with the errors
  - once one answers you will be shown the response it really returns,
    and you rewrite pick and every field name against that

Never invent a field name to fill a gap. If the response shape is given
to you, use only names that appear in it.

For anything meant to show what is new, two rules. Pick a publisher that
actually posts often: a real feed that went quiet a fortnight ago fails
the app just as surely as a broken URL, and the freshness of whatever
you choose is checked. And never trust the order items arrive in. Sort
by the date field yourself before taking the first one, for instance
  data.slice().sort((a, b) => new Date(b.pubDate) - new Date(a.pubDate))
`new` is not available in expressions, so use Date.parse(x) instead:
  data.slice().sort((a, b) => Date.parse(b.pubDate) - Date.parse(a.pubDate))

Endpoints known to answer today, as a sense of the shape of a good one:
  F1 schedule    https://api.jolpi.ca/ergast/f1/current/next.json
                 pick MRData.RaceTable.Races
  F1 standings   https://api.jolpi.ca/ergast/f1/current/driverStandings.json
                 pick MRData.StandingsTable.StandingsLists[0].DriverStandings
  Weather        https://api.open-meteo.com/v1/forecast?latitude=48.85&longitude=2.35&current=temperature_2m
                 pick current
  Currency       https://api.frankfurter.app/latest?from=EUR&to=USD
                 pick rates
  Crypto         https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=eur
                 pick bitcoin
  RSS as JSON    a fallback only, when the site has no JSON of its own
                 https://api.rss2json.com/v1/api.json?rss_url=<url-encoded feed>
                 pick items. Check the wrapped feed is a real one: a tag
                 path that 404s comes back as an error here, not as news.
                 Fresh tech feeds: androidauthority.com/tag/<x>/feed/ and
                 gsmarena.com/rss-news-reviews.php3
  Any sport      https://www.thesportsdb.com/api/v1/json/3/eventsnextleague.php?id=<leagueId>
                 pick events. Covers most leagues and needs no key. Known
                 ids: MotoGP 4407, Formula 1 4370, NBA 4387, NFL 4391,
                 Premier League 4328, La Liga 4335, NHL 4380.
                 Season schedule: .../eventsseason.php?id=<leagueId>&s=2026
  Holidays       https://date.nager.at/api/v3/NextPublicHolidays/FR
  Anime          https://kitsu.app/api/edge/anime?sort=-userCount&page[limit]=5
                 pick data
  GitHub repo    https://api.github.com/repos/OWNER/NAME
"""

EXAMPLE = """EXAMPLE, a tea timer:
{"name":"Tea Timer","icon":"\\udb80\\udd46","size":"m","sources":["notify"],
 "state":{"left":0,"total":120,"running":false},
 "body":[
  {"t":"stat","value":"fmt.mmss(state.left)","caption":"'REMAINING'","size":"l"},
  {"t":"progress","value":"state.total > 0 ? 1 - state.left / state.total : 0"},
  {"t":"row","kids":[
    {"t":"button","label":"'GREEN 2:00'","on":"green"},
    {"t":"button","label":"'BLACK 4:00'","on":"black"},
    {"t":"button","label":"state.running ? 'STOP' : 'GO'","on":"toggleRun"}]}],
 "actions":{
  "green":[{"set":"total","to":"120"},{"set":"left","to":"120"},{"set":"running","to":"true"}],
  "black":[{"set":"total","to":"240"},{"set":"left","to":"240"},{"set":"running","to":"true"}],
  "toggleRun":[{"toggle":"running"}]},
 "tick":[{"if":"state.running && state.left > 0","do":[{"inc":"left","by":"-1"}]},
         {"if":"state.running && state.left === 0","do":[
            {"set":"running","to":"false"},
            {"notify":"'Tea is ready'","body":"'Timer finished'"}]}]}
"""


def build_prompt(request: str, current: dict | None = None) -> str:
    if current is None:
        return (
            SCHEMA_DOC + "\n" + EXAMPLE + "\n"
            "Write the app the user asks for.\n"
            f"User: {request}\n"
        )
    trimmed = dict(current)
    trimmed.pop("id", None)
    return (
        SCHEMA_DOC + "\n"
        "Here is the current app. Apply the requested change and return the\n"
        "COMPLETE new app, same schema, not a diff.\n"
        f"Current:\n{json.dumps(trimmed, ensure_ascii=False)}\n"
        f"Change: {request}\n"
    )


def ollama_text(prompt: str, model: str, timeout: int = 120) -> tuple[str, str]:
    if not have("ollama"):
        return "", "ollama is not installed"
    try:
        raw = subprocess.check_output(
            ["ollama", "run", model, prompt],
            timeout=timeout, stderr=subprocess.DEVNULL)
        return raw.decode("utf-8", "replace").strip(), ""
    except subprocess.TimeoutExpired:
        return "", "ollama timed out"
    except (subprocess.SubprocessError, OSError):
        return "", "ollama failed"


def ask_model(prompt: str) -> tuple[str, str]:
    env = read_env()
    backend = (os.environ.get("NOTHING_MIND_BACKEND")
               or env.get("BACKEND") or "stub").strip().lower()
    if backend == "ollama":
        return ollama_text(prompt, env.get("MODEL") or "llama3.2")
    if backend == "gemini":
        # An app prompt carries the schema and a field catalogue, so it is
        # far bigger than an Essential Search question and draws the
        # occasional 503. Backing off beats handing the panel a failure
        # for something that clears in a few seconds.
        for pause in (0, 6, 15):
            if pause:
                time.sleep(pause)
            text, err = gemini_text(prompt, env, 90)
            if text or not ("busy" in err.lower() or "tap Ask again" in err):
                break
        if "tap Ask again" in err:
            err = "Gemini is busy. Try again in a moment"
        return text, err
    return "", "Pick Gemini or Ollama in Essential settings first"


def draft(prompt: str, keep_id: str) -> tuple[dict | None, str]:
    """One model call, one repair call if the spec did not validate."""
    raw, err = ask_model(prompt)
    if err:
        return None, err
    spec, errors = validate(parse_json_obj(raw), keep_id)
    if spec:
        return spec, ""
    repair = (
        prompt + "\nYour previous answer was rejected:\n"
        + "\n".join(f"- {e}" for e in errors[:8])
        + "\nReturn a corrected complete app, JSON only.\n"
    )
    raw, err = ask_model(repair)
    if err:
        return None, err
    spec, errors = validate(parse_json_obj(raw), keep_id)
    if spec:
        return spec, ""
    return None, (errors[0] if errors else "the model did not return a usable app")


def ground(spec: dict, request: str, keep_id: str) -> tuple[dict, str]:
    """Point a networked app at an endpoint that actually answers.

    The URL is fetched for real. If nothing answers, the model gets the
    failures and picks different ones. Once something answers, it is shown
    the response it will really receive, so `pick` and every field name are
    written against the feed rather than against its memory of the feed."""
    fetch = spec.get("fetch")
    if not fetch:
        return spec, ""

    url, payload, failures = probe_fetch(fetch)

    if not url:
        retry = (
            SCHEMA_DOC + "\n"
            "None of these endpoints answered:\n"
            + "\n".join(f"- {f}" for f in failures[:6]) + "\n"
            "Pick DIFFERENT public JSON APIs for this app. Put your best "
            "guess in fetch.url and two or three more in fetch.candidates. "
            "Prefer APIs that need no key and no CORS proxy. Return the "
            "complete app, JSON only.\n"
            f"App wanted: {request}\n"
            f"Your previous attempt:\n{json.dumps(spec, ensure_ascii=False)}\n"
        )
        for _ in range(2):
            retried, err = draft(retry, keep_id)
            if not (retried and retried.get("fetch")):
                break
            url, payload, more = probe_fetch(retried["fetch"])
            failures = failures + more
            if url:
                spec = retried
                fetch = spec["fetch"]
                break
            retry = (
                SCHEMA_DOC + "\n"
                "Still nothing. These have now all failed:\n"
                + "\n".join(f"- {f}" for f in failures[:10]) + "\n"
                "Try providers you have not tried yet. Avoid raw file paths "
                "on code hosting, they rot. Prefer a documented public API.\n"
                f"App wanted: {request}\n"
            )
        if not url:
            spec.get("fetch", {}).pop("candidates", None)
            return spec, "no endpoint answered: " + (failures[0] if failures else "unknown")

    picked = json_pick(payload, fetch.get("pick") or "")
    gone = missing_fields(spec, picked)
    empty = picked is None or (isinstance(picked, (list, dict)) and len(picked) == 0)

    if not gone and not empty:
        fetch["url"] = url
        fetch.pop("candidates", None)
        return spec, ""

    def settle(candidate: dict) -> dict:
        """Force the endpoint we proved works onto a spec."""
        got = candidate.get("fetch") or {}
        got["url"] = url
        got.setdefault("pick", fetch.get("pick", ""))
        got.setdefault("every", fetch.get("every", 900))
        got.pop("candidates", None)
        candidate["fetch"] = got
        return candidate

    element = picked[0] if isinstance(picked, list) and picked else picked
    catalogue = "\n".join(
        "  it." + line for line in flat_paths(element)) if isinstance(element, dict) else ""
    if isinstance(picked, list):
        catalogue = (f"`data` is an array of {len(picked)} items. Inside a list "
                     "block, `it` is one item and these are its readable "
                     f"paths:\n{catalogue}")
    else:
        catalogue = catalogue.replace("  it.", "  data.")
        catalogue = f"`data` is an object with these readable paths:\n{catalogue}"

    # Two goes at it. The model reaching for another API's field names is
    # the single most common way a networked app comes out looking fine
    # and rendering blank, so the fix is checked rather than assumed.
    attempt = spec
    for _ in range(2):
        trouble = []
        if empty:
            trouble.append(f'pick "{fetch.get("pick")}" resolved to nothing')
        for field in gone:
            trouble.append(f"{field} does not exist in the response")

        fix = (
            SCHEMA_DOC + "\n"
            f"This endpoint answers and is the one to use:\n{url}\n\n"
            f"{catalogue}\n\n"
            f"Raw shape, for context:\n{shape_of(payload)}\n\n"
            "What is wrong with your draft:\n"
            + "\n".join(f"- {t}" for t in trouble[:8]) + "\n\n"
            "Those field names belong to a different API. Rewrite the "
            "complete app against the response above. Set fetch.url to "
            f'exactly "{url}". Use ONLY paths from the list above, copied '
            "character for character. Do not fall back to a placeholder "
            "like 'Untitled': if you need a title, one of the listed paths "
            "is the title. Return JSON only.\n"
            f"App wanted: {request}\n"
        )
        fixed, err = draft(fix, keep_id)
        if not fixed:
            return settle(attempt), f"could not correct the field names ({err})"

        attempt = settle(fixed)
        picked = json_pick(payload, attempt["fetch"].get("pick") or "")
        gone = missing_fields(attempt, picked)
        empty = picked is None or (isinstance(picked, (list, dict)) and len(picked) == 0)
        if not gone and not empty:
            return attempt, ""

    return attempt, "some fields do not exist in the feed: " + ", ".join(gone[:3])


# Words that mean the user wants what is happening now. A feed whose
# freshest entry is weeks old fails them even when it is on topic.
RECENCY = re.compile(
    r"\b(news|latest|recent|update|updates|feed|headline|headlines|blog|"
    r"post|posts|communit|release|releases|actualit|actu|nouveaut|derni)",
    re.IGNORECASE)

DATE_KEYS = re.compile(
    r"(date|time|published|pubdate|created|updated|timestamp|when|start)",
    re.IGNORECASE)


def parse_any_date(value):
    """ISO, RFC 2822 and epoch seconds, which is what feeds actually use."""
    if isinstance(value, (int, float)):
        if 1_500_000_000 < value < 2_500_000_000:
            return datetime.fromtimestamp(value)
        return None
    text = str(value or "").strip()
    if not text or len(text) > 64:
        return None
    try:
        cleaned = text.replace("Z", "+00:00").replace(" ", "T", 1) \
            if re.match(r"^\d{4}-\d{2}-\d{2}[ T]", text) else text
        return datetime.fromisoformat(cleaned).replace(tzinfo=None)
    except ValueError:
        pass
    try:
        return parsedate_to_datetime(text).replace(tzinfo=None)
    except (TypeError, ValueError):
        return None


def newest_age_days(payload) -> float | None:
    """Age of the freshest dated entry anywhere in the payload."""
    best = None

    def walk(node, depth=0):
        nonlocal best
        if depth > 4:
            return
        if isinstance(node, dict):
            for key, value in node.items():
                if DATE_KEYS.search(key):
                    when = parse_any_date(value)
                    if when and (best is None or when > best):
                        best = when
                else:
                    walk(value, depth + 1)
        elif isinstance(node, list):
            for item in node[:20]:
                walk(item, depth + 1)

    walk(payload)
    if best is None:
        return None
    return (datetime.now() - best).total_seconds() / 86400.0


def freshness_check(spec: dict, request: str) -> tuple[bool, str]:
    """Asked for news, given a feed that stopped publishing.

    9to5google's Nothing tag is a real source with real fields and its
    newest post was a fortnight old, so every other check passed while
    the widget showed stale headlines. Costs no model call."""
    if not RECENCY.search(request or ""):
        return True, ""
    fetch = spec.get("fetch") or {}
    if not fetch.get("url"):
        return True, ""
    payload, err = http_get(fetch["url"])
    if err:
        return True, ""
    age = newest_age_days(json_pick(payload, fetch.get("pick") or ""))
    if age is None or age <= 6:
        return True, ""
    return False, (f"the freshest entry in that feed is {int(age)} days old, "
                   "so the source has gone quiet")


def subject_check(spec: dict, request: str) -> tuple[bool, str]:
    """Is the feed even about the right thing?

    `ground()` only proves an endpoint answers and that the fields exist.
    Asked for MotoGP, the model reached for the F1 URL out of the examples
    above and every mechanical check passed. Nothing but a reading of the
    data catches that, so the model is made to read it back."""
    fetch = spec.get("fetch") or {}
    url = fetch.get("url") or ""
    if not url:
        return True, ""
    payload, err = http_get(url)
    if err:
        return True, ""
    sample = json.dumps(summarize(json_pick(payload, fetch.get("pick") or "")),
                        ensure_ascii=False)[:1400]
    prompt = (
        "A user asked for this desktop widget:\n"
        f'  "{request}"\n\n'
        "The app that was written reads this endpoint:\n"
        f"  {url}\n"
        "and that endpoint returns:\n"
        f"{sample}\n\n"
        "Is this data about the SUBJECT the user asked for? Answer false if "
        "it covers a different sport, series, league, topic, place or entity "
        "than the one requested, even when the shape of the data would fit "
        "the widget. Judging the subject is the whole job here.\n"
        'Return JSON only: {"ok": true|false, "why": "one short sentence"}'
    )
    raw, err = ask_model(prompt)
    if err:
        return True, ""
    data = parse_json_obj(raw) or {}
    if "ok" not in data:
        return True, ""
    return bool(data.get("ok")), str(data.get("why") or "")[:200]


def prefer_official(spec: dict, request: str, keep_id: str) -> dict:
    """When the user named a site, that site is the source.

    An RSS proxy over a third-party blog can be on topic and fresh and
    still be the wrong thing entirely: asked for Nothing Community, the
    answer is nothing.community, not someone writing about it."""
    home = spec.get("home") or ""
    if not home:
        return spec
    if clean_host((spec.get("fetch") or {}).get("url", "")) == home:
        return spec

    url, payload, pick = discover_official(home)
    if not url:
        return spec

    picked = json_pick(payload, pick)
    element = picked[0] if isinstance(picked, list) and picked else picked
    catalogue = "\n".join("  it." + line for line in flat_paths(element)) \
        if isinstance(element, dict) else ""

    prompt = (
        SCHEMA_DOC + "\n"
        f"{home} publishes its own JSON API. That is the source for this "
        "app, not a proxy and not a third-party blog writing about it.\n"
        f"Endpoint: {url}\n"
        f'fetch.pick must be exactly: "{pick}"\n\n'
        f"`data` is an array of {len(picked)} items. Inside a list block "
        f"`it` is one of them, with these readable paths:\n{catalogue}\n\n"
        "Rewrite the complete app against this response. Use only paths "
        "from the list, copied character for character. Return JSON only.\n"
        f"App wanted: {request}\n"
    )
    fixed, err = draft(prompt, keep_id)
    if not fixed:
        return spec

    got = fixed.get("fetch") or {}
    got["url"] = url
    got["pick"] = pick
    got.setdefault("every", (spec.get("fetch") or {}).get("every", 900))
    got.pop("candidates", None)
    fixed["fetch"] = got
    fixed["home"] = home
    return fixed


def quality_gate(spec: dict, request: str) -> str:
    """Everything that can be wrong with an app whose plumbing works.

    `ground()` proves the endpoint answers and the field names exist. That
    leaves the two ways a technically correct app is still useless: right
    shape, wrong subject; and right subject, dead source."""
    ok, why = subject_check(spec, request)
    if not ok:
        return why or "the data is not about what was asked for"
    ok, why = freshness_check(spec, request)
    if not ok:
        return why
    return ""


def generate(request: str, current: dict | None, keep_id: str) -> tuple[dict | None, str]:
    base = build_prompt(request, current)
    spec, err = draft(base, keep_id)
    if not spec:
        return None, err
    spec = prefer_official(spec, request, keep_id)
    spec, note = ground(spec, request, keep_id)
    if note or not spec.get("fetch"):
        return spec, note and "NOTE:" + note

    complaint = quality_gate(spec, request)
    if not complaint:
        return spec, ""

    wrong = spec.get("fetch", {}).get("url", "")
    retry = (
        base + "\nYour previous attempt used a source that does not work "
        "for this app.\n"
        f"- it read {wrong}\n"
        f"- {complaint}\n"
        "Pick a different source. Do not reuse an endpoint from the "
        "examples because its shape is convenient, and for anything "
        "described as news, latest or a feed, prefer a publisher that "
        "posts often. Offer several candidates. If no public JSON API "
        "covers this, build the app without a feed and say so in a "
        "caption rather than showing stale or unrelated data.\n"
    )
    second, err = draft(retry, keep_id)
    if not second:
        return spec, "NOTE:" + complaint

    second, note2 = ground(second, request, keep_id)
    # A replacement that reaches nothing is worse than a source that is
    # merely slow. Keep what worked and say what is wrong with it, rather
    # than swapping a stale feed for a dead URL.
    if note2 or not second.get("fetch"):
        return spec, "NOTE:" + complaint

    again = quality_gate(second, request)
    if not again:
        return second, ""
    # The second try is no better on the merits either: prefer whichever
    # of the two at least answers, which is the one we started with.
    return spec, "NOTE:" + complaint


# ── The site's own API ───────────────────────────────────────────────────
# Asked for the latest from Nothing Community, the model reached for an
# RSS-to-JSON proxy pointed at a third-party blog. That answers, is on
# topic and is fresh, so every check passed, and it still was not the
# thing asked for. Forums and CMSes expose their own JSON at well-known
# paths, so when the request names a site those are probed directly.

OFFICIAL_PATHS = [
    ("/api/discussions?sort=-createdAt", "data"),          # Flarum
    ("/latest.json", "topic_list.topics"),                 # Discourse
    ("/api/recent", "topics"),                             # NodeBB
    ("/wp-json/wp/v2/posts?per_page=10", ""),              # WordPress
    ("/api/v1/posts", "data"),
    ("/api/posts", "data"),
]


def clean_host(value: str) -> str:
    host = str(value or "").strip().lower()
    host = re.sub(r"^https?://", "", host).split("/")[0].split("?")[0]
    if not re.fullmatch(r"[a-z0-9.-]{3,80}\.[a-z]{2,}", host):
        return ""
    return host


def discover_official(host: str) -> tuple[str, object, str]:
    """First well-known API path on this host that yields real items."""
    for path, pick in OFFICIAL_PATHS:
        url = f"https://{host}{path}"
        payload, err = http_get(url, timeout=10)
        if err:
            continue
        picked = json_pick(payload, pick)
        if isinstance(picked, list) and picked:
            return url, payload, pick
    return "", None, ""


# ── Endpoint discovery ───────────────────────────────────────────────────
# The model writes a URL from memory, and memory goes stale: Jikan was a
# fine anime API until it started answering 504 to everything. So nothing
# it proposes is trusted. Each candidate is fetched for real, and the one
# that answers is handed back to the model as an actual response shape,
# which is also what stops it inventing field names.

# Mozilla-compatible token, still naming the app: plenty of sites
# reject a bare tool agent, and the probe must be able to reach
# exactly what the shell will reach.
UA = "Mozilla/5.0 (compatible; nothing-essential-apps/1)"
# JSON:API feeds refuse a bare application/json with a 406.
ACCEPT = "application/json, application/vnd.api+json, */*"


def http_get(url: str, timeout: int = 12) -> tuple[object, str]:
    req = urllib.request.Request(url, headers={
        "Accept": ACCEPT,
        "User-Agent": UA,
    })
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read(400_000).decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        return None, f"HTTP {exc.code}"
    except (urllib.error.URLError, TimeoutError):
        return None, "unreachable"
    except (OSError, ValueError):
        return None, "read failed"
    text = raw.strip()
    if not text:
        return None, "empty response"
    if text[0] not in "[{":
        return None, "not JSON (looks like HTML)"
    try:
        # strict=False: real feeds carry raw newlines and tabs inside
        # strings, and rejecting those threw away endpoints that work.
        return json.loads(text, strict=False), ""
    except json.JSONDecodeError:
        return None, "malformed JSON"


def json_pick(root, path: str):
    """Same walk as expr.js pick(), so a path that works here works there."""
    if not path:
        return root
    cur = root
    for part in re.sub(r"\[(\d+)\]", r".\1", str(path)).split("."):
        if part == "":
            continue
        if isinstance(cur, list):
            try:
                cur = cur[int(part)]
                continue
            except (ValueError, IndexError):
                return None
        if not isinstance(cur, dict):
            return None
        cur = cur.get(part)
    return cur


def summarize(value, depth: int = 0):
    """Structure plus a few real values. Concrete samples are what keep
    the model from writing camelCase where the feed uses snake_case."""
    if depth > 4:
        return "..."
    if isinstance(value, dict):
        out = {}
        for key in list(value.keys())[:22]:
            out[key] = summarize(value[key], depth + 1)
        if len(value) > 22:
            out["..."] = f"{len(value) - 22} more keys"
        return out
    if isinstance(value, list):
        if not value:
            return []
        return [summarize(value[0], depth + 1), f"...{len(value)} items total"]
    if isinstance(value, str):
        return value[:70] + ("..." if len(value) > 70 else "")
    return value


def flat_paths(value, prefix: str = "", depth: int = 0, out: list | None = None) -> list:
    """Every readable path, with a real sample value.

    A truncated JSON dump makes the model guess where a field sits. A flat
    list of `it.attributes.canonicalTitle = "One Piece"` does not."""
    if out is None:
        out = []
    if len(out) >= 120 or depth > 3:
        return out
    if isinstance(value, dict):
        # A dict keyed by numbers is a data map, not a set of fields.
        # Kitsu's ratingFrequencies has 19 of them and would push the
        # episode count, the thing actually being asked for, off the list.
        keys = list(value.keys())
        if len(keys) > 4 and all(str(k).lstrip("-").isdigit() for k in keys):
            out.append(f"{prefix} = <map of {len(keys)} numeric keys>")
            return out
        for key, sub in list(value.items())[:40]:
            path = f"{prefix}.{key}" if prefix else key
            if isinstance(sub, (dict, list)):
                flat_paths(sub, path, depth + 1, out)
            else:
                sample = sub
                if isinstance(sample, str):
                    sample = sample[:48] + ("…" if len(sample) > 48 else "")
                out.append(f"{path} = {json.dumps(sample, ensure_ascii=False)}")
    elif isinstance(value, list) and value:
        flat_paths(value[0], f"{prefix}[0]", depth + 1, out)
    return out


def shape_of(payload) -> str:
    text = json.dumps(summarize(payload), ensure_ascii=False, indent=1)
    return text[:3000] + ("\n...(truncated)" if len(text) > 3000 else "")


def expressions_of(spec: dict) -> list:
    """Every expression string in a spec, wherever it lives."""
    found = []

    def walk(node):
        if isinstance(node, dict):
            for key, val in node.items():
                if isinstance(val, str) and key in (
                        "value", "caption", "unit", "label", "glyph", "empty",
                        "of", "to", "by", "if", "notify", "body", "copy", "open"):
                    found.append(val)
                else:
                    walk(val)
        elif isinstance(node, list):
            for item in node:
                walk(item)

    walk(spec.get("body"))
    walk(spec.get("actions"))
    walk(spec.get("tick"))
    return found


def missing_fields(spec: dict, picked) -> list:
    """Field paths the spec reads off the feed that the feed does not have."""
    sample = picked[0] if isinstance(picked, list) and picked else picked
    if not isinstance(sample, dict):
        return []
    gone = []
    for expr in expressions_of(spec):
        for prefix, base in (("it", sample), ("data", picked)):
            for match in re.finditer(
                    rf"\b{prefix}(?:\[(\d+)\])?\.([A-Za-z_][\w.]*)", expr):
                index, path = match.group(1), match.group(2)
                root = base
                if index is not None:
                    if not isinstance(root, list) or int(index) >= len(root):
                        continue
                    root = root[int(index)]
                # Only the first hop is checked: deeper misses are usually
                # a consequence of the first, and a false alarm costs a
                # needless model call.
                head = path.split(".")[0]
                if isinstance(root, dict) and head not in root:
                    gone.append(f"{prefix}.{path}")
    seen = []
    for item in gone:
        if item not in seen:
            seen.append(item)
    return seen[:8]


def probe_fetch(fetch: dict) -> tuple[str, object, list]:
    """Try every candidate. Returns (working url, payload, failures)."""
    urls = [fetch.get("url") or ""] + list(fetch.get("candidates") or [])
    failures = []
    for url in urls:
        if not url:
            continue
        payload, err = http_get(url)
        if err:
            failures.append(f"{url} -> {err}")
            continue
        return url, payload, failures
    return "", None, failures


# ── Commands ─────────────────────────────────────────────────────────────

def cmd_list() -> None:
    ensure()
    items = []
    for path in DIR.glob("*.json"):
        data = read_json(path)
        if not isinstance(data, dict) or not data.get("id"):
            continue
        data["saved"] = load_state(data["id"])
        items.append(data)
    items.sort(key=lambda s: str(s.get("created") or ""), reverse=True)
    sys.stdout.write(json.dumps(items[:CAP], ensure_ascii=False) + "\n")


def cmd_get(app_id: str) -> None:
    spec = load_spec(app_id)
    if not spec:
        fail("no such app")
    spec["saved"] = load_state(app_id)
    sys.stdout.write(json.dumps(spec, ensure_ascii=False) + "\n")


def cmd_gen(request: str) -> None:
    request = (request or "").strip()
    if not request:
        fail("describe the app first")
    spec, err = generate(request, None, "")
    if not spec:
        fail(err)
    note = err[5:] if err.startswith("NOTE:") else ""
    spec["prompt"] = request[:600]
    spec["created"] = now()
    spec["version"] = 1
    spec["history"] = [request[:200]]
    save_spec(spec)
    archive(spec)
    save_state(spec["id"], dict(spec.get("state") or {}))
    out({"ok": True, "id": spec["id"], "name": spec["name"], "note": note})


def cmd_refine(app_id: str, request: str) -> None:
    current = load_spec(app_id)
    if not current:
        fail("no such app")
    request = (request or "").strip()
    if not request:
        fail("describe the change first")
    spec, err = generate(request, current, app_id)
    if not spec:
        fail(err)
    note = err[5:] if err.startswith("NOTE:") else ""
    spec["prompt"] = current.get("prompt") or request[:600]
    spec["created"] = current.get("created") or now()
    spec["version"] = int(current.get("version") or 1) + 1
    spec["history"] = (current.get("history") or [])[-9:] + [request[:200]]
    save_spec(spec)
    archive(spec)
    # Keep the state the user built up, minus keys the new spec dropped.
    saved = load_state(app_id)
    fresh = dict(spec.get("state") or {})
    for key in fresh:
        if key in saved:
            fresh[key] = saved[key]
    save_state(app_id, fresh)
    out({"ok": True, "id": spec["id"], "name": spec["name"],
         "version": spec["version"], "note": note})


def cmd_put(app_id: str, payload: str) -> None:
    """Save a hand-edited spec. It goes through the same validator as a
    generated one: editing the JSON must not be a way around it."""
    current = load_spec(app_id)
    if not current:
        fail("no such app")
    try:
        raw = json.loads(payload or "")
    except json.JSONDecodeError as exc:
        fail(f"not valid JSON: {exc.msg} at line {exc.lineno}")
        return
    spec, errors = validate(raw, app_id)
    if not spec:
        fail(errors[0] if errors else "the app did not validate")
        return
    if errors:
        fail(errors[0])
        return
    spec["prompt"] = current.get("prompt") or ""
    spec["created"] = current.get("created") or now()
    spec["version"] = int(current.get("version") or 1) + 1
    spec["history"] = (current.get("history") or [])[-9:] + ["edited by hand"]
    save_spec(spec)
    archive(spec)
    saved = load_state(app_id)
    fresh = dict(spec.get("state") or {})
    for key in fresh:
        if key in saved:
            fresh[key] = saved[key]
    save_state(app_id, fresh)
    out({"ok": True, "version": spec["version"]})


def cmd_remove(app_id: str) -> None:
    spec_path(app_id).unlink(missing_ok=True)
    (STATE / f"{app_id}.json").unlink(missing_ok=True)
    shutil.rmtree(VERSIONS / app_id, ignore_errors=True)
    out({"ok": True})


def cmd_rename(app_id: str, name: str) -> None:
    spec = load_spec(app_id)
    if not spec:
        fail("no such app")
    clean = (name or "").strip()[:36]
    if not clean:
        fail("empty name")
    spec["name"] = clean
    save_spec(spec)
    out({"ok": True, "name": clean})


def cmd_state(app_id: str, payload: str) -> None:
    spec = load_spec(app_id)
    if not spec:
        fail("no such app")
    try:
        patch = json.loads(payload or "{}")
    except json.JSONDecodeError:
        fail("bad state payload")
        return
    if not isinstance(patch, dict):
        fail("bad state payload")
        return
    saved = load_state(app_id)
    allowed = set((spec.get("state") or {}).keys())
    for key, value in patch.items():
        if key in allowed and isinstance(value, (int, float, str, bool)):
            saved[key] = value if not isinstance(value, str) else value[:400]
    save_state(app_id, saved)
    out({"ok": True})


def cmd_reset(app_id: str) -> None:
    spec = load_spec(app_id)
    if not spec:
        fail("no such app")
    save_state(app_id, dict(spec.get("state") or {}))
    out({"ok": True})


def cmd_versions(app_id: str) -> None:
    folder = VERSIONS / app_id
    nums = []
    if folder.exists():
        for path in folder.glob("*.json"):
            try:
                nums.append(int(path.stem))
            except ValueError:
                continue
    out({"ok": True, "versions": sorted(nums)})


def cmd_revert(app_id: str, number: int) -> None:
    old = read_json(VERSIONS / app_id / f"{number}.json")
    if not isinstance(old, dict):
        fail("no such version")
        return
    current = load_spec(app_id) or {}
    spec = dict(old)
    spec["id"] = app_id
    spec["version"] = int(current.get("version") or 1) + 1
    spec["history"] = (current.get("history") or []) + [f"revert to v{number}"]
    save_spec(spec)
    archive(spec)
    out({"ok": True, "version": spec["version"]})


def bundled() -> list[Path]:
    if not PRESETS.exists():
        return []
    return sorted(PRESETS.glob("*.json"))


def install_preset(path: Path) -> str | None:
    data = read_json(path)
    if not isinstance(data, dict):
        return None
    spec, _ = validate(data, data.get("id") or slug(data.get("name") or path.stem))
    if not spec:
        return None
    spec["prompt"] = str(data.get("prompt") or "")[:600]
    spec["created"] = now()
    spec["version"] = 1
    spec["preset"] = path.stem
    save_spec(spec)
    archive(spec)
    save_state(spec["id"], dict(spec.get("state") or {}))
    return spec["id"]


def cmd_seed() -> None:
    ensure()
    if SEEDED.exists():
        out({"ok": True, "seeded": 0})
        return
    ids = [i for i in (install_preset(p) for p in bundled()) if i]
    SEEDED.write_text(now() + "\n", encoding="utf-8")
    out({"ok": True, "seeded": len(ids), "ids": ids})


def cmd_presets() -> None:
    items = []
    for path in bundled():
        data = read_json(path)
        if isinstance(data, dict):
            items.append({
                "file": path.stem,
                "name": data.get("name") or path.stem,
                "icon": data.get("icon") or "󰀻",
                "prompt": data.get("prompt") or "",
            })
    sys.stdout.write(json.dumps(items, ensure_ascii=False) + "\n")


def cmd_install(name: str) -> None:
    path = PRESETS / f"{name}.json"
    if not path.exists():
        fail("no such preset")
    app_id = install_preset(path)
    if not app_id:
        fail("preset did not validate")
    out({"ok": True, "id": app_id})


def main() -> None:
    args = sys.argv[1:]
    if not args:
        fail("usage: essential-app.py <command>", 2)
    cmd = args[0]
    rest = args[1:]

    if cmd == "list":
        cmd_list()
    elif cmd == "dir":
        ensure()
        print(str(DIR))
    elif cmd == "schema":
        print(SCHEMA_DOC)
    elif cmd == "get":
        cmd_get(rest[0] if rest else "")
    elif cmd == "gen":
        text = " ".join(rest).strip() or sys.stdin.read()
        cmd_gen(text)
    elif cmd == "refine":
        if not rest:
            fail("id required")
        text = " ".join(rest[1:]).strip() or sys.stdin.read()
        cmd_refine(rest[0], text)
    elif cmd == "put":
        if not rest:
            fail("id required")
        cmd_put(rest[0], sys.stdin.read())
    elif cmd == "remove":
        cmd_remove(rest[0] if rest else "")
    elif cmd == "rename":
        cmd_rename(rest[0] if rest else "", " ".join(rest[1:]))
    elif cmd == "state":
        if not rest:
            fail("id required")
        cmd_state(rest[0], sys.stdin.read())
    elif cmd == "reset":
        cmd_reset(rest[0] if rest else "")
    elif cmd == "versions":
        cmd_versions(rest[0] if rest else "")
    elif cmd == "revert":
        if len(rest) < 2:
            fail("id and version required")
        try:
            cmd_revert(rest[0], int(rest[1]))
        except ValueError:
            fail("bad version number")
    elif cmd == "seed":
        cmd_seed()
    elif cmd == "presets":
        cmd_presets()
    elif cmd == "install":
        cmd_install(rest[0] if rest else "")
    else:
        fail("unknown command: " + cmd, 2)


if __name__ == "__main__":
    main()
