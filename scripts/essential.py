#!/usr/bin/env python3
"""Vault for Essential Space.

Commands:
  list
  add KIND TEXT...
  clip
  snip
  ocr
  ingest KIND PATH [TEXT...]
  ingest-record
  ingest-voice
  ingest-song TITLE [ARTIST...]
  remove ID
  mind ID [backend]
  patch ID             (JSON on stdin: when, forYou)
  wipe
  dir
  has-key
  set-key          (API key on stdin)
  set-backend NAME
  ask              (question on stdin or argv)
"""
from __future__ import annotations

import base64
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
from datetime import datetime, timedelta
from pathlib import Path

DATA = Path(os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local/share"))
DIR = DATA / "nothing" / "essentials"
INDEX = DIR / "index.json"
FILES = DIR / "files"
LAST_RECORD = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "nothing-record.last"
LAST_VOICE = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "nothing-voice.last"
MIND_ENV = Path.home() / ".config" / "nothing" / "mind.env"
CAP = 80


def ensure() -> None:
    FILES.mkdir(parents=True, exist_ok=True)


def load() -> list:
    ensure()
    if not INDEX.exists():
        return []
    try:
        data = json.loads(INDEX.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except (OSError, json.JSONDecodeError):
        return []


def save(items: list) -> None:
    ensure()
    INDEX.write_text(
        json.dumps(items[:CAP], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def nid() -> str:
    return time.strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:4]


def now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S")


def have(bin_name: str) -> bool:
    return shutil.which(bin_name) is not None


def out(obj) -> None:
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")


def fail(msg: str, code: int = 1) -> None:
    sys.stdout.write(msg + "\n")
    sys.exit(code)


def read_env() -> dict:
    env: dict[str, str] = {}
    if not MIND_ENV.exists():
        return env
    try:
        for line in MIND_ENV.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, val = line.split("=", 1)
            env[key.strip()] = val.strip().strip('"').strip("'")
    except OSError:
        pass
    return env


def write_env(env: dict) -> None:
    MIND_ENV.parent.mkdir(parents=True, exist_ok=True)
    order = ("BACKEND", "MODEL", "GEMINI_API_KEY")
    lines = []
    seen = set()
    for key in order:
        val = env.get(key, "")
        if val:
            lines.append(f"{key}={val}\n")
            seen.add(key)
    for key, val in env.items():
        if key in seen or not val:
            continue
        lines.append(f"{key}={val}\n")
    old = os.umask(0o077)
    try:
        MIND_ENV.write_text("".join(lines), encoding="utf-8")
        os.chmod(MIND_ENV, 0o600)
    finally:
        os.umask(old)


def parse_json_obj(body: str) -> dict:
    text = (body or "").strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[-1]
        if text.endswith("```"):
            text = text[: text.rfind("```")]
        text = text.strip()
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end <= start:
        return {}
    try:
        data = json.loads(text[start : end + 1])
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        return {}


def stub_mind(entry: dict) -> dict:
    text = (entry.get("text") or "").strip()
    kind = entry.get("kind") or "note"
    if text:
        first = text.split("\n", 1)[0].strip()
        entry["title"] = first[:48] or kind.title()
        entry["summary"] = text[:240]
    else:
        labels = {
            "snip": "Screenshot",
            "ocr": "Text from a capture",
            "record": "Recording",
            "voice": "Voice note",
            "song": "Track",
            "clip": "Clipboard",
            "calc": "Result",
            "note": "Note",
        }
        entry["title"] = labels.get(kind, kind.title())
        entry["summary"] = ""
    entry.setdefault("tags", [])
    entry.setdefault("actions", [])
    entry.setdefault("reminders", [])
    if not entry.get("when"):
        entry["when"] = infer_when(text)
    if not entry.get("when") and task_intent(text):
        entry["when"] = iso_when(clock())
    entry["forYou"] = bool(entry.get("when")) or task_intent(text)
    entry["mind"] = "stub"
    return entry


def clock() -> datetime:
    return datetime.now().replace(microsecond=0)


def iso_when(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%S")


def mind_clock_line() -> str:
    now = clock()
    return (
        f"Current local datetime: {iso_when(now)} "
        f"({now.strftime('%A')}). Resolve relative dates against this."
    )


def mind_rules() -> str:
    return (
        "Return JSON only, keys: title (short), summary (one or two sentences), "
        "transcript (full text, voice notes only, else empty), "
        "tags (array of 1-4 lowercase words), "
        "actions (array of short next steps, empty if none), "
        "when (ISO 8601 local datetime YYYY-MM-DDTHH:MM:SS if this is a task, "
        "to-do, reminder, deadline, event, appointment, or mentions any date "
        "or time; date-only tasks use 09:00; else empty string), "
        "forYou (true if Essential For You should surface it: any task, "
        "reminder, deadline, date, rendez-vous or thing to follow up; "
        "false for a plain memo). "
        "Library stores every capture. For You only gets forYou true or a when. "
        "No markdown.\n"
        f"{mind_clock_line()}\n"
    )


def normalise_when(value) -> str:
    if isinstance(value, dict):
        value = value.get("datetime") or value.get("date") or value.get("iso") or ""
    raw = str(value or "").strip()
    if raw.lower() in ("", "none", "null", "n/a", "undefined"):
        return ""
    raw = raw.replace(" ", "T", 1) if "T" not in raw and " " in raw else raw
    if re.match(r"^\d{4}-\d{2}-\d{2}$", raw):
        raw = raw + "T09:00:00"
    try:
        dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        if dt.tzinfo is not None:
            dt = dt.astimezone().replace(tzinfo=None)
        return iso_when(dt)
    except ValueError:
        return ""


def task_intent(blob: str) -> bool:
    t = (blob or "").lower()
    keys = (
        "rappel", "rappelle", "n'oublie", "n oublie", "oublie pas",
        "il faut", "faut que", "à faire", "a faire", "tache", "tâche",
        "todo", "to-do", "to do", "remind", "reminder", "deadline",
        "rdv", "rendez-vous", "rendez vous", "appointment", "meeting",
        "réunion", "reunion", "échéance", "echeance", "follow up",
        "n'oubliez", "pense à", "pense a",
    )
    return any(k in t for k in keys)


def infer_when(blob: str) -> str:
    t = (blob or "").lower()
    if not t:
        return ""
    now = clock()
    day = now
    found_day = False
    if re.search(r"\b(apr[eè]s[-\s]?demain|day after tomorrow)\b", t):
        day = now + timedelta(days=2)
        found_day = True
    elif re.search(r"\b(demain|tomorrow)\b", t):
        day = now + timedelta(days=1)
        found_day = True
    elif re.search(r"\b(aujourd['’]?hui|today)\b", t):
        found_day = True
    else:
        week = {
            "lundi": 0, "monday": 0, "mardi": 1, "tuesday": 1,
            "mercredi": 2, "wednesday": 2, "jeudi": 3, "thursday": 3,
            "vendredi": 4, "friday": 4, "samedi": 5, "saturday": 5,
            "dimanche": 6, "sunday": 6,
        }
        for name, idx in week.items():
            if re.search(rf"\b{name}\b", t):
                delta = (idx - now.weekday()) % 7
                day = now + timedelta(days=delta)
                found_day = True
                break

    hour, minute = 9, 0
    found_time = False
    m = re.search(r"\b(\d{1,2})\s*h\s*(\d{2})?\b", t)
    if not m:
        m = re.search(r"\b(\d{1,2}):(\d{2})\b", t)
    if m:
        hour = int(m.group(1))
        minute = int(m.group(2) or 0)
        found_time = 0 <= hour <= 23 and 0 <= minute <= 59
    else:
        ampm = re.search(r"\b(\d{1,2})\s*(am|pm)\b", t)
        if ampm:
            hour = int(ampm.group(1)) % 12
            if ampm.group(2) == "pm":
                hour += 12
            found_time = True
    if re.search(r"\b(ce soir|tonight|this evening)\b", t) and not found_time:
        hour, minute, found_time = 20, 0, True
    if re.search(r"\b(ce matin|this morning)\b", t) and not found_time:
        hour, minute, found_time = 9, 0, True

    if not found_day and not found_time:
        return ""
    if not found_time:
        hour, minute = 9, 0
    try:
        return iso_when(day.replace(hour=hour, minute=minute, second=0))
    except ValueError:
        return ""


def ollama_mind(entry: dict, model: str) -> dict:
    text = (entry.get("text") or "").strip()
    if not text or not have("ollama"):
        return stub_mind(entry)
    prompt = (
        mind_rules()
        + f"Kind: {entry.get('kind')}\n"
        + f"Text:\n{text[:4000]}\n"
    )
    try:
        raw = subprocess.check_output(
            ["ollama", "run", model, prompt],
            timeout=45,
            stderr=subprocess.DEVNULL,
        )
        data = parse_json_obj(raw.decode("utf-8", "replace"))
        if not data:
            return stub_mind(entry)
        paint_mind(entry, data, "ollama")
        return entry
    except (subprocess.SubprocessError, OSError):
        return stub_mind(entry)


def paint_mind(entry: dict, data: dict, source: str) -> None:
    title = str(data.get("title") or entry.get("title") or "").strip()
    if title:
        entry["title"] = title[:80]
    summary = str(data.get("summary") or "").strip()
    if summary:
        entry["summary"] = summary[:400]
    tags = data.get("tags") if isinstance(data.get("tags"), list) else []
    entry["tags"] = [str(t)[:24] for t in tags][:4]
    actions = data.get("actions") if isinstance(data.get("actions"), list) else []
    entry["actions"] = [str(a)[:80] for a in actions if str(a).strip()][:4]
    rems = data.get("reminders") if isinstance(data.get("reminders"), list) else []
    entry["reminders"] = [str(r)[:80] for r in rems if str(r).strip()][:4]
    transcript = str(data.get("transcript") or "").strip()
    if transcript:
        entry["text"] = transcript[:4000]
        if not str(entry.get("summary") or "").strip():
            entry["summary"] = transcript[:400]
    blob = " ".join([
        str(entry.get("text") or ""),
        str(entry.get("summary") or ""),
        str(entry.get("title") or ""),
        " ".join(entry.get("actions") or []),
        " ".join(entry.get("reminders") or []),
    ])
    when = normalise_when(data.get("when"))
    if not when:
        when = infer_when(blob)
    fy = data.get("forYou")
    if isinstance(fy, str):
        fy = fy.strip().lower() in ("1", "true", "yes")
    else:
        fy = bool(fy)
    if not when and (fy or task_intent(blob) or entry.get("reminders")):
        when = iso_when(clock())
    entry["when"] = when[:40]
    entry["forYou"] = bool(when) or fy or bool(entry.get("reminders"))
    entry["mind"] = source


def gemini_parts(entry: dict) -> list:
    kind = entry.get("kind") or "note"
    text = (entry.get("text") or "").strip()
    if kind == "voice":
        prompt = (
            "This is a spoken voice note. Transcribe it fully, then organise it. "
            "Spoken dates are often relative (demain, lundi, 15h, tomorrow, "
            "next week) or tasks (il faut, n'oublie pas, remind me). Those "
            "must set when and forYou true so they appear in For You.\n"
            + mind_rules()
            + f"Kind: {kind}\n"
        )
    else:
        prompt = (
            "You organise a capture for Nothing Essential Space. "
            + mind_rules()
            + f"Kind: {kind}\n"
            + f"Text:\n{text[:4000]}\n"
        )
    parts: list = [{"text": prompt}]
    path = Path(entry.get("path") or "")
    if not path.is_file():
        return parts
    suffix = path.suffix.lower()
    mime = {
        ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".wav": "audio/wav", ".oga": "audio/ogg", ".ogg": "audio/ogg",
        ".opus": "audio/ogg", ".mp3": "audio/mpeg", ".m4a": "audio/mp4",
        ".flac": "audio/flac",
    }.get(suffix)
    if not mime:
        return parts
    try:
        raw = path.read_bytes()
    except OSError:
        return parts
    limit = 12_000_000 if mime.startswith("audio/") else 4_000_000
    if not raw or len(raw) > limit:
        return parts
    parts.append({
        "inline_data": {
            "mime_type": mime,
            "data": base64.b64encode(raw).decode("ascii"),
        }
    })
    return parts


def gemini_mind(entry: dict, env: dict) -> dict:
    key = env.get("GEMINI_API_KEY") or os.environ.get("GEMINI_API_KEY") or ""
    if not key:
        stub_mind(entry)
        entry["mind"] = "nokey"
        entry["summary"] = "Add a Gemini key in settings"
        return entry
    models = []
    for name in (env.get("MODEL"), "gemini-3.6-flash", "gemini-3.5-flash"):
        if name and name not in models:
            models.append(name)
    last_err = "Gemini failed"
    for model in models:
        ok, err = gemini_once(entry, key, model)
        if ok:
            return entry
        last_err = err
        if "no longer available" in err.lower() or "not found" in err.lower():
            continue
        break
    stub_mind(entry)
    entry["mind"] = "error"
    entry["summary"] = last_err[:180]
    return entry


def gemini_once(entry: dict, key: str, model: str) -> tuple[bool, str]:
    body = json.dumps({
        "contents": [{"parts": gemini_parts(entry)}],
        "generationConfig": {
            "temperature": 0.2,
            "responseMimeType": "application/json",
        },
    }).encode("utf-8")
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent?key={key}"
    )
    req = urllib.request.Request(
        url, data=body, method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=75 if entry.get("kind") == "voice" else 45) as resp:
            payload = json.loads(resp.read().decode("utf-8", "replace"))
        text = (
            payload.get("candidates", [{}])[0]
            .get("content", {})
            .get("parts", [{}])[0]
            .get("text", "")
        )
        data = parse_json_obj(text)
        if not data:
            return False, "Gemini returned no title"
        paint_mind(entry, data, "gemini")
        return True, ""
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        msg = ""
        try:
            msg = str(json.loads(raw).get("error", {}).get("message") or "")
        except json.JSONDecodeError:
            msg = raw[:180]
        if exc.code in (401, 403):
            return False, "Bad Gemini API key"
        if exc.code in (429, 503):
            return False, "Gemini is busy — tap Ask again"
        return False, (msg or f"Gemini HTTP {exc.code}")[:180]
    except (urllib.error.URLError, TimeoutError):
        return False, "No network to Gemini"
    except (json.JSONDecodeError, OSError, IndexError, KeyError, TypeError):
        return False, "Gemini returned junk"


def gemini_text(prompt: str, env: dict, timeout: int = 30) -> tuple[str, str]:
    key = env.get("GEMINI_API_KEY") or os.environ.get("GEMINI_API_KEY") or ""
    if not key:
        return "", "Add a Gemini key in settings"
    models: list[str] = []
    for name in (env.get("MODEL"), "gemini-3.6-flash", "gemini-3.5-flash"):
        if name and name not in models:
            models.append(name)
    last_err = "Gemini failed"
    for model in models:
        text, err = gemini_text_once(prompt, key, model, timeout)
        if text:
            return text, ""
        last_err = err
        if "no longer available" in err.lower() or "not found" in err.lower():
            continue
        break
    return "", last_err


def gemini_text_once(prompt: str, key: str, model: str, timeout: int) -> tuple[str, str]:
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.3,
            "responseMimeType": "application/json",
        },
    }).encode("utf-8")
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent?key={key}"
    )
    req = urllib.request.Request(
        url, data=body, method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8", "replace"))
        text = (
            payload.get("candidates", [{}])[0]
            .get("content", {})
            .get("parts", [{}])[0]
            .get("text", "")
        )
        return (text or "").strip(), ""
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        msg = ""
        try:
            msg = str(json.loads(raw).get("error", {}).get("message") or "")
        except json.JSONDecodeError:
            msg = raw[:180]
        if exc.code in (401, 403):
            return "", "Bad Gemini API key"
        if exc.code in (429, 503):
            return "", "Gemini is busy — tap Ask again"
        return "", (msg or f"Gemini HTTP {exc.code}")[:180]
    except (urllib.error.URLError, TimeoutError):
        return "", "No network to Gemini"
    except (json.JSONDecodeError, OSError, IndexError, KeyError, TypeError):
        return "", "Gemini returned junk"


def cmd_ask(question: str) -> None:
    q = (question or "").strip()
    if not q:
        out({"answer": "Type a question first", "ids": []})
        return
    items = load()
    words = [w for w in re.split(r"\s+", q.lower()) if len(w) > 2]
    ranked: list[tuple[int, dict]] = []
    for it in items:
        hay = " ".join([
            str(it.get("kind") or ""),
            str(it.get("title") or ""),
            str(it.get("summary") or ""),
            str(it.get("text") or "")[:1200],
            " ".join(it.get("tags") or []),
        ]).lower()
        hits = sum(1 for w in words if w in hay) if words else 0
        if hits:
            ranked.append((hits, it))
    ranked.sort(key=lambda pair: -pair[0])
    picked = [it for _, it in ranked[:8]] or items[:8]
    lines = []
    for it in picked:
        body = (it.get("summary") or it.get("text") or "")[:220]
        lines.append(
            f"id={it.get('id') or ''} kind={it.get('kind') or ''} "
            f"title={it.get('title') or ''}: {body}"
        )
    vault = "\n".join(lines) if lines else "(empty)"
    prompt = (
        "You are Essential Search on a Nothing OS desktop. "
        "Answer in 2 or 3 short sentences. Prefer the vault if it answers. "
        "If you use a capture, mention its title. No markdown, no bullets, "
        "no follow-up question.\n"
        'Return JSON: {"answer": string, "ids": [id strings you used]}\n'
        f"Vault:\n{vault}\n"
        f"Question: {q}\n"
    )
    raw, err = gemini_text(prompt, read_env(), 30)
    if err:
        out({"answer": err, "ids": []})
        return
    data = parse_json_obj(raw) or {}
    answer = str(data.get("answer") or "").strip()
    if not answer:
        answer = re.sub(r"\s+", " ", raw).strip()[:800]
    ids = data.get("ids") if isinstance(data.get("ids"), list) else []
    known = {str(it.get("id") or "") for it in items}
    clean = [str(i) for i in ids if str(i) in known][:4]
    out({"answer": answer[:800], "ids": clean})


def apply_mind(entry: dict, backend: str) -> dict:
    env = read_env()
    backend = (backend or env.get("BACKEND") or "stub").strip().lower()
    if backend == "gemini":
        return gemini_mind(entry, env)
    if backend == "ollama":
        model = env.get("MODEL") or "llama3.2"
        return ollama_mind(entry, model)
    return stub_mind(entry)


def insert(entry: dict, backend: str = "stub") -> dict:
    backend = (backend or "stub").strip().lower()
    items = load()
    stub_mind(entry)
    if backend in ("gemini", "ollama"):
        entry["mind"] = "pending"
    items.insert(0, entry)
    save(items)
    if backend in ("gemini", "ollama"):
        apply_mind(entry, backend)
        save(items)
    return entry


def slurp() -> str:
    if not have("slurp") or not have("grim"):
        fail("slurp or grim is not installed")
    try:
        geo = subprocess.check_output(
            ["slurp", "-d", "-b", "00000080", "-c", "d71921ff", "-w", "2"],
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        fail("Cancelled")
    return geo.decode().strip()


def grim_to(path: Path, geo: str) -> None:
    subprocess.check_call(["grim", "-g", geo, str(path)])


def ocr_file(path: Path) -> str:
    if not have("tesseract"):
        return ""
    langs = "eng"
    listed = subprocess.run(
        ["tesseract", "--list-langs"],
        capture_output=True,
        text=True,
    )
    if "fra" in (listed.stdout or "").split():
        langs = "fra+eng"
    r = subprocess.run(
        ["tesseract", str(path), "-", "-l", langs],
        capture_output=True,
    )
    return r.stdout.decode("utf-8", "replace").strip()


def cmd_list() -> None:
    out(load())


def cmd_add(kind: str, text: str, backend: str) -> None:
    kind = kind if kind in ("note", "clip", "calc", "ocr", "song") else "note"
    text = text.strip()
    if not text:
        fail("Empty")
    entry = {
        "id": nid(),
        "at": now(),
        "kind": kind,
        "text": text,
        "path": "",
        "title": "",
        "summary": "",
        "tags": [],
        "actions": [],
        "mind": "",
    }
    insert(entry, backend)
    print("Saved")


def cmd_clip(backend: str) -> None:
    if not have("wl-paste"):
        fail("wl-paste is not installed")
    img = subprocess.run(
        ["wl-paste", "-t", "image/png"],
        capture_output=True,
    )
    if img.returncode == 0 and img.stdout.startswith(b"\x89PNG"):
        eid = nid()
        dest = FILES / f"{eid}.png"
        dest.write_bytes(img.stdout)
        insert(
            {
                "id": eid,
                "at": now(),
                "kind": "snip",
                "text": "",
                "path": str(dest),
                "title": "",
                "summary": "",
                "tags": [],
                "actions": [],
                "mind": "",
            },
            backend,
        )
        print("Saved image")
        return
    text = subprocess.run(
        ["wl-paste", "-t", "text"],
        capture_output=True,
    )
    body = text.stdout.decode("utf-8", "replace").strip()
    if not body:
        fail("Clipboard empty")
    cmd_add("clip", body, backend)


def cmd_snip(backend: str, do_ocr: bool) -> None:
    geo = slurp()
    eid = nid()
    dest = FILES / f"{eid}.png"
    try:
        grim_to(dest, geo)
    except subprocess.CalledProcessError:
        fail("Cancelled")
    if not dest.exists() or dest.stat().st_size == 0:
        fail("Cancelled")
    text = ocr_file(dest) if do_ocr else ""
    insert(
        {
            "id": eid,
            "at": now(),
            "kind": "ocr" if do_ocr else "snip",
            "text": text,
            "path": str(dest),
            "title": "",
            "summary": "",
            "tags": [],
            "actions": [],
            "mind": "",
        },
        backend,
    )
    print("Saved")


def cmd_ingest(kind: str, path: str, text: str, backend: str) -> None:
    src = Path(path) if path else Path()
    dest = ""
    if src.is_file():
        eid = nid()
        dest_path = FILES / f"{eid}{src.suffix}"
        try:
            shutil.copy2(src, dest_path)
            dest = str(dest_path)
        except OSError:
            dest = str(src)
        ident = eid
    else:
        ident = nid()
    insert(
        {
            "id": ident,
            "at": now(),
            "kind": kind or "note",
            "text": text.strip(),
            "path": dest,
            "title": "",
            "summary": "",
            "tags": [],
            "actions": [],
            "mind": "",
        },
        backend,
    )
    print("Saved")


def cmd_ingest_record(backend: str) -> None:
    if not LAST_RECORD.exists():
        fail("No recording")
    path = LAST_RECORD.read_text(encoding="utf-8").strip()
    if not path or not Path(path).is_file():
        fail("No recording")
    cmd_ingest("record", path, Path(path).name, backend)


def cmd_ingest_voice(backend: str) -> None:
    if not LAST_VOICE.exists():
        fail("No voice note")
    path = LAST_VOICE.read_text(encoding="utf-8").strip()
    src = Path(path)
    if not path or not src.is_file() or src.stat().st_size < 800:
        fail("No voice note")
    cmd_ingest("voice", path, "", backend)


def cmd_ingest_last(kind: str, backend: str) -> None:
    last = Path("/tmp/nothing-snip/last")
    if not last.exists():
        fail("No capture")
    path = last.read_text(encoding="utf-8").strip()
    if not path or not Path(path).is_file():
        fail("No capture")
    if kind == "ocr":
        cmd_ingest("ocr", path, ocr_file(Path(path)), backend)
    else:
        cmd_ingest("snip", path, "", backend)


def cmd_remove(ident: str) -> None:
    items = load()
    keep = []
    removed = None
    for it in items:
        if it.get("id") == ident:
            removed = it
        else:
            keep.append(it)
    if removed is None:
        fail("Not found")
    path = removed.get("path") or ""
    if path.startswith(str(FILES)) and Path(path).is_file():
        try:
            Path(path).unlink()
        except OSError:
            pass
    save(keep)
    print("Removed")


def cmd_patch(ident: str) -> None:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        fail("Bad patch")
    if not isinstance(payload, dict):
        fail("Bad patch")
    items = load()
    found = None
    for it in items:
        if it.get("id") == ident:
            found = it
            break
    if found is None:
        fail("Not found")
    if "when" in payload:
        found["when"] = normalise_when(payload.get("when"))
    if "forYou" in payload:
        fy = payload.get("forYou")
        if isinstance(fy, str):
            fy = fy.strip().lower() in ("1", "true", "yes", "on")
        found["forYou"] = bool(fy)
        if not found["forYou"]:
            found["when"] = ""
    elif "when" in payload:
        found["forYou"] = bool(found.get("when"))
    save(items)
    print("Patched")


def cmd_mind(ident: str, backend: str) -> None:
    items = load()
    found = None
    for it in items:
        if it.get("id") == ident:
            found = it
            break
    if found is None:
        fail("Not found")
    found["mind"] = "pending"
    save(items)
    apply_mind(found, backend)
    save(items)
    print("Mind")


def cmd_wipe() -> None:
    if FILES.exists():
        shutil.rmtree(FILES, ignore_errors=True)
    save([])
    print("Wiped")


def cmd_has_key() -> None:
    print("yes" if read_env().get("GEMINI_API_KEY") else "no")


def cmd_set_key() -> None:
    key = sys.stdin.read().strip()
    env = read_env()
    if key:
        env["GEMINI_API_KEY"] = key
    else:
        env.pop("GEMINI_API_KEY", None)
    write_env(env)
    print("saved" if key else "cleared")


def cmd_set_backend(name: str) -> None:
    env = read_env()
    env["BACKEND"] = (name or "stub").strip().lower() or "stub"
    write_env(env)
    print("ok")


def main() -> None:
    args = sys.argv[1:]
    if not args:
        fail("usage: essential.py <command>", 2)
    cmd = args[0]
    backend = os.environ.get("NOTHING_MIND_BACKEND", "stub")

    if cmd == "list":
        cmd_list()
    elif cmd == "dir":
        ensure()
        print(str(DIR))
    elif cmd == "wipe":
        cmd_wipe()
    elif cmd == "add":
        kind = args[1] if len(args) > 1 else "note"
        text = " ".join(args[2:]) if len(args) > 2 else ""
        cmd_add(kind, text, backend)
    elif cmd == "clip":
        cmd_clip(backend)
    elif cmd == "snip":
        cmd_snip(backend, False)
    elif cmd == "ocr":
        cmd_snip(backend, True)
    elif cmd == "ingest":
        kind = args[1] if len(args) > 1 else "note"
        path = args[2] if len(args) > 2 else ""
        text = " ".join(args[3:]) if len(args) > 3 else ""
        cmd_ingest(kind, path, text, backend)
    elif cmd == "ingest-record":
        cmd_ingest_record(backend)
    elif cmd == "ingest-voice":
        cmd_ingest_voice(backend)
    elif cmd == "ingest-last":
        cmd_ingest_last(args[1] if len(args) > 1 else "snip", backend)
    elif cmd == "ingest-song":
        title = args[1] if len(args) > 1 else ""
        artist = " ".join(args[2:]) if len(args) > 2 else ""
        body = f"{title} — {artist}".strip(" —")
        cmd_add("song", body, backend)
    elif cmd == "remove":
        if len(args) < 2:
            fail("id required")
        cmd_remove(args[1])
    elif cmd == "patch":
        if len(args) < 2:
            fail("id required")
        cmd_patch(args[1])
    elif cmd == "mind":
        if len(args) < 2:
            fail("id required")
        if len(args) > 2:
            backend = args[2]
        cmd_mind(args[1], backend)
    elif cmd == "has-key":
        cmd_has_key()
    elif cmd == "set-key":
        cmd_set_key()
    elif cmd == "set-backend":
        cmd_set_backend(args[1] if len(args) > 1 else "stub")
    elif cmd == "ask":
        q = " ".join(args[1:]).strip()
        if not q:
            q = sys.stdin.read()
        cmd_ask(q)
    else:
        fail("unknown command: " + cmd, 2)


if __name__ == "__main__":
    main()
