pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// MPRIS players. The full list is exposed: YouTube and Spotify must
// be pauseable separately, not only the "current" one.
Singleton {
    id: root

    readonly property var all: Mpris.players.values
    readonly property var players: root.listed(all) || []

    readonly property var current: players.find(p => root.isPlaying(p))
        ?? players.find(p => p.playbackState === MprisPlaybackState.Paused)
        ?? players[0] ?? null

    readonly property bool active: current !== null
    readonly property bool playing: root.isPlaying(current)

    readonly property string title: current?.trackTitle ?? ""
    readonly property string artist: current?.trackArtist ?? ""
    readonly property string album: current?.trackAlbum ?? ""
    readonly property string artUrl: current?.trackArtUrl ?? ""
    readonly property string identity: current?.identity ?? ""
    readonly property string desktopEntry: current?.desktopEntry ?? ""

    readonly property real length: root.lengthOf(current)
    readonly property real position: root.positionOf(current)
    readonly property real progress: root.progressOf(current)
    readonly property bool hasLength: root.length > 0

    readonly property bool canSeek: (current?.canSeek ?? false) && root.hasLength
    readonly property bool canNext: current?.canGoNext ?? false
    readonly property bool canPrev: current?.canGoPrevious ?? false

    readonly property string cleanTitle: root.titleOf(current)
    readonly property string subtitle: root.subtitleOf(current)

    // Browser that re-publishes the same stream as a site (YouTube in Helium).
    readonly property var browserNames: [
        "helium", "chromium", "chrome", "firefox", "zen", "brave",
        "vivaldi", "edge", "msedge", "opera", "librewolf", "floorp",
        "epiphany", "qutebrowser"
    ]
    readonly property var siteNames: [
        "youtube", "soundcloud", "twitch", "netflix", "deezer",
        "tidal", "bandcamp", "crunchyroll"
    ]

    function haystack(p: var): string {
        return `${p?.identity ?? ""} ${p?.desktopEntry ?? ""} ${p?.dbusName ?? ""}`.toLowerCase();
    }

    function isBrowser(p: var): bool {
        const h = root.haystack(p);
        return root.browserNames.some(b => h.indexOf(b) !== -1);
    }

    function isSite(p: var): bool {
        const id = (p?.identity ?? "").toLowerCase();
        return root.siteNames.some(s => id.indexOf(s) !== -1);
    }

    function hasPlasmaIntegration(): bool {
        return all.some(p => (p?.dbusName ?? "").indexOf("plasma-browser-integration") !== -1);
    }

    function isReal(p: var): bool {
        const n = p?.dbusName ?? "";
        if (n === "") return false;
        if (n.indexOf("playerctld") !== -1) return false;
        // Like ii: if plasma-browser-integration is present, the native
        // Chromium/Helium/Firefox bus is only a duplicate.
        if (root.hasPlasmaIntegration()
                && n.indexOf("plasma-browser-integration") === -1
                && root.isBrowser(p))
            return false;
        return true;
    }

    function listed(list: var): var {
        const real = (list ?? []).filter(p => root.isReal(p));
        const hasSite = real.some(p => root.isSite(p));
        // YouTube (site) + Helium (browser) = the same tab.
        const slim = hasSite ? real.filter(p => !root.isBrowser(p) || root.isSite(p)) : real;
        return root.dedupeByTrack(slim);
    }

    function sameTrack(a: var, b: var): bool {
        const t1 = root.titleOf(a).toLowerCase();
        const t2 = root.titleOf(b).toLowerCase();
        if (t1.length >= 3 && t2.length >= 3 && (t1 === t2 || t1.indexOf(t2) !== -1 || t2.indexOf(t1) !== -1))
            return true;
        const l1 = a?.length ?? 0, l2 = b?.length ?? 0;
        const p1 = a?.position ?? 0, p2 = b?.position ?? 0;
        if (l1 > 1 && l2 > 1 && Math.abs(l1 - l2) <= 2 && Math.abs(p1 - p2) <= 2)
            return true;
        return false;
    }

    function score(p: var): int {
        let s = 0;
        if (root.isSite(p)) s += 8;
        if (!root.isBrowser(p)) s += 4;
        if ((p?.trackArtUrl ?? "") !== "") s += 2;
        if (root.isPlaying(p)) s += 1;
        return s;
    }

    function dedupeByTrack(list: var): var {
        const used = [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            if (used[i]) continue;
            let best = i;
            for (let j = i + 1; j < list.length; j++) {
                if (used[j]) continue;
                if (!root.sameTrack(list[i], list[j])) continue;
                used[j] = true;
                if (root.score(list[j]) > root.score(list[best]))
                    best = j;
            }
            used[i] = true;
            out.push(list[best]);
        }
        return out;
    }

    function isPlaying(p: var): bool {
        return p?.playbackState === MprisPlaybackState.Playing;
    }

    function titleOf(p: var): string {
        let t = p?.trackTitle ?? "";
        t = t.replace(/^\(\d+\)\s*/, "");
        t = t.replace(/\s*[--|]\s*YouTube$/i, "");
        t = t.replace(/\s*[--|]\s*(Mozilla Firefox|Google Chrome|Chromium|Zen Browser)$/i, "");
        return t.trim();
    }

    function subtitleOf(p: var): string {
        const a = p?.trackArtist ?? "";
        return a !== "" ? a : (p?.identity ?? "");
    }

    function lengthOf(p: var): real {
        if (!(p?.lengthSupported ?? false)) return 0;
        const l = p?.length ?? 0;
        return Time.isValidLength(l) ? l : 0;
    }

    function positionOf(p: var): real {
        if (!(p?.positionSupported ?? false)) return 0;
        const pos = p?.position ?? 0;
        if (!isFinite(pos) || pos < 0) return 0;
        const len = root.lengthOf(p);
        return len > 0 ? Math.min(pos, len) : pos;
    }

    function progressOf(p: var): real {
        const len = root.lengthOf(p);
        return len > 0 ? root.positionOf(p) / len : 0;
    }

    function playPause(p: var): void {
        const t = p || root.current;
        if (t?.canTogglePlaying) t.togglePlaying();
    }

    function next(p: var): void {
        const t = p || root.current;
        if (t?.canGoNext) t.next();
    }

    function previous(p: var): void {
        const t = p || root.current;
        if (t?.canGoPrevious) t.previous();
    }

    function seek(fraction: real, p: var): void {
        const t = p ?? current;
        const len = root.lengthOf(t);
        if ((t?.canSeek ?? false) && len > 0)
            t.position = Math.max(0, Math.min(1, fraction)) * len;
    }

    Timer {
        running: root.playing
        interval: 1000
        repeat: true
        onTriggered: {
            for (const p of root.players) {
                if (root.isPlaying(p))
                    p.positionChanged();
            }
        }
    }
}
