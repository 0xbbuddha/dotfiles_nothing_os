#!/usr/bin/env python3
"""What is using the machine, grouped by program, for Settings > Processes.

    procs.py [cpu|mem] [limit]   JSON on stdout

CPU is measured, not averaged: /proc is read twice 0.4 s apart and the
difference is what each program used in that window (ps's %CPU is the
average since the process started, which says a browser idle for an hour
is idle and one that just went wild is fine). 100 % is one full core.
Processes are grouped by name, so twenty browser processes are one row.
Read-only: nothing here sends a signal.
"""
import json
import os
import sys
import time

SORT = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] in ("cpu", "mem") else "cpu"
LIMIT = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 15
ME = os.getuid()
TICK = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
# Ending these takes the session or the sound down with it.
PROTECTED = {"Hyprland", "Xwayland", "quickshell", "qs", "systemd", "dbus-daemon", "dbus-broker",
             "pipewire", "pipewire-pulse", "wireplumber", "sddm", "gdm", "login", "sshd",
             "xdg-desktop-portal", "xdg-desktop-portal-hyprland", "hypridle", "hyprlock"}


def snapshot():
    out = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat", "rb") as f:
                raw = f.read().decode(errors="replace")
            # comm is in parentheses and may itself contain ") "
            name = raw[raw.index("(") + 1:raw.rindex(")")]
            rest = raw[raw.rindex(")") + 2:].split()
            ticks = int(rest[11]) + int(rest[12])      # utime + stime
            rss = int(rest[21]) * PAGE
            uid = os.stat(f"/proc/{pid}").st_uid
            out[int(pid)] = (name, ticks, rss, uid)
        except (OSError, ValueError, IndexError):
            continue
    return out


def meminfo():
    vals = {}
    with open("/proc/meminfo") as f:
        for line in f:
            k, v = line.split(":", 1)
            vals[k] = int(v.split()[0]) * 1024
    return vals.get("MemTotal", 0), vals.get("MemTotal", 0) - vals.get("MemAvailable", 0)


a = snapshot()
t0 = time.monotonic()
time.sleep(0.4)
b = snapshot()
dt = time.monotonic() - t0
me = os.getpid()

groups = {}
for pid, (name, ticks, rss, uid) in b.items():
    if pid == me or rss == 0:          # kernel threads have no memory
        continue
    prev = a.get(pid)
    cpu = ((ticks - prev[1]) / TICK / dt * 100) if prev and prev[0] == name else 0.0
    g = groups.setdefault(name, {"name": name, "pids": [], "cpu": 0.0, "mem": 0, "mine": True})
    g["pids"].append(pid)
    g["cpu"] += max(0.0, cpu)
    g["mem"] += rss
    g["mine"] = g["mine"] and uid == ME

items = sorted(groups.values(), key=lambda g: g[SORT], reverse=True)[:LIMIT]
for g in items:
    g["cpu"] = round(g["cpu"], 1)
    g["protected"] = g["name"] in PROTECTED
total, used = meminfo()
print(json.dumps({"cores": os.cpu_count(), "memTotal": total, "memUsed": used, "items": items}))
