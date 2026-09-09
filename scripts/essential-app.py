#!/usr/bin/env python3
"""Essential Apps: describe a widget, the model fills a Nothing-like tile.

A widget is a JSON spec, never code. The shell draws a closed set of
faces (stat, tracker, list, clock, media, note) or a custom block tree.
Network reads are declared; the shell performs them.

Commands:
  list / get ID / gen / refine ID / put ID / remove ID / rename ID
  state ID / reset ID / versions ID / revert ID N
  seed / presets / install NAME / schema
"""
from __future__ import annotations

import json
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from essential import gemini_text, parse_json_obj, read_env  # noqa: E402

DATA = Path(os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local/share"))
DIR = DATA / "nothing" / "apps"
STATE = DIR / "state"
VERSIONS = DIR / "versions"
SEEDED = DIR / ".seeded"
PRESETS = Path(__file__).resolve().parent.parent / "quickshell" / "nothing" / "assets" / "apps"

MAX_NODES = 80
MAX_DEPTH = 6
MAX_EXPR = 360
CAP = 40
UA = "Mozilla/5.0 (compatible; nothing-essential-apps/1)"

FACES = {"stat", "tracker", "list", "clock", "media", "note", "custom"}
SIZES = {"s", "m", "l"}
BLOCKS = {
    "text", "stat", "row", "col", "grid", "card", "button", "toggle",
    "slider", "field", "progress", "ring", "dots", "bars", "list",
    "divider", "spacer", "icon", "image",
}
SOURCES = {
    "time", "weather", "sys", "media", "net", "vault", "notify",
    "audio", "battery", "updates", "notifs", "desktop",
}
SLOT_KEYS = (
    "value", "unit", "caption", "progress", "rows", "rowTitle", "rowSub",
    "rowOpen", "empty", "note",
)

BANNED = re.compile(
    r"\b(Qt|Quickshell|XMLHttpRequest|Function|eval|import|require|globalThis"
    r"|window|document|process|constructor|prototype|__proto__|__defineGetter__"
    r"|setTimeout|setInterval|Component|Qt_signal)\b"
)
UNSAFE = re.compile(r"(?<![=!<>])=(?![=>])|;|`|\$\{")
LOOPS = re.compile(r"\b(while|for)\s*\(|\bdo\s*\{|\bfunction\b")
CONSTRUCT = re.compile(r"\bnew\s+[A-Za-z]")
BRACKET_NAME = re.compile(r"\[\s*['\"]")
STRINGS = re.compile(r"'[^']*'|\"[^\"]*\"")
PLAIN_TEXT = re.compile(r"^[A-Za-z][A-Za-z0-9 _\-·•!?%,.:/]*$")
EXPR_ROOTS = SOURCES | {
    "state", "data", "it", "i", "fmt", "Math", "String", "Number", "Date",
    "isNaN", "parseInt", "parseFloat", "JSON", "Object", "Array",
    "true", "false", "null", "undefined", "NaN", "Infinity",
}


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


class Budget:
    def __init__(self) -> None:
        self.nodes = 0
        self.errors: list[str] = []

    def note(self, msg: str) -> None:
        if len(self.errors) < 12:
            self.errors.append(msg)


def quote_if_literal(text: str) -> str:
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
    bare = STRINGS.sub("''", text)
    if BANNED.search(bare) or BRACKET_NAME.search(bare):
        budget.note(f"{where}: forbidden name")
        return ""
    if LOOPS.search(bare):
        budget.note(f"{where}: no loops")
        return ""
    if CONSTRUCT.search(bare):
        budget.note(f"{where}: no `new`, use Date.parse")
        return ""
    if UNSAFE.search(bare):
        budget.note(f"{where}: read-only expressions")
        return ""
    return text


def clean_key(value, budget: Budget, where: str) -> str:
    key = str(value or "").strip()
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,40}", key):
        budget.note(f"{where}: bad state key")
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
        return None
    budget.nodes += 1
    block: dict = {"t": kind}

    def expr(field: str, default: str = "") -> str:
        return clean_expr(raw.get(field, default), budget, kind)

    if kind in ("row", "col", "grid", "card"):
        kids = []
        for child in (raw.get("kids") or [])[:16]:
            node = clean_block(child, budget, depth + 1)
            if node:
                kids.append(node)
        block["kids"] = kids
        if kind == "grid":
            block["cols"] = max(1, min(4, int(raw.get("cols") or 2)))
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
        block["key"] = clean_key(raw.get("key"), budget, kind)
        block["label"] = expr("label")
    elif kind == "slider":
        block["key"] = clean_key(raw.get("key"), budget, kind)
        block["label"] = expr("label")
        block["min"] = float(raw.get("min") or 0)
        block["max"] = float(raw.get("max") if raw.get("max") is not None else 100)
        block["step"] = float(raw.get("step") or 1)
    elif kind == "field":
        block["key"] = clean_key(raw.get("key"), budget, kind)
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
        block["limit"] = max(1, min(8, int(raw.get("limit") or 5)))
        block["empty"] = expr("empty")
        kids = []
        for child in (raw.get("item") or [])[:8]:
            node = clean_block(child, budget, depth + 1)
            if node:
                kids.append(node)
        block["item"] = kids
    elif kind == "image":
        block["src"] = expr("src")
        block["height"] = max(16, min(240, int(raw.get("height") or 64)))
        block["width"] = max(0, min(400, int(raw.get("width") or 0)))
        block["fit"] = str(raw.get("fit") or "cover")[:10]
        block["round"] = str(raw.get("round") or "chip")[:8]
    elif kind == "icon":
        block["glyph"] = expr("glyph")
        block["size"] = str(raw.get("size") or "m")[:2]
        block["color"] = str(raw.get("color") or "")[:12]
    elif kind == "spacer":
        block["size"] = max(2, min(40, int(raw.get("size") or 8)))
    return block


