pragma Singleton

import QtQuick
import Quickshell
import ".."

// Resolve applications via the system's .desktop files.
// That is what gives real icons and names, rather than guessed
// Nerd Font codepoints.
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications?.values ?? []

    readonly property var visible: root.all
        .filter(e => !e.noDisplay)
        .sort((x, y) => x.name.localeCompare(y.name))

    // Returns a DesktopEntry for a .desktop id or a Hyprland window class.
    // byId("zen") rarely suffices: the real icon is often `zen-browser`,
    // and the class only matches StartupWMClass.
    function entry(id: string): var {
        if (!id)
            return null;
        const tries = [id, id.toLowerCase()];
        for (let i = 0; i < tries.length; i++) {
            const e = DesktopEntries.byId(tries[i]);
            if (e)
                return e;
        }
        // Hyprland class vs StartupWMClass / .desktop id, before
        // heuristicLookup which can glue "zen" to a grey theme icon.
        const lower = id.toLowerCase();
        const all = root.all;
        for (let i = 0; i < all.length; i++) {
            const e = all[i];
            const wm = (e.startupClass ?? "").toLowerCase();
            const eid = (e.id ?? "").toLowerCase();
            if (wm === lower || eid === lower)
                return e;
        }
        for (let i = 0; i < tries.length; i++) {
            const e = DesktopEntries.heuristicLookup(tries[i]);
            if (e)
                return e;
        }
        return null;
    }

    // Hyprland class -> .desktop icon name. Without this, iconPath("zen")
    // finds nothing (the icon is named zen-browser).
    readonly property var iconAliases: ({
        zen: "zen-browser",
        helium: "helium-browser",
        "helium-browser": "helium-browser",
        dolphin: "org.kde.dolphin",
        "org.kde.dolphin": "org.kde.dolphin",
        spotify: "spotify-client",
        cursor: "co.anysphere.cursor",
        "co.anysphere.cursor": "co.anysphere.cursor",
    })

    function iconNames(id: string): var {
        const names = [];
        const seen = {};
        const add = n => {
            if (!n)
                return;
            const s = String(n);
            if (seen[s])
                return;
            seen[s] = true;
            names.push(s);
        };
        const e = root.entry(id);
        add(e?.icon);
        add(id);
        if (id)
            add(id.toLowerCase());
        add(root.iconAliases[(id ?? "").toLowerCase()]);
        return names;
    }

    function toImageUrl(p: string): string {
        if (!p)
            return "";
        if (p.includes("://") || p.startsWith("qrc:"))
            return p;
        if (p.startsWith("/"))
            return "file://" + p;
        return p;
    }

    // URLs to try in order. iconPath(..., true) often skips
    // hicolor/pixmaps: known paths are then added, without listing
    // missing files (each Image failure pollutes the log).
    function iconCandidates(id: string): var {
        const names = root.iconNames(id);
        const urls = [];
        const seen = {};
        const addUrl = u => {
            if (!u || seen[u])
                return;
            seen[u] = true;
            urls.push(u);
        };
        for (let i = 0; i < names.length; i++) {
            const n = names[i];
            if (n.startsWith("/") || n.includes("://")) {
                addUrl(root.toImageUrl(n));
                continue;
            }
            if (Quickshell.hasThemeIcon(n))
                addUrl(root.toImageUrl(Quickshell.iconPath(n)));
            const known = root.knownIconFiles[n];
            if (known) {
                for (let j = 0; j < known.length; j++)
                    addUrl(known[j]);
            }
        }
        return urls;
    }

    // Real paths as a last resort (the Qogir catalogue is tried first).
    readonly property var knownIconFiles: ({
        "zen-browser": [
            "file:///usr/share/icons/Qogir-Dark/scalable/apps/zen.svg",
            "file:///opt/zen-browser-bin/browser/chrome/icons/default/default48.png",
            "file:///usr/share/icons/hicolor/48x48/apps/zen-browser.png"
        ],
        "helium-browser": [
            "file:///usr/share/icons/hicolor/256x256/apps/helium-browser.png",
            "file:///usr/share/pixmaps/helium-browser.png"
        ],
        kitty: [
            "file:///usr/share/icons/Qogir-Dark/scalable/apps/kitty.svg",
            "file://" + Quickshell.shellPath("assets/icons/kitty.png")
        ],
        vesktop: [
            "file:///usr/share/icons/Qogir-Dark/scalable/apps/vesktop.svg",
            "file:///usr/share/icons/hicolor/scalable/apps/vesktop.svg"
        ],
        "spotify-client": [
            "file:///usr/share/icons/Qogir-Dark/scalable/apps/spotify.svg"
        ],
        spotify: [
            "file:///usr/share/icons/Qogir-Dark/scalable/apps/spotify.svg"
        ],
        "co.anysphere.cursor": [
            "file:///usr/share/pixmaps/co.anysphere.cursor.png"
        ],
        cursor: [
            "file:///usr/share/pixmaps/co.anysphere.cursor.png"
        ]
    })

    function iconFor(id: string): string {
        const c = root.iconCandidates(id);
        return c.length > 0 ? c[0] : "";
    }

    function nameFor(id: string): string {
        return root.entry(id)?.name ?? id;
    }

    // Expected Hyprland class for this app (used by the dock indicator dot).
    function classFor(id: string): string {
        const e = root.entry(id);
        return (e?.startupClass || e?.id || id).toLowerCase();
    }

    function launch(id: string): void {
        const e = root.entry(id);
        if (e) e.execute();
    }

    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (q === "") return root.visible;
        return root.visible.filter(e =>
            e.name.toLowerCase().includes(q)
            || (e.genericName ?? "").toLowerCase().includes(q)
            || (e.comment ?? "").toLowerCase().includes(q)
            || (e.id ?? "").toLowerCase().includes(q));
    }
}
