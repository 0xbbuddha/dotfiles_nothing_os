#!/usr/bin/env bash
# Compile every QML file in the shell and report the ones that fail.
#
#   ./scripts/check-qml.sh
#
# Why this exists: qmllint is close to useless here. It does not resolve
# Quickshell types, and it does not resolve this shell's own components
# either, so it stays silent when an import is missing or a type name is
# wrong. Both were verified: removing a needed `import Quickshell.Io` from
# a file using StdioCollector, and renaming a local type to something that
# does not exist, each drew no complaint at all.
#
# Qt.createComponent does resolve types, and it compiles without
# instantiating anything, so nothing here touches the running session.
# A singleton that is already registered cannot be built this way; those
# errors are the harness's own and are filtered out.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
SHELL_DIR="$ROOT/quickshell/nothing"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v qs >/dev/null 2>&1 || { echo "qs (quickshell) not found" >&2; exit 1; }

# Calls into a singleton are resolved at run time, so deleting a function
# still compiles and only fails when someone clicks the thing. That has now
# happened twice: a block edit took Config.enableGlyph with it, and later
# every widget function, leaving the launcher's switches inert. Checked by
# name here instead.
python3 - "$SHELL_DIR" <<'MEMBERS'
import collections, os, re, sys

root = sys.argv[1]
decl = {}
for dp, dn, fn in os.walk(root):
    for f in fn:
        if not f.endswith(".qml"):
            continue
        src = open(os.path.join(dp, f), encoding="utf-8").read()
        if "pragma Singleton" not in src:
            continue
        # Only what the singleton declares at its own indent. A property
        # inside its JsonAdapter is not reachable as Config.x without an
        # alias, and counting those hid exactly that bug: the Strip lost
        # all five of its aliases and nothing noticed.
        names = set(re.findall(r"^    function\s+(\w+)\s*\(", src, re.M))
        names |= set(re.findall(r"^    (?:readonly\s+)?property\s+(?:alias\s+)?[\w<>.]+\s+(\w+)\s*[:{]", src, re.M))
        names |= set(re.findall(r"^    signal\s+(\w+)", src, re.M))
        decl[f[:-4]] = names

bad = collections.defaultdict(set)
for dp, dn, fn in os.walk(root):
    for f in fn:
        if not f.endswith(".qml"):
            continue
        p = os.path.join(dp, f)
        src = open(p, encoding="utf-8").read()
        for sing, names in decl.items():
            if f == sing + ".qml":
                continue
            for m in re.finditer(r"\b%s\.(\w+)" % sing, src):
                # "Config.qml" in a comment is not a member reference
                if m.group(1) not in names and m.group(1) != "qml":
                    bad[sing].add((m.group(1), os.path.relpath(p, root)))

for sing in sorted(bad):
    for member, where in sorted(bad[sing]):
        print("MISSING %s.%s referenced by %s" % (sing, member, where),
              file=sys.stderr)
sys.exit(1 if bad else 0)
MEMBERS
if [[ $? -ne 0 ]]; then
    echo "a singleton member is referenced but not declared." >&2
    exit 1
fi

# A type name is global across every directory the shell imports, so two
# files with the same basename are one type and the loser is unreachable.
# A services/Battery.qml quietly displaced components/glyph/Battery.qml and
# took the whole shell down with "Composite Singleton Type Battery is not
# creatable" from a file that had never heard of the new one. Compiling
# each file on its own cannot see this: the clash only bites on
# instantiation, so it is checked by name here instead.
python3 - "$SHELL_DIR" <<'DUP'
import collections, os, sys
seen = collections.defaultdict(list)
for dp, dn, fn in os.walk(sys.argv[1]):
    for f in fn:
        if f.endswith(".qml"):
            seen[f].append(os.path.relpath(os.path.join(dp, f), sys.argv[1]))
bad = {k: v for k, v in seen.items() if len(v) > 1}
for k, v in sorted(bad.items()):
    print("DUPLICATE TYPE %s: %s" % (k[:-4], ", ".join(sorted(v))), file=sys.stderr)
sys.exit(1 if bad else 0)
DUP
if [[ $? -ne 0 ]]; then
    echo "two files share a type name; rename one." >&2
    exit 1
fi

python3 - "$SHELL_DIR" "$WORK/shell.qml" <<'PY'
import json, sys
from pathlib import Path

shell_dir, out = Path(sys.argv[1]), Path(sys.argv[2])
files = sorted(str(p) for p in shell_dir.rglob("*.qml") if p.name != "shell.qml")
out.write_text('''import Quickshell
import QtQuick

ShellRoot {
    Component.onCompleted: {
        const files = %s;
        let bad = 0;
        for (const f of files) {
            const c = Qt.createComponent("file://" + f, Component.PreferSynchronous);
            if (c.status === Component.Error) {
                const e = c.errorString().trim();
                // A registered singleton cannot be instantiated as a
                // component. That is this harness's limit, not a fault in
                // the file being checked.
                if (e.indexOf("non composite singleton") < 0) {
                    bad++;
                    console.warn("FAIL " + f + "\\n    " + e);
                }
            }
            c.destroy();
        }
        console.log("CHECKED " + files.length + " " + bad);
        Qt.quit();
    }
}
''' % json.dumps(files))
PY

LOG="$WORK/log.txt"
timeout 120 qs -p "$WORK" > "$LOG" 2>&1 || true

# Strip the colour codes quickshell writes even when redirected.
clean() { sed 's/\x1b\[[0-9;]*m//g' "$LOG"; }

clean | grep -E "^\s*WARN qml: FAIL" -A1 | sed 's/^\s*WARN qml: //' || true

line="$(clean | grep -oE "CHECKED [0-9]+ [0-9]+" | tail -1 || true)"
if [[ -z "$line" ]]; then
    echo "the check did not run to completion; raw log:" >&2
    clean >&2
    exit 1
fi

read -r _ total bad <<< "$line"
if [[ "$bad" -eq 0 ]]; then
    printf '%s QML files, all compile.\n' "$total"
else
    printf '%s QML files, %s failed.\n' "$total" "$bad" >&2
    exit 1
fi
