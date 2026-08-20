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
  ingest-song TITLE [ARTIST...]
  remove ID
  mind ID [backend]
  wipe
  dir
  has-key
  set-key          (API key on stdin)
  set-backend NAME
"""
from __future__ import annotations

import base64
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

DATA = Path(os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local/share"))
DIR = DATA / "nothing" / "essentials"
INDEX = DIR / "index.json"
FILES = DIR / "files"
LAST_RECORD = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "nothing-record.last"
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
            "song": "Track",
            "clip": "Clipboard",
            "calc": "Result",
            "note": "Note",
        }
        entry["title"] = labels.get(kind, kind.title())
        entry["summary"] = ""
    entry.setdefault("tags", [])
    entry.setdefault("actions", [])
    entry.setdefault("when", "")
    entry["mind"] = "stub"
    return entry


def ollama_mind(entry: dict, model: str) -> dict:
    text = (entry.get("text") or "").strip()
    if not text or not have("ollama"):
        return stub_mind(entry)
    prompt = (
        "Return JSON only, keys: title (short), summary (one or two sentences), "
        "tags (array of 1-4 lowercase words). No markdown.\n"
        f"Kind: {entry.get('kind')}\n"
        f"Text:\n{text[:4000]}\n"
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
    when = str(data.get("when") or "").strip()
    if when.lower() in ("", "none", "null", "n/a"):
        when = ""
    entry["when"] = when[:32]
    entry["mind"] = source


def gemini_parts(entry: dict) -> list:
    kind = entry.get("kind") or "note"
    text = (entry.get("text") or "").strip()
    prompt = (
        "You organise a capture for Nothing Essential Space. "
        "Return JSON only, keys: title (short), summary (one or two sentences), "
        "tags (array of 1-4 lowercase words), actions (array of short next steps, "
        "empty if none), when (ISO 8601 datetime if this is a reminder, deadline, "
        "event or appointment to remember, else empty string). "
        "Library stores every capture with its summary. For You only gets items "
        "with a real when datetime. No markdown.\n"
        f"Kind: {kind}\n"
        f"Text:\n{text[:4000]}\n"
    )
    parts: list = [{"text": prompt}]
    path = Path(entry.get("path") or "")
    if not path.is_file():
        return parts
    suffix = path.suffix.lower()
    mime = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
            ".webp": "image/webp"}.get(suffix)
    if not mime:
        return parts
    try:
        raw = path.read_bytes()
    except OSError:
        return parts
    if not raw or len(raw) > 4_000_000:
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
        with urllib.request.urlopen(req, timeout=45) as resp:
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
    else:
        fail("unknown command: " + cmd, 2)


if __name__ == "__main__":
    main()
