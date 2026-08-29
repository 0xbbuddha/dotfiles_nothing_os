pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import ".."

// Notification server + persistent history.
// The server lives here (not in the bubble window) so history
// survives a panel being closed.
Singleton {
    id: root

    property var popups: []        // currently shown
    property var history: []       // kept
    property bool doNotDisturb: false

    // Monotonic counter: QML hands JS objects to the delegate as copies,
    // so identity comparison fails. Compare keys instead.
    property int nextKey: 1

    readonly property int unread: root.history.filter(n => !n.seen).length

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (n) => {
            n.tracked = true;

            const entry = {
                key: root.nextKey++,
                id: n.id,
                notif: n,
                appName: n.appName,
                appIcon: n.appIcon,
                desktopEntry: n.desktopEntry,
                summary: n.summary,
                body: n.body,
                urgency: n.urgency,
                image: n.image,
                time: new Date(),
                seen: false
            };

            root.history = [entry].concat(root.history).slice(0, 100);
            if (!root.doNotDisturb)
                root.popups = [entry].concat(root.popups).slice(0, 5);
        }
    }

    function appIdOf(entry: var): string {
        const desk = String(entry?.desktopEntry ?? "").trim();
        if (desk)
            return desk;
        const name = String(entry?.appName ?? "").toLowerCase();
        if (name.indexOf("vesktop") >= 0 || name.indexOf("discord") >= 0)
            return "vesktop";
        return String(entry?.appName ?? "").trim();
    }

    function isChat(entry: var): bool {
        const blob = `${entry?.desktopEntry ?? ""} ${entry?.appName ?? ""}`.toLowerCase();
        return blob.indexOf("vesktop") >= 0 || blob.indexOf("discord") >= 0;
    }

    function defaultAction(entry: var): var {
        const acts = entry?.notif?.actions ?? [];
        for (let i = 0; i < acts.length; i++) {
            const id = String(acts[i]?.identifier ?? "").toLowerCase();
            if (id === "default" || id === "open")
                return acts[i];
        }
        return null;
    }

    // Extra buttons (Mark as read…), skipping the hidden default action.
    function listedActions(entry: var): var {
        const acts = entry?.notif?.actions ?? [];
        const out = [];
        for (let i = 0; i < acts.length; i++) {
            const a = acts[i];
            const id = String(a?.identifier ?? "").toLowerCase();
            if (id === "default" || id === "open")
                continue;
            if (!String(a?.text ?? "").trim())
                continue;
            out.push(a);
        }
        return out;
    }

    function canOpen(entry: var): bool {
        if (!entry)
            return false;
        if (root.defaultAction(entry))
            return true;
        const id = root.appIdOf(entry);
        if (!id)
            return false;
        if (Apps.entry(id))
            return true;
        return root.isChat(entry);
    }

    function activate(entry: var): void {
        if (!entry)
            return;
        const def = root.defaultAction(entry);
        if (def)
            def.invoke();
        root.focusApp(entry);
        root.dismissPopup(entry.key);
    }

    function invokeAction(entry: var, action: var): void {
        action?.invoke();
        root.dismissPopup(entry?.key);
    }

    function focusApp(entry: var): void {
        const id = root.appIdOf(entry);
        if (!id)
            return;
        const cls = Apps.classFor(id);
        const aliases = [cls, id.toLowerCase()];
        if (root.isChat(entry)) {
            aliases.push("vesktop", "discord", "vesktop.exe", "discord.exe");
        }
        const tops = Hyprland.toplevels?.values ?? [];
        let matched = "";
        for (let i = 0; i < tops.length; i++) {
            const c = String(tops[i]?.lastIpcObject?.class ?? "").toLowerCase();
            if (aliases.indexOf(c) >= 0) {
                matched = c;
                break;
            }
        }
        if (matched)
            Hyprland.dispatch(`hl.dsp.focus({ window = "class:${matched}" })`);
        else
            Apps.launch(id);
    }

    function dismissPopup(key: int): void {
        root.popups = root.popups.filter(x => x.key !== key);
    }

    function forget(key: int): void {
        const entry = root.history.find(x => x.key === key)
                   ?? root.popups.find(x => x.key === key);
        entry?.notif?.dismiss();
        root.popups = root.popups.filter(x => x.key !== key);
        root.history = root.history.filter(x => x.key !== key);
    }

    function clearHistory(): void {
        for (const e of root.history) e.notif?.dismiss();
        root.history = [];
        root.popups = [];
    }

    function markAllSeen(): void {
        // object spread is not supported by QML's JS engine
        root.history = root.history.map(e => Object.assign({}, e, { seen: true }));
    }

    // Group by application for the centre view.
    function grouped(): var {
        const map = {};
        for (const e of root.history) {
            const k = e.appName || "System";
            if (!map[k]) map[k] = [];
            map[k].push(e);
        }
        return Object.keys(map).map(k => ({ app: k, items: map[k] }));
    }

    function relative(d: date): string {
        const s = Math.floor((Date.now() - d.getTime()) / 1000);
        if (s < 60) return "just now";
        if (s < 3600) return `${Math.floor(s / 60)} min ago`;
        if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
        return `${Math.floor(s / 86400)} d ago`;
    }
}
