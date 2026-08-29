pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Essential Search: prefixes switch the mode; with no prefix, apps,
// actions, Essential Space captures and settings are mixed. Ask sends
// the query to Gemini without leaving the overlay.
Singleton {
    id: root

    readonly property var prefixes: ({
        action:  "/",
        app:     ">",
        clip:    ";",
        emoji:   ":",
        math:    "=",
        shell:   "$",
        web:     "?"
    })

    property string query: ""
    property string mathResult: ""
    property var emojis: []
    property string askAnswer: ""
    property string askFor: ""
    property bool askBusy: false

    readonly property string engine: "https://duckduckgo.com/?q="

    // ── Emoji, loaded once ────────────────────────────────────────────
    // Read via a process rather than FileView: its onLoaded signal fires
    // before the text property is populated, and JSON.parse would get
    // an empty string.
    Process {
        running: true
        command: ["cat", Quickshell.shellPath("assets/emoji.json")]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.emojis = JSON.parse(text); }
                catch (e) { console.warn("emoji.json unreadable", e); }
            }
        }
    }

    // ── Calculator via qalc ─────────────────────────────────────────
    Process {
        id: math
        stdout: StdioCollector {
            onStreamFinished: root.mathResult = text.trim()
        }
    }

    function compute(expr: string): void {
        if (expr.trim() === "") { root.mathResult = ""; return; }
        math.running = false;
        math.command = ["qalc", "-t", expr];
        math.running = true;
    }

    Process { id: runner }
    function run(cmd: string): void {
        runner.command = ["sh", "-c", cmd];
        runner.running = true;
    }

    Process {
        id: asker
        property string payload: ""
        onRunningChanged: {
            if (running) {
                write(payload);
                stdinEnabled = false;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.askBusy = false;
                if (root.body(root.query).trim() !== root.askFor)
                    return;
                try {
                    const data = JSON.parse(text);
                    root.askAnswer = (data.answer || "").trim() || "No answer";
                } catch (e) {
                    root.askAnswer = text.trim() || "Ask failed";
                }
            }
        }
        onExited: (code) => {
            if (!root.askBusy)
                return;
            root.askBusy = false;
            if (code !== 0 && root.askAnswer === "")
                root.askAnswer = "Ask failed";
        }
    }

    function askReady(q: string): bool {
        return root.prefixOf(q) === "" && root.body(q).trim() !== "";
    }

    function askNow(q: string): void {
        const text = root.body(q).trim();
        if (text === "")
            return;
        root.askBusy = true;
        root.askAnswer = "";
        root.askFor = text;
        asker.payload = text;
        asker.running = false;
        asker.command = ["python3", Essentials.script, "ask"];
        asker.stdinEnabled = true;
        asker.running = true;
    }

    function clearAsk(): void {
        asker.running = false;
        root.askBusy = false;
        root.askAnswer = "";
        root.askFor = "";
    }

    function openCapture(id: string): void {
        if ((id ?? "") === "")
            return;
        GlobalState.closeAll();
        GlobalState.essentialFocus = id;
        GlobalState.essentialOpen = true;
    }

    function openApp(id: string): void {
        if ((id ?? "") === "")
            return;
        GlobalState.closeAll();
        GlobalState.appsFocus = id;
        GlobalState.appsOpen = true;
    }

    function matchApps(needle: string): var {
        const parts = needle.trim().toLowerCase().split(/\s+/).filter(p => p !== "");
        if (parts.length === 0)
            return [];
        const src = MiniApps.specs;
        const hits = [];
        for (let i = 0; i < src.length; i++) {
            const spec = src[i];
            const hay = [spec.name ?? "", spec.prompt ?? ""].join(" ").toLowerCase();
            let ok = true;
            for (let j = 0; j < parts.length; j++) {
                if (!hay.includes(parts[j])) {
                    ok = false;
                    break;
                }
            }
            if (ok)
                hits.push(spec);
        }
        return hits;
    }

    function openSetting(page: int, key: string): void {
        GlobalState.closeAll();
        GlobalState.settingsPage = page;
        GlobalState.settingsFocus = key;
        GlobalState.settingsOpen = true;
    }

    function captureIcon(kind: string): string {
        switch (kind) {
        case "snip": return "󰄀";
        case "ocr": return "󰈚";
        case "clip": return "󰅌";
        case "record": return "󰑊";
        case "voice": return "󰍬";
        case "song": return "󰎈";
        case "calc": return "󰃬";
        default: return "󰠮";
        }
    }

    function captureHay(it: var): string {
        const tags = it.tags ?? [];
        return [
            it.kind ?? "", it.title ?? "", it.summary ?? "",
            it.text ?? "", tags.join(" "), it.when ?? ""
        ].join(" ").toLowerCase();
    }

    function matchCaptures(needle: string): var {
        const parts = needle.trim().toLowerCase().split(/\s+/).filter(p => p !== "");
        if (parts.length === 0)
            return [];
        const src = Essentials.items;
        const hits = [];
        for (let i = 0; i < src.length; i++) {
            const it = src[i];
            const hay = root.captureHay(it);
            let ok = true;
            for (let j = 0; j < parts.length; j++) {
                if (!hay.includes(parts[j])) {
                    ok = false;
                    break;
                }
            }
            if (ok)
                hits.push(it);
        }
        const q = needle.toLowerCase();
        hits.sort((a, b) => {
            const at = (a.title || "").toLowerCase().includes(q) ? 0 : 1;
            const bt = (b.title || "").toLowerCase().includes(q) ? 0 : 1;
            return at - bt;
        });
        return hits;
    }

    // ── Shell actions ─────────────────────────────────────────────────
    readonly property var actions: [
        { name: "settings",   label: "Open settings",        icon: "󰒓",
          run: () => GlobalState.settingsOpen = true },
        { name: "shortcuts", label: "Keyboard shortcuts", icon: "󰌌",
          run: () => GlobalState.cheatsheetOpen = true },
        { name: "essential", label: "Essential Space", icon: "󰠮",
          run: () => { GlobalState.closeAll(); GlobalState.essentialOpen = true; } },
        { name: "apps", label: "Essential Apps", icon: "󰀻",
          run: () => { GlobalState.closeAll(); GlobalState.appsOpen = true; } },
        { name: "game",        label: "Toggle game mode",        icon: "󰊴",
          run: () => Game.toggle() },
        { name: "crosshair",     label: "Toggle crosshair",        icon: "󰆤",
          run: () => { Config.crosshair = !Config.crosshair; Config.save(); } },
        { name: "screenshot",    label: "Capture a selection",      icon: "󰄀",
          run: () => Shot.capture("region", "copy") },
        { name: "ocr",        label: "OCR a selection",         icon: "󰈚",
          run: () => Shot.capture("region", "ocr") },
        { name: "record", label: "Record the screen",        icon: "󰑊",
          run: () => Recorder.toggle("screen", false) },
        { name: "dnd",    label: "Do not disturb",             icon: "󰂛",
          run: () => Notifs.doNotDisturb = !Notifs.doNotDisturb },
        { name: "notifications", label: "Clear notifications", icon: "󰩹",
          run: () => Notifs.clearHistory() },
        { name: "clipboard", label: "Clear the clipboard", icon: "󰅍",
          run: () => Clipboard.wipe() },
        // Power.lock() calls hyprlock directly: "loginctl lock-session"
        // goes through hypridle, which caffeine mode kills.
        { name: "lock", label: "Lock the session",     icon: "󰌾",
          run: () => Power.lock() },
        { name: "suspend",     label: "Suspend",            icon: "󰒲",
          run: () => Power.suspend() },
        { name: "session",    label: "Session menu",             icon: "󰐥",
          run: () => GlobalState.sessionOpen = true },
        { name: "reload",  label: "Restart the shell",         icon: "󰑐",
          run: () => Power.restartShell() }
    ]

    // ── Query parsing ─────────────────────────────────────────────────
    function prefixOf(q: string): string {
        for (const k of Object.keys(root.prefixes))
            if (q.startsWith(root.prefixes[k])) return k;
        return "";
    }

    function body(q: string): string {
        const p = root.prefixOf(q);
        return p === "" ? q : q.slice(root.prefixes[p].length);
    }

    // ── Building results ──────────────────────────────────────────────
    // Each entry: { kind, title, subtitle, icon, appId, emoji, run }
    readonly property var results: {
        const q = root.query;
        const mode = root.prefixOf(q);
        const text = root.body(q).trim();
        const out = [];

        if (mode === "clip") {
            const _ = Clipboard.stamp;
            for (const it of Clipboard.search(text).slice(0, 30)) {
                out.push({
                    kind: "clip", title: it.preview,
                    subtitle: it.isImage ? "Image" : "Clipboard",
                    icon: it.isImage ? "󰋩" : "󰅍",
                    run: () => Clipboard.copy(it.id, it.preview)
                });
            }
            return out;
        }

        if (mode === "emoji") {
            const needle = text.toLowerCase();
            const pool = needle === ""
                ? root.emojis.slice(0, 60)
                : root.emojis.filter(e => e.k.includes(needle)).slice(0, 60);
            for (const e of pool) {
                out.push({
                    kind: "emoji", title: e.e,
                    subtitle: e.k.split(" ").slice(0, 4).join(" "),
                    emoji: e.e,
                    run: () => root.run(`printf '%s' ${JSON.stringify(e.e)} | wl-copy`)
                });
            }
            return out;
        }

        // Captures and settings sit above apps: Essential Search is
        // meant to find a note or a toggle before launching Firefox.
        if (mode === "" && text !== "") {
            const _ = Essentials.stamp;
            const caps = root.matchCaptures(text).slice(0, 6);
            for (const it of caps) {
                const title = (it.title || it.summary || (it.text || "").slice(0, 60)
                    || "Capture").toString();
                const tags = (it.tags || []).join(" · ");
                const sub = tags !== ""
                    ? `${it.kind || "note"} · ${tags}`
                    : (it.kind || "note");
                const capId = it.id || "";
                out.push({
                    kind: "capture", title: title,
                    subtitle: sub,
                    icon: root.captureIcon(it.kind || "note"),
                    run: () => root.openCapture(capId)
                });
            }
            const _apps = MiniApps.stamp;
            const mini = root.matchApps(text).slice(0, 4);
            for (const spec of mini) {
                const appId = spec.id || "";
                // Not "app": the launcher routes that kind to AppIcon and
                // a .desktop icon name, which a generated app does not have.
                out.push({
                    kind: "miniapp", title: spec.name || "App",
                    subtitle: "Essential App",
                    icon: spec.icon || "󰀻",
                    run: () => root.openApp(appId)
                });
            }
            const sets = SettingsIndex.search(text).slice(0, 5);
            for (const e of sets) {
                const page = e.page;
                const key = e.key;
                out.push({
                    kind: "setting", title: e.label,
                    subtitle: "Settings",
                    icon: "󰒓",
                    run: () => root.openSetting(page, key)
                });
            }
        }

        if (mode === "action" || text !== "") {
            const needle = (mode === "action" ? text : q).toLowerCase();
            for (const a of root.actions) {
                if (mode !== "action" && needle !== ""
                        && !a.name.includes(needle) && !a.label.toLowerCase().includes(needle))
                    continue;
                if (mode === "action" && needle !== ""
                        && !a.name.includes(needle) && !a.label.toLowerCase().includes(needle))
                    continue;
                out.push({
                    kind: "action", title: a.label,
                    subtitle: root.prefixes.action + a.name,
                    icon: a.icon, run: a.run
                });
            }
            if (mode === "action") return out;
        }

        // Calculator, prioritised if explicitly requested
        if (mode === "math" || (text !== "" && /^[\d\s().+\-*\/^%]+$/.test(text) && /[\d]/.test(text))) {
            const shown = root.mathResult !== "" ? root.mathResult : "…";
            const entry = {
                kind: "math", title: shown, subtitle: text + " =",
                icon: "󰪚",
                run: () => root.run(`printf '%s' ${JSON.stringify(root.mathResult)} | wl-copy`)
            };
            if (mode === "math") out.unshift(entry); else out.push(entry);
        }

        if (mode === "shell" && text !== "") {
            out.unshift({
                kind: "shell", title: text, subtitle: "Run the command",
                icon: "󰆍", run: () => root.run(`${text} &`)
            });
        }

        if (mode === "web" && text !== "") {
            out.unshift({
                kind: "web", title: text, subtitle: "Search the web",
                icon: "󰖟",
                run: () => root.run(`xdg-open ${JSON.stringify(root.engine + encodeURIComponent(text))}`)
            });
        }

        // Applications
        if (mode === "" || mode === "app") {
            const apps = Apps.search(text).slice(0, 40);
            for (const e of apps) {
                out.push({
                    kind: "app", title: e.name,
                    subtitle: e.genericName || e.comment || "",
                    iconName: e.icon, entry: e,
                    run: () => e.execute()
                });
            }
        }

        // Fallbacks when nothing matches
        if (mode === "" && text !== "" && out.length === 0) {
            out.push({
                kind: "web", title: text, subtitle: "Search the web",
                icon: "󰖟",
                run: () => root.run(`xdg-open ${JSON.stringify(root.engine + encodeURIComponent(text))}`)
            });
            out.push({
                kind: "shell", title: text, subtitle: "Run the command",
                icon: "󰆍", run: () => root.run(`${text} &`)
            });
        }

        return out;
    }

    // Calculator is async: restart on every useful keystroke.
    onQueryChanged: {
        const mode = root.prefixOf(query);
        const text = root.body(query).trim();
        if (mode === "math" || (/^[\d\s().+\-*\/^%]+$/.test(text) && /[\d]/.test(text)))
            root.compute(text);
        else
            root.mathResult = "";
        if (text !== root.askFor)
            root.askAnswer = "";
    }

    readonly property var hints: [
        { p: ">", label: "applications" },
        { p: ";", label: "clipboard" },
        { p: ":", label: "emoji" },
        { p: "=", label: "calculator" },
        { p: "$", label: "command" },
        { p: "?", label: "web" },
        { p: "/", label: "actions" }
    ]

    // Label of the current mode, shown in the search bar.
    function modeLabel(q: string): string {
        switch (root.prefixOf(q)) {
        case "clip":   return "Clipboard";
        case "emoji":  return "Emoji";
        case "math":   return "Calculator";
        case "shell":  return "Command";
        case "web":    return "Web";
        case "action": return "Actions";
        case "app":    return "Applications";
        default:       return "";
        }
    }
}
