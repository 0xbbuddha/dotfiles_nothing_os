// Expression engine for Essential Apps.
//
// App specs carry JavaScript expressions, never statements. They are
// compiled here into functions whose only arguments are the read-only
// context objects, so a spec cannot reach a QML singleton: those live in
// component scope, and a Function body only sees the global object.
// scripts/essential-app.py rejects Qt, Function, constructor and every
// assignment before a spec ever gets here, so this is the second lock,
// not the first.

.pragma library

var cache = ({});

var ARGS = ["state", "data", "time", "weather", "sys", "media",
            "net", "vault", "audio", "battery", "updates", "notifs",
            "desktop", "fmt", "it", "i"];

function compile(src) {
    if (cache.hasOwnProperty(src))
        return cache[src];
    var fn = null;
    try {
        fn = Function.apply(null, ARGS.concat(
            ['"use strict"; return (' + src + ');']));
    } catch (e) {
        fn = null;
    }
    cache[src] = fn;
    return fn;
}

// ── Formatting helpers exposed to specs as `fmt` ─────────────────────
var fmt = {
    mmss: function (s) {
        var v = Math.max(0, Math.floor(Number(s) || 0));
        return pad(Math.floor(v / 60), 2) + ":" + pad(v % 60, 2);
    },
    hms: function (s) {
        var v = Math.max(0, Math.floor(Number(s) || 0));
        var h = Math.floor(v / 3600);
        return (h > 0 ? h + ":" : "")
            + pad(Math.floor(v / 60) % 60, 2) + ":" + pad(v % 60, 2);
    },
    pct: function (x) {
        return Math.round((Number(x) || 0) * 100) + "%";
    },
    round: function (x, n) {
        var d = Math.pow(10, Math.max(0, Math.min(6, Number(n) || 0)));
        var v = Math.round((Number(x) || 0) * d) / d;
        return String(v);
    },
    pad: function (n, w) { return pad(n, w); },
    num: function (x) {
        var v = Number(x);
        if (!isFinite(v))
            return "-";
        return String(v).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
    },
    date: function (iso) {
        var d = parse(iso);
        if (!d)
            return "-";
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()];
    },
    time: function (iso) {
        var d = parse(iso);
        return d ? pad(d.getHours(), 2) + ":" + pad(d.getMinutes(), 2) : "-";
    },
    until: function (iso) { return span(iso, 1); },
    ago: function (iso) { return span(iso, -1); }
};

function pad(n, w) {
    var s = String(Math.floor(Math.abs(Number(n) || 0)));
    var width = Math.max(1, Math.min(12, Number(w) || 2));
    while (s.length < width)
        s = "0" + s;
    return s;
}

function parse(iso) {
    if (iso instanceof Date)
        return isNaN(iso.getTime()) ? null : iso;
    var text = String(iso || "").trim();
    if (text === "")
        return null;
    var d = new Date(text);
    if (isNaN(d.getTime())) {
        // Bare "YYYY-MM-DD HH:MM" is common in feeds and rejected by
        // some engines: retry as ISO.
        d = new Date(text.replace(" ", "T"));
    }
    return isNaN(d.getTime()) ? null : d;
}

// Coarse duration, largest two units. `dir` is 1 for the future.
function span(iso, dir) {
    var d = parse(iso);
    if (!d)
        return "-";
    var delta = (d.getTime() - Date.now()) / 1000 * dir;
    if (delta <= 0)
        return "NOW";
    var days = Math.floor(delta / 86400);
    var hours = Math.floor(delta / 3600) % 24;
    var mins = Math.floor(delta / 60) % 60;
    var secs = Math.floor(delta) % 60;
    if (days > 0)
        return days + "d " + hours + "h";
    if (hours > 0)
        return hours + "h " + pad(mins, 2) + "m";
    if (mins > 0)
        return mins + "m " + pad(secs, 2) + "s";
    return secs + "s";
}

// ── Evaluation ───────────────────────────────────────────────────────
// A failed expression yields undefined rather than throwing: one bad
// field must not take the whole app down.

function evaluate(src, ctx, item, index) {
    if (!src || !ctx)
        return undefined;
    var fn = compile(src);
    if (!fn)
        return undefined;
    try {
        return fn(ctx.state, ctx.data, ctx.time, ctx.weather, ctx.sys,
                  ctx.media, ctx.net, ctx.vault, ctx.audio, ctx.battery,
                  ctx.updates, ctx.notifs, ctx.desktop, fmt, item, index);
    } catch (e) {
        return undefined;
    }
}

function asText(src, ctx, item, index) {
    var v = evaluate(src, ctx, item, index);
    if (v === undefined || v === null)
        return "";
    if (typeof v === "number")
        return isFinite(v) ? String(v) : "-";
    if (typeof v === "object")
        return "";
    return String(v);
}

function asNumber(src, ctx, item, index, fallback) {
    var v = Number(evaluate(src, ctx, item, index));
    return isFinite(v) ? v : (fallback === undefined ? 0 : fallback);
}

function asBool(src, ctx, item, index) {
    return !!evaluate(src, ctx, item, index);
}

function asArray(src, ctx, item, index) {
    var v = evaluate(src, ctx, item, index);
    if (Array.isArray(v))
        return v;
    // An object is walked as its values: feeds return both shapes.
    if (v && typeof v === "object")
        return Object.keys(v).map(function (k) { return v[k]; });
    return [];
}

// Walks the dotted path a spec declared in `fetch.pick`.
function pick(root, path) {
    if (!path)
        return root;
    var cur = root;
    var parts = String(path).replace(/\[(\d+)\]/g, ".$1").split(".");
    for (var n = 0; n < parts.length; n++) {
        if (parts[n] === "")
            continue;
        if (cur === null || cur === undefined || typeof cur !== "object")
            return null;
        cur = cur[parts[n]];
    }
    return cur === undefined ? null : cur;
}