def clean_fetch(raw, budget: Budget) -> dict | None:
    if not isinstance(raw, dict):
        return None
    url = str(raw.get("url") or "").strip()
    if not url.startswith("https://") or len(url) > 500:
        if url:
            budget.note("fetch.url must be https")
        return None
    every = int(raw.get("every") or raw.get("interval") or 900)
    pick = str(raw.get("pick") or "")[:120]
    return {"url": url, "pick": pick, "every": max(30, min(86400, every))}


def validate(raw, keep_id: str = "") -> tuple[dict | None, list[str]]:
    budget = Budget()
    if not isinstance(raw, dict):
        return None, ["not an object"]

    name = str(raw.get("name") or "").strip()[:36] or "Untitled"
    size = str(raw.get("size") or "s").strip()[:2]
    if size not in SIZES:
        size = "s"
    face = str(raw.get("face") or "").strip().lower()
    body = []
    for child in (raw.get("body") or [])[:16]:
        node = clean_block(child, budget, 1)
        if node:
            body.append(node)
    if face not in FACES:
        face = "custom" if body else "stat"
    if face == "custom" and not body:
        return None, budget.errors or ["custom face needs a body"]

    state = {}
    raw_state = raw.get("state")
    if isinstance(raw_state, dict):
        for key, value in list(raw_state.items())[:24]:
            clean = clean_key(key, budget, "state")
            if clean and isinstance(value, (int, float, str, bool)):
                state[clean] = value if not isinstance(value, str) else value[:200]

    slots = {}
    raw_slots = raw.get("slots")
    if isinstance(raw_slots, dict):
        for key in SLOT_KEYS:
            if key in raw_slots:
                expr = clean_expr(raw_slots.get(key), budget, f"slots.{key}")
                if expr:
                    slots[key] = expr

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

    spec = {
        "id": keep_id or slug(name),
        "name": name,
        "icon": str(raw.get("icon") or "󰀻")[:4],
        "size": size,
        "face": face,
        "title": str(raw.get("title") or name).strip()[:24].upper(),
        "sources": sources,
        "state": state,
        "slots": slots,
        "actions": actions,
        "tick": clean_steps(raw.get("tick"), budget, "tick"),
        "plus": str(raw.get("plus") or "+")[:8],
        "minus": str(raw.get("minus") or "−")[:8],
        "primary": str(raw.get("primary") or "")[:16],
    }
    if body:
        spec["body"] = body
    if fetch:
        spec["fetch"] = fetch
    return spec, budget.errors


