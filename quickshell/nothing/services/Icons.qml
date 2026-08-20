pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Icon pack. Nothing = Lawnicons (mono glyphs) on dark squircles.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string script:
        Quickshell.shellPath("../../scripts/apply-icon-theme.sh")

    readonly property var presets: [
        { label: "Nothing",     value: "Nothing" },
        { label: "Qogir Dark",  value: "Qogir-Dark" },
        { label: "Qogir",       value: "Qogir" },
        { label: "Breeze Dark", value: "breeze-dark" },
        { label: "Breeze",      value: "breeze" },
        { label: "Adwaita",     value: "Adwaita" }
    ]

    readonly property var available: root.presets

    readonly property string indexerScript:
        Quickshell.shellPath("../../scripts/index-icon-theme.py")

    property var catalog: ({})
    property var named: ({})

    readonly property string packName: {
        const t = Config.iconTheme || "Nothing";
        return t === "Nothing" ? "Qogir-Dark" : t;
    }

    function keysFor(name: string): var {
        if (!name)
            return [];
        let raw = String(name).toLowerCase().replace(/\.desktop$/i, "");
        if (raw.includes("://")) {
            const cut = raw.lastIndexOf("/");
            raw = cut >= 0 ? raw.slice(cut + 1) : raw;
        }
        if (raw.startsWith("/")) {
            const cut = raw.lastIndexOf("/");
            raw = cut >= 0 ? raw.slice(cut + 1) : raw;
        }
        raw = raw.replace(/\.(svg|png|xpm|jpg)$/i, "");
        if (!raw || raw.includes("/") || raw.includes("\\"))
            return [];
        const keys = [raw];
        const add = k => {
            if (k && keys.indexOf(k) < 0)
                keys.push(k);
        };
        if (raw.endsWith("-client"))
            add(raw.slice(0, -7));
        if (raw.startsWith("org.kde."))
            add(raw.slice(8));
        if (raw === "com.google.chrome" || raw === "google-chrome-stable"
            || raw === "chrome")
            add("google-chrome");
        if (raw === "zen-browser" || raw === "zen") {
            add("zen");
            add("io.github.zen_browser.zen");
        }
        if (raw === "helium" || raw === "helium-browser") {
            add("helium-browser");
            add("helium");
            add("internet-browser");
            add("internet_browser");
        }
        if (raw === "vesktop" || raw === "discord") {
            add("vesktop");
            add("discord");
        }
        if (raw.indexOf(".") === -1 && (raw.startsWith("k") || raw === "dolphin"
            || raw === "kate" || raw === "okular" || raw === "konsole"
            || raw === "ark" || raw === "gwenview" || raw === "spectacle")) {
            add("org.kde." + raw);
        }
        if (raw.includes("-"))
            add(raw.replace(/-/g, "_"));
        if (raw.includes("_"))
            add(raw.replace(/_/g, "-"));
        return keys;
    }

    // Lawnicons squircles only, not vendor logos (Inherits=Qogir).
    function packPathsFor(name: string): var {
        const keys = root.keysFor(name);
        const urls = [];
        const seen = {};
        const add = u => {
            if (!u || seen[u])
                return;
            seen[u] = true;
            urls.push(u);
        };
        const cat = root.catalog;
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            const u = cat[k];
            if (u && String(u).indexOf("/icons/Nothing/") >= 0) {
                add(u);
                continue;
            }
            const p = Quickshell.iconPath(k, true);
            if (p && String(p).indexOf("/icons/Nothing/") >= 0) {
                if (p.startsWith("/"))
                    add("file://" + p);
                else if (p.includes("://"))
                    add(p);
                else
                    add(p);
            }
        }
        return urls;
    }

    // SNI tray: the id is often chrome_status_icon_1; the tooltip names the app.
    function trayKey(item: var): string {
        if (!item)
            return "";
        const id = String(item.id ?? "").toLowerCase();
        const title = String(item.title ?? "").toLowerCase();
        const tip = String(item.tooltipTitle ?? "").toLowerCase();
        const blob = `${id} ${title} ${tip}`;
        if (blob.indexOf("spotify") >= 0)
            return "spotify";
        if (blob.indexOf("vesktop") >= 0 || blob.indexOf("discord") >= 0)
            return "vesktop";
        if (blob.indexOf("cursor") >= 0)
            return "cursor";
        if (id && id.indexOf("chrome_status") < 0 && id.indexOf(":") < 0)
            return id;
        return title || tip;
    }

    function pathsFor(name: string): var {
        const keys = root.keysFor(name);
        const urls = [];
        const seen = {};
        const add = u => {
            if (!u || seen[u])
                return;
            seen[u] = true;
            urls.push(u);
        };
        const cat = root.catalog;
        for (let i = 0; i < keys.length; i++) {
            const u = cat[keys[i]];
            if (u)
                add(u);
        }
        return urls;
    }

    function lookup(name: string): string {
        const p = root.pathsFor(name);
        return p.length > 0 ? p[0] : "";
    }

    function apply(name: string, reload: bool): void {
        if (!name)
            return;
        if (Config.iconTheme !== name) {
            Config.iconTheme = name;
            Config.save();
        }
        Quickshell.execDetached(["bash", root.script, name]);
        scanDelay.restart();
        if (reload)
            applyReload.restart();
    }

    function scan(): void {
        lister.running = false;
        lister.running = true;
    }

    Timer {
        id: scanDelay
        interval: 400
        onTriggered: root.scan()
    }

    Timer {
        id: applyReload
        interval: 800
        onTriggered: Quickshell.reload(true)
    }

    Process {
        id: lister
        running: true
        command: ["python3", root.indexerScript, root.packName,
                  Config.iconTheme || "Nothing"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                const n = {};
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    const tab = line.indexOf("\t");
                    if (tab < 1)
                        continue;
                    const k = line.slice(0, tab);
                    m[k] = line.slice(tab + 1);
                    n[k] = true;
                }
                root.catalog = m;
                root.named = n;
            }
        }
    }

    Connections {
        target: Config
        function onReadyChanged(): void {
            if (Config.ready)
                root.apply(Config.iconTheme, false);
        }
        function onIconThemeChanged(): void {
            lister.running = false;
            lister.running = true;
        }
    }

    Component.onCompleted: {
        if (Config.ready)
            root.apply(Config.iconTheme, false);
    }
}
