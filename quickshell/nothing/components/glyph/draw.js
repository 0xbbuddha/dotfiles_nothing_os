.pragma library

// Glyph Matrix frame and drawing primitives.
//
// A toy does not display QML items: it writes brightness values into a
// dot frame, which GlyphMatrix lights. That is what the Nothing SDK does,
// and it keeps the render in the matrix vocabulary instead of a round
// card with text inside.
//
// Consequence: no font can be used here, hence the two matrix typefaces
// below.

// ── Frame ────────────────────────────────────────────────────────────
//
// Two parallel channels: brightness (0..1) and hue (0 = white,
// 1 = accent). The second is for states that must alert: low battery
// or a pending notification.

function frame(size) {
    return {
        size: size,
        lum: new Array(size * size).fill(0),
        hue: new Array(size * size).fill(0)
    };
}

function clear(f) {
    f.lum.fill(0);
    f.hue.fill(0);
}

// Light a dot. Brightness takes the max of what is already there: toys
// overlay their elements, and a later stroke must not extinguish what
// was already lit underneath.
function set(f, x, y, v, accent) {
    const px = Math.round(x), py = Math.round(y);
    if (px < 0 || py < 0 || px >= f.size || py >= f.size)
        return;
    const i = py * f.size + px;
    if (v > f.lum[i]) {
        f.lum[i] = v;
        f.hue[i] = accent ? 1 : 0;
    }
}

// ── Typefaces ────────────────────────────────────────────────────────
//
// 5x7 for digits, the only size where an hour stays readable in a
// 25-dot disc. 3x5 for everything else, letters included.

var BIG = {
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"]
};

var SMALL = {
    "0": ["111", "101", "101", "101", "111"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"],
    "3": ["111", "001", "111", "001", "111"],
    "4": ["101", "101", "111", "001", "001"],
    "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"],
    "7": ["111", "001", "001", "001", "001"],
    "8": ["111", "101", "111", "101", "111"],
    "9": ["111", "101", "111", "001", "111"],
    "A": ["010", "101", "111", "101", "101"],
    "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"],
    "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"],
    "F": ["111", "100", "110", "100", "100"],
    "G": ["011", "100", "101", "101", "011"],
    "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"],
    "J": ["001", "001", "001", "101", "010"],
    "K": ["101", "101", "110", "101", "101"],
    "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"],
    "N": ["101", "111", "101", "101", "101"],
    "O": ["010", "101", "101", "101", "010"],
    "P": ["110", "101", "110", "100", "100"],
    "Q": ["010", "101", "101", "110", "011"],
    "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"],
    "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "011"],
    "V": ["101", "101", "101", "101", "010"],
    "W": ["101", "101", "111", "111", "101"],
    "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"],
    "Z": ["111", "001", "010", "100", "111"],
    "%": ["101", "001", "010", "100", "101"],
    "+": ["000", "010", "111", "010", "000"],
    "-": ["000", "000", "111", "000", "000"],
    ".": ["000", "000", "000", "000", "010"],
    "?": ["110", "001", "010", "000", "010"],
    " ": ["000", "000", "000", "000", "000"]
};

// The colon is only one column: putting it in a three-cell slot would
// punch a hole in the middle of the time.
var COLON = ["0", "1", "0", "1", "0"];

function glyph(f, rows, x, y, v, accent) {
    for (var r = 0; r < rows.length; r++) {
        var row = rows[r];
        for (var c = 0; c < row.length; c++) {
            if (row[c] !== "0")
                set(f, x + c, y + r, v, accent);
        }
    }
}

// ── Text ─────────────────────────────────────────────────────────────

function bigWidth(s) { return s.length * 6 - 1; }

// 5x7 digits, one-dot gap between characters.
function big(f, x, y, s, v, accent) {
    var str = String(s);
    for (var i = 0; i < str.length; i++) {
        var rows = BIG[str[i]];
        if (rows)
            glyph(f, rows, x + i * 6, y, v, accent);
    }
}

function bigCentered(f, y, s, v, accent) {
    big(f, Math.round((f.size - bigWidth(String(s))) / 2), y, s, v, accent);
}

function smallWidth(s) {
    var w = 0;
    var str = String(s).toUpperCase();
    for (var i = 0; i < str.length; i++)
        w += (str[i] === ":" ? 1 : 3) + 1;
    return Math.max(0, w - 1);
}

function small(f, x, y, s, v, accent) {
    var str = String(s).toUpperCase();
    var cx = x;
    for (var i = 0; i < str.length; i++) {
        if (str[i] === ":") {
            glyph(f, COLON, cx, y, v, accent);
            cx += 2;
            continue;
        }
        var rows = SMALL[str[i]];
        if (rows)
            glyph(f, rows, cx, y, v, accent);
        cx += 4;
    }
}

function smallCentered(f, y, s, v, accent) {
    small(f, Math.round((f.size - smallWidth(s)) / 2), y, s, v, accent);
}

// ── Shapes ───────────────────────────────────────────────────────────

function center(f) { return (f.size - 1) / 2; }

// Partial ring, start at the top, clockwise. `progress` goes from 0 to 1.
// The head dot is left at full brightness to mark the position even when
// progress is small.
function ring(f, progress, radius, thickness, v, accent) {
    var c = center(f);
    var p = Math.max(0, Math.min(1, progress));
    for (var y = 0; y < f.size; y++) {
        for (var x = 0; x < f.size; x++) {
            var dx = x - c, dy = y - c;
            var d = Math.sqrt(dx * dx + dy * dy);
            if (Math.abs(d - radius) > thickness / 2)
                continue;
            // atan2 is measured from the x-axis; restart from the top.
            var a = Math.atan2(dx, -dy);
            if (a < 0)
                a += Math.PI * 2;
            if (a / (Math.PI * 2) <= p)
                set(f, x, y, v, accent);
        }
    }
}

function circle(f, radius, thickness, v, accent) {
    ring(f, 1, radius, thickness, v, accent);
}

function disc(f, cx, cy, radius, v, accent) {
    for (var y = Math.floor(cy - radius); y <= Math.ceil(cy + radius); y++) {
        for (var x = Math.floor(cx - radius); x <= Math.ceil(cx + radius); x++) {
            var dx = x - cx, dy = y - cy;
            if (Math.sqrt(dx * dx + dy * dy) <= radius)
                set(f, x, y, v, accent);
        }
    }
}

function line(f, x0, y0, x1, y1, v, accent) {
    var steps = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0));
    if (steps === 0) {
        set(f, x0, y0, v, accent);
        return;
    }
    for (var i = 0; i <= steps; i++) {
        var t = i / steps;
        set(f, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, v, accent);
    }
}

// Histogram glued to the bottom of the frame, one column per value (0..1).
function bars(f, values, v, accent) {
    var n = Math.min(values.length, f.size);
    for (var x = 0; x < n; x++) {
        var h = Math.round(Math.max(0, Math.min(1, values[x])) * f.size);
        for (var k = 0; k < h; k++)
            set(f, x, f.size - 1 - k, v, accent);
    }
}

// Horizontal progress bar, useful for gauges that are not round.
function bar(f, y, progress, v, accent) {
    var w = Math.round(Math.max(0, Math.min(1, progress)) * f.size);
    for (var x = 0; x < w; x++)
        set(f, x, y, v, accent);
}

// Plan aliases: digit = a 5x7 glyph, text = the small 3x5 typeface.
function digit(f, x, y, d, v, accent) { big(f, x, y, String(d), v, accent); }
function text(f, x, y, s, v, accent) { small(f, x, y, s, v, accent); }