SCHEMA_DOC = """You build ONE homescreen widget for a Nothing OS desktop.

Widgets are small glanceable tiles, not apps. Think 2×2 (size s), 2×4 strip
(size m) or 4×4 (size l). One job. English UI, short uppercase captions.

Return JSON only:
{
  "say": "one or two sentences, what you built and how to use it",
  "name": "<=36 chars",
  "icon": "<one Nerd Font glyph>",
  "size": "s" | "m" | "l",
  "face": "stat" | "tracker" | "list" | "clock" | "media" | "note" | "custom",
  "title": "SHORT LABEL",
  "sources": ["time","weather","sys","media","net","vault","audio","battery","updates","notifs","desktop"],
  "state": { "key": number|string|bool },
  "slots": {
    "value": <expr>, "unit": <expr>, "caption": <expr>,
    "progress": <expr 0..1>,
    "rows": <expr array>, "rowTitle": <expr>, "rowSub": <expr>,
    "rowOpen": <expr url>, "empty": <expr>, "note": <expr>
  },
  "plus": "+", "minus": "−", "primary": "ROLL",
  "actions": { "plus": [steps], "minus": [steps], "primary": [steps], "open": [steps] },
  "fetch": { "url": "https://...", "pick": "a.b", "every": 900 },
  "tick": [steps],
  "body": [blocks]   // ONLY when face is custom
}

FACES — pick one, fill the slots it needs:
  stat     big Ndot number. slots.value + caption + optional unit
  tracker  like stat, plus a dot bar (slots.progress) and + / −
  list     title + up to 5 rows. slots.rows, rowTitle, rowSub, rowOpen
  clock    wall clock from time.hhmm / time.dateLong (slots optional)
  media    now playing from media.title / media.artist
  note     a paragraph. slots.note
  custom   only if nothing else fits. body uses the block schema below

STEPS: {"set":"k","to":<expr>} {"inc":"k","by":<expr>} {"toggle":"k"}
  {"notify":<expr>,"body":<expr>} {"copy":<expr>} {"open":<expr>}
  {"refetch":true} {"if":<expr>,"do":[steps]}

EXPRESSIONS: read-only JS, no assignment, no semicolon, no `new`.
  state.* data time.hhmm time.dayShort time.dateLong time.epoch
  weather.temp weather.desc weather.city
  sys.cpu sys.ram battery.percent battery.charging
  media.title media.artist media.playing
  audio.volume notifs.unread vault.latest vault.count
  fmt.mmss(s) fmt.until(iso) fmt.ago(iso) fmt.date(iso) fmt.round(x,n) fmt.num(x)
  Math, Date.parse, .map .filter .sort .slice .reduce
Guard data: it is null until the fetch lands. (data && data[0] ? data[0].x : "-")

BLOCKS for custom only: text, stat, row, col, grid, button, toggle, field,
progress, ring, dots, list, icon, image, divider, spacer.
text.value is an expression: write 'CUPS' not CUPS.

Known live https JSON, no key:
  F1 next     https://api.jolpi.ca/ergast/f1/current/next.json
              pick MRData.RaceTable.Races
  FX          https://api.frankfurter.app/latest?from=EUR&to=USD,GBP,JPY  pick rates
  Weather     https://api.open-meteo.com/v1/forecast?latitude=48.85&longitude=2.35&current=temperature_2m
              pick current
  Holidays    https://date.nager.at/api/v3/NextPublicHolidays/FR
  Crypto      https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=eur

Prefer a face. One focal number. Do not invent APIs.
"""


def strip_meta(spec: dict) -> dict:
    copy = dict(spec)
    for key in ("id", "created", "version", "history", "preset", "saved",
                "chat", "_say", "_note"):
        copy.pop(key, None)
    return copy


