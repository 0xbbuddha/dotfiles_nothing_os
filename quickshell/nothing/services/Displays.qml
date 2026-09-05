pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

// The screens, and how they are arranged.
//
// Hyprland has no interface for this: you either edit a config file and
// reload, or you remember hyprctl's monitor syntax. That is fine once and
// tiresome every time you plug something in, which is why every other
// desktop has a Super+P.
//
// Read with `hyprctl -j monitors all`, because Quickshell's own monitor
// list only carries the ones currently on. A screen you switched off has
// to stay in the list or there is no way to switch it back.
//
// Written with `hyprctl eval`, not `hyprctl keyword`: this rice configures
// Hyprland in Lua, and keyword answers "can't work with non-legacy
// parsers". The Lua call takes output, mode, position, scale, transform,
// disabled, mirror, vrr and bitdepth; it rejects anything else by name,
// which is how that list was established.
Singleton {
    id: root

    // One entry per screen, on or off, straight from Hyprland.
    property var screens: []
    property bool busy: false

    readonly property var active: root.screens.filter(s => !s.disabled)

    function byName(name: string): var {
        return root.screens.find(s => s.name === name) ?? null;
    }

    // The whole desktop's bounding box, for drawing the map.
    readonly property var bounds: {
        const on = root.active;
        if (on.length === 0)
            return { x: 0, y: 0, w: 1, h: 1 };
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (const s of on) {
            x0 = Math.min(x0, s.x);
            y0 = Math.min(y0, s.y);
            x1 = Math.max(x1, s.x + s.w);
            y1 = Math.max(y1, s.y + s.h);
        }
        return { x: x0, y: y0, w: Math.max(1, x1 - x0), h: Math.max(1, y1 - y0) };
    }

    // ── Reading ───────────────────────────────────────────────────────
    function refresh(): void {
        lister.running = false;
        lister.running = true;
    }

    NProcess {
        id: lister
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = [];
                try {
                    raw = JSON.parse(text);
                } catch (e) {
                    console.warn("displays: unreadable monitor list", e);
                    return;
                }
                const out = [];
                for (const m of raw) {
                    out.push({
                        name: m.name ?? "",
                        // "Make Model Serial" is what a person recognises;
                        // the connector name is what Hyprland wants.
                        label: [m.make, m.model].filter(x => x && x !== "Unknown")
                                                .join(" ") || (m.description ?? m.name),
                        w: m.width ?? 0,
                        h: m.height ?? 0,
                        hz: m.refreshRate ?? 0,
                        x: m.x ?? 0,
                        y: m.y ?? 0,
                        scale: m.scale ?? 1,
                        transform: m.transform ?? 0,
                        disabled: m.disabled === true,
                        mirrorOf: m.mirrorOf && m.mirrorOf !== "none"
                            ? m.mirrorOf : "",
                        focused: m.focused === true,
                        modes: root.tidyModes(m.availableModes ?? [])
                    });
                }
                root.screens = out;
            }
        }
    }

    // "1920x1080@60.00Hz" is Hyprland's own spelling and also what
    // hl.monitor accepts back, so the string is kept whole and only the
    // label is prettied.
    function tidyModes(list: var): var {
        const seen = {};
        const out = [];
        for (const m of list) {
            const p = String(m).match(/^(\d+)x(\d+)@([\d.]+)/);
            if (!p)
                continue;
            const key = p[1] + "x" + p[2] + "@" + Math.round(parseFloat(p[3]));
            if (seen[key])
                continue;
            seen[key] = true;
            out.push({
                id: String(m),
                w: parseInt(p[1]),
                h: parseInt(p[2]),
                hz: Math.round(parseFloat(p[3])),
                label: p[1] + " x " + p[2] + "  " + Math.round(parseFloat(p[3])) + " Hz"
            });
        }
        return out;
    }

    // ── Writing ───────────────────────────────────────────────────────
    //
    // One eval per screen. Passed as its own argv entry, never through a
    // shell, so a monitor description with a quote in it cannot become
    // part of the command.
    function lua(spec: var): string {
        const parts = [];
        for (const k in spec) {
            const v = spec[k];
            parts.push(k + " = " + (typeof v === "string"
                ? JSON.stringify(v) : String(v)));
        }
        return "hl.monitor({ " + parts.join(", ") + " })";
    }

    // Every screen in one call, deliberately.
    //
    // One hyprctl per screen looks equivalent and is not: Hyprland lays
    // the others out again after each rule, asynchronously, so the second
    // command's position was routinely clobbered by the first command's
    // re-layout landing late. A screen would end up 120px lower than
    // asked for, every other time. A single Lua chunk is applied as one
    // batch, and the positions hold.
    //
    // hyprctl eval wraps its argument in `return`, so the chunk has to be
    // one expression: hence the function, called immediately.
    function chunk(specs: var): string {
        const calls = specs.map(spec => root.lua(spec));
        return "(function() " + calls.join(" ") + " return \"ok\" end)()";
    }

    function apply(specs: var): void {
        if (!specs || specs.length === 0)
            return;
        root.busy = true;
        writer.command = ["hyprctl", "eval", root.chunk(specs)];
        writer.running = false;
        writer.running = true;
    }

    NProcess {
        id: writer
        onExited: {
            root.busy = false;
            // Hyprland finishes laying out after the call returns, so the
            // list is only true a moment later.
            settle.restart();
        }
    }

    Timer {
        id: settle
        interval: 350
        onTriggered: root.refresh()
    }

    // ── Applied on approval ───────────────────────────────────────────
    //
    // A mode the screen cannot actually show leaves it black, and a black
    // screen is the one thing you cannot repair from the panel that
    // blacked it. So a change that decides how a screen displays is put
    // on trial: the layout it replaced is held, and it comes back on its
    // own unless somebody says to keep it.
    //
    // Position is not on trial (a screen moved is a screen you can still
    // see) and neither is switching one off, which refuses to take the
    // last one and so always leaves you somewhere to switch it back from.
    property var undoTo: []
    property bool confirming: false
    property int countdown: 0
    readonly property int grace: 15

    // The current layout as the specs that would recreate it.
    function specsNow(): var {
        const out = [];
        for (const s of root.screens) {
            if (s.disabled) {
                out.push({ output: s.name, disabled: true });
                continue;
            }
            out.push({
                output: s.name,
                mode: s.w + "x" + s.h + "@" + s.hz.toFixed(2),
                position: s.x + "x" + s.y,
                scale: s.scale,
                transform: s.transform,
                mirror: s.mirrorOf !== "" ? s.mirrorOf : "none"
            });
        }
        return out;
    }

    function tryOut(specs: var): void {
        // Chained experiments rewind to where you started, not to the
        // last thing you tried, which was already wrong.
        if (!root.confirming)
            root.undoTo = root.specsNow();
        root.confirming = true;
        root.countdown = root.grace;
        root.apply(specs);
    }

    function keep(): void {
        root.confirming = false;
        root.undoTo = [];
    }

    function revert(): void {
        const back = root.undoTo;
        root.confirming = false;
        root.undoTo = [];
        if (back.length > 0)
            root.apply(back);
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        running: root.confirming
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0)
                root.revert();
        }
    }

    // ── The four arrangements ─────────────────────────────────────────
    //
    // Named after what they do rather than after Windows' wording: nobody
    // has ever known which way round "Second screen only" was.
    function only(name: string): void {
        const specs = [];
        for (const s of root.screens) {
            if (s.name === name)
                specs.push({ output: s.name, mode: "preferred",
                             position: "0x0", scale: s.scale });
            else
                specs.push({ output: s.name, disabled: true });
        }
        root.tryOut(specs);
    }

    function duplicate(): void {
        const on = root.screens.filter(s => !s.disabled);
        if (on.length < 2)
            return;
        // The focused screen is the one you are looking at, so it is the
        // one the others copy.
        const src = (on.find(s => s.focused) ?? on[0]).name;
        const specs = [{ output: src, mode: "preferred", position: "0x0",
                         scale: root.byName(src)?.scale ?? 1 }];
        for (const s of root.screens)
            if (s.name !== src)
                specs.push({ output: s.name, mode: "preferred",
                             position: "auto", scale: 1, mirror: src });
        root.tryOut(specs);
    }

    function extend(): void {
        // Left to right in the order they already sit, so extending does
        // not shuffle a layout you had arranged.
        const list = root.screens.slice().sort((a, b) =>
            (a.disabled ? 1 : 0) - (b.disabled ? 1 : 0) || a.x - b.x);
        const specs = [];
        let x = 0;
        for (const s of list) {
            specs.push({ output: s.name, mode: "preferred",
                         position: x + "x0", scale: s.scale, mirror: "none" });
            // Logical width: a screen at scale 2 takes half the room.
            x += Math.round(s.w / (s.scale > 0 ? s.scale : 1));
        }
        root.tryOut(specs);
    }

    // ── Per screen ────────────────────────────────────────────────────
    //
    // Every one of these sends the whole layout, not just the screen you
    // touched. A monitor rule of `position = "auto"` is re-evaluated
    // whenever any rule is applied, so changing one screen's mode used to
    // slide its neighbour somewhere else. Restating each position pins
    // them, and only the screen you asked about moves.
    function withChange(name: string, patch: var): var {
        const specs = root.specsNow();
        for (const spec of specs) {
            if (spec.output !== name || spec.disabled === true)
                continue;
            for (const k in patch)
                spec[k] = patch[k];
        }
        return specs;
    }

    function setMode(name: string, mode: string): void {
        if (!root.byName(name)) return;
        root.tryOut(root.withChange(name, { mode: mode }));
    }

    function setScale(name: string, scale: real): void {
        if (!root.byName(name)) return;
        root.tryOut(root.withChange(name, { scale: scale }));
    }

    function setTransform(name: string, t: int): void {
        if (!root.byName(name)) return;
        root.tryOut(root.withChange(name, { transform: t }));
    }

    function setEnabled(name: string, on: bool): void {
        if (!on) {
            // Refuse to leave the session with nothing to draw on.
            if (root.active.length <= 1)
                return;
            const off = root.specsNow();
            for (let i = 0; i < off.length; i++)
                if (off[i].output === name)
                    off[i] = { output: name, disabled: true };
            root.apply(off);
            return;
        }
        // A screen coming back has no geometry worth restating, so it is
        // the one allowed to place itself: the others are pinned, so auto
        // can only move this one.
        const back = root.specsNow();
        for (let i = 0; i < back.length; i++)
            if (back[i].output === name)
                back[i] = { output: name, mode: "preferred",
                            position: "auto", scale: 1 };
        root.apply(back);
    }

    function setPosition(name: string, x: int, y: int): void {
        if (!root.byName(name)) return;
        root.apply(root.withChange(name, {
            position: Math.round(x) + "x" + Math.round(y),
            mirror: "none"
        }));
    }

    // ── Keeping it ────────────────────────────────────────────────────
    //
    // hyprctl eval only lives as long as the running compositor: the next
    // reload puts every screen back where the config file says. So the
    // arrangement is written out as the same Lua calls, into a file
    // hypr/hyprland/monitors.lua loads at the end of itself, and a layout
    // arranged by hand survives a reload, a relog and a reboot.
    readonly property string savePath:
        (Quickshell.env("HOME") ?? "") + "/.config/hypr/displays.lua"

    // True while what is on screen is exactly what the file holds, so the
    // Keep button can say whether there is anything left to keep. Compared
    // by text rather than flagged on write: the list refreshes right after
    // saving, and a flag would clear itself every time.
    property string savedText: ""
    readonly property bool saved: root.savedText === root.saveText

    readonly property string saveText: {
        const lines = [
            "-- Written by the Nothing shell's display manager (SUPER+P).",
            "-- Edit freely: it is read back as plain Lua and only rewritten",
            "-- when you press Remember in that panel.",
            ""
        ];
        for (const spec of root.specsNow())
            lines.push(root.lua(spec));
        return lines.join("\n") + "\n";
    }

    function save(): void {
        keeper.setText(root.saveText);
    }

    readonly property bool kept: root.savedText.indexOf("hl.monitor") >= 0

    function forget(): void {
        keeper.setText("-- Cleared. Hyprland's own monitor config applies.\n");
        root.savedText = "";
    }

    FileView {
        id: keeper
        path: root.savePath
        // Missing on a machine that has never kept a layout, which is not
        // a fault worth printing.
        printErrors: false
        onLoaded: root.savedText = keeper.text()
        onSaved: root.savedText = keeper.text()
    }

    Component.onCompleted: root.refresh()

    // A screen appearing or going away is exactly when this list is wrong.
    Connections {
        target: Hyprland.monitors
        function onValuesChanged(): void { settle.restart(); }
    }
}