def probe(url: str) -> tuple[bool, str]:
    req = urllib.request.Request(
        url, method="GET",
        headers={"User-Agent": UA, "Accept": "application/json, */*"},
    )
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            if resp.status >= 400:
                return False, f"fetch HTTP {resp.status}"
            return True, ""
    except urllib.error.HTTPError as exc:
        return False, f"fetch HTTP {exc.code}"
    except (urllib.error.URLError, TimeoutError, OSError):
        return False, "fetch did not answer"


def generate(request: str, current: dict | None, keep_id: str) -> tuple[dict | None, str]:
    env = read_env()
    if not (env.get("GEMINI_API_KEY") or os.environ.get("GEMINI_API_KEY")):
        return None, "Add a Gemini key in settings"
    prompt = SCHEMA_DOC + "\n"
    if current:
        prompt += "CURRENT WIDGET:\n" + json.dumps(
            strip_meta(current), ensure_ascii=False)[:4000] + "\n"
        prompt += f"CHANGE: {request}\n"
    else:
        prompt += f"REQUEST: {request}\n"
    raw, err = gemini_text(prompt, env, 45)
    if err:
        return None, err
    data = parse_json_obj(raw)
    spec, errors = validate(data, keep_id)
    if not spec:
        return None, (errors[0] if errors else "the widget could not be built")
    spec["_say"] = str((data or {}).get("say") or "Done.")[:400]
    fetch = spec.get("fetch")
    if isinstance(fetch, dict) and fetch.get("url"):
        ok, note = probe(fetch["url"])
        if not ok:
            spec["_note"] = note + " — the tile still works, data may stay empty"
    return spec, ""


def append_chat(spec: dict, user: str, say: str, previous: dict | None) -> None:
    chat = list((previous or spec).get("chat") or [])[-16:]
    chat.append({"role": "user", "text": user[:500]})
    chat.append({"role": "app", "text": (say or "Done.")[:400]})
    spec["chat"] = chat


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
        fail("describe the widget first")
    spec, err = generate(request, None, "")
    if not spec:
        fail(err)
    say = spec.pop("_say", "Done.")
    note = spec.pop("_note", "")
    spec["prompt"] = request[:600]
    spec["created"] = now()
    spec["version"] = 1
    spec["history"] = [request[:200]]
    append_chat(spec, request, say, None)
    save_spec(spec)
    archive(spec)
    save_state(spec["id"], dict(spec.get("state") or {}))
    out({"ok": True, "id": spec["id"], "name": spec["name"],
         "say": say, "note": note})


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
    say = spec.pop("_say", "Done.")
    note = spec.pop("_note", "")
    spec["prompt"] = current.get("prompt") or request[:600]
    spec["created"] = current.get("created") or now()
    spec["version"] = int(current.get("version") or 1) + 1
    spec["history"] = (current.get("history") or [])[-9:] + [request[:200]]
    spec["preset"] = current.get("preset")
    append_chat(spec, request, say, current)
    save_spec(spec)
    archive(spec)
    saved = load_state(app_id)
    fresh = dict(spec.get("state") or {})
    for key in fresh:
        if key in saved:
            fresh[key] = saved[key]
    save_state(app_id, fresh)
    out({"ok": True, "id": spec["id"], "name": spec["name"],
         "version": spec["version"], "say": say, "note": note})


def cmd_put(app_id: str, payload: str) -> None:
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
        fail(errors[0] if errors else "the widget did not validate")
        return
    spec["prompt"] = current.get("prompt") or ""
    spec["created"] = current.get("created") or now()
    spec["version"] = int(current.get("version") or 1) + 1
    spec["history"] = (current.get("history") or [])[-9:] + ["edited"]
    spec["chat"] = current.get("chat") or []
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
    spec["chat"] = current.get("chat") or []
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
    spec["chat"] = [{
        "role": "app",
        "text": f"Preset {spec['name']}. Describe a change to reshape it.",
    }]
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
                "size": data.get("size") or "s",
                "face": data.get("face") or "",
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
