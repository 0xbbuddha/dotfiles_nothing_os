// Expression engine for Essential Apps.
//
// App specs carry expressions, never code. They are parsed here and walked
// by a small interpreter: names resolve only to the context, members only
// to own data, and calls only to the tables below. Nothing is ever compiled,
// so no spec can reach Function, Qt or a QML singleton.

.pragma library

var hasOwn = Object.prototype.hasOwnProperty;
var MAX_SOURCE = 1000;
var MAX_DEPTH = 48;
var MAX_STEPS = 50000;
var MAX_CACHE = 2000;
var MAX_PAD = 64;

var cache = Object.create(null);
var cached = 0;
var steps = 0;

function table(names) {
    var out = Object.create(null);
    for (var n = 0; n < names.length; n++)
        out[names[n]] = true;
    return out;
}

var BLOCKED = table(["constructor", "__proto__", "prototype", "__defineGetter__",
                     "__defineSetter__", "__lookupGetter__", "__lookupSetter__"]);
var RESERVED = table(["new", "function", "this", "class", "delete", "void", "in",
                      "instanceof", "while", "for", "do", "var", "let", "const",
                      "if", "else", "return", "throw", "try", "catch", "yield",
                      "await", "async", "import", "export", "super", "with",
                      "switch", "case", "default", "break", "continue"]);
var ARGS = ["state", "data", "time", "weather", "sys", "media", "net", "vault",
            "audio", "battery", "updates", "notifs", "desktop", "it", "i"];

var OPS = ["===", "!==", "=>", "==", "!=", "<=", ">=", "&&", "||", "??", "?.",
           "**", "+", "-", "*", "/", "%", "!", "<", ">", "?", ":", ".", ",",
           "(", ")", "[", "]", "{", "}"];
var ESCAPES = { n: "\n", t: "\t", r: "\r", b: "\b", f: "\f", v: "\v", "0": "\0" };

function isDigit(c) { return c >= "0" && c <= "9"; }
function isIdStart(c) {
    return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c === "_";
}

function tokenize(src) {
    var out = [];
    var at = 0;
    while (at < src.length) {
        var c = src.charAt(at);
        if (c === " " || c === "\t" || c === "\n" || c === "\r") {
            at++;
        } else if (isDigit(c) || (c === "." && isDigit(src.charAt(at + 1)))) {
            var m = /^(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)/.exec(src.slice(at));
            out.push({ t: "num", v: Number(m[0]) });
            at += m[0].length;
        } else if (isIdStart(c)) {
            var end = at + 1;
            while (end < src.length
                   && (isIdStart(src.charAt(end)) || isDigit(src.charAt(end))))
                end++;
            out.push({ t: "id", v: src.slice(at, end) });
            at = end;
        } else if (c === "'" || c === "\"") {
            var text = "";
            at++;
            while (src.charAt(at) !== c) {
                if (at >= src.length)
                    throw new Error("open string");
                var d = src.charAt(at);
                if (d === "\\") {
                    var e = src.charAt(at + 1);
                    if (e === "u") {
                        var hex = src.slice(at + 2, at + 6);
                        if (!/^[0-9a-fA-F]{4}$/.test(hex))
                            throw new Error("bad escape");
                        text += String.fromCharCode(parseInt(hex, 16));
                        at += 6;
                    } else {
                        text += ESCAPES[e] !== undefined ? ESCAPES[e] : e;
                        at += 2;
                    }
                } else {
                    text += d;
                    at++;
                }
            }
            at++;
            out.push({ t: "str", v: text });
        } else {
            var op = "";
            for (var n = 0; n < OPS.length && op === ""; n++) {
                if (src.substr(at, OPS[n].length) === OPS[n])
                    op = OPS[n];
            }
            if (op === "")
                throw new Error("bad character");
            if (op === "?." && isDigit(src.charAt(at + 2)))
                op = "?";
            out.push({ t: "op", v: op });
            at += op.length;
        }
    }
    out.push({ t: "end", v: "" });
    return out;
}

function parseExpression(src) {
    var toks = tokenize(src);
    var at = 0;
    var depth = 0;

    function isOp(v) { return toks[at].t === "op" && toks[at].v === v; }
    function eat(v) {
        if (!isOp(v))
            return false;
        at++;
        return true;
    }
    function need(v) {
        if (!eat(v))
            throw new Error("expected " + v);
    }
    function name() {
        var tok = toks[at];
        if (tok.t !== "id" || BLOCKED[tok.v])
            throw new Error("expected a name");
        at++;
        return tok.v;
    }

    function chain(next, ops) {
        var left = next();
        while (toks[at].t === "op" && ops.indexOf(toks[at].v) >= 0) {
            var op = toks[at++].v;
            left = { k: "bin", op: op, l: left, r: next() };
        }
        return left;
    }

    function expression() {
        if (++depth > MAX_DEPTH)
            throw new Error("too deep");
        var cond = logicOr();
        var out = cond;
        if (eat("?")) {
            var yes = expression();
            need(":");
            out = { k: "cond", c: cond, a: yes, b: expression() };
        }
        depth--;
        return out;
    }
    function logicOr() { return chain(logicAnd, ["||", "??"]); }
    function logicAnd() { return chain(equality, ["&&"]); }
    function equality() { return chain(relation, ["===", "!==", "==", "!="]); }
    function relation() { return chain(additive, ["<", ">", "<=", ">="]); }
    function additive() { return chain(product, ["+", "-"]); }
    function product() { return chain(power, ["*", "/", "%"]); }
    function power() {
        var base = unary();
        return eat("**") ? { k: "bin", op: "**", l: base, r: power() } : base;
    }
    function unary() {
        if (toks[at].t === "id" && toks[at].v === "typeof") {
            at++;
            return { k: "un", op: "typeof", x: unary() };
        }
        if (isOp("!") || isOp("-") || isOp("+")) {
            var op = toks[at++].v;
            return { k: "un", op: op, x: unary() };
        }
        return postfix();
    }
    function postfix() {
        var left = primary();
        for (;;) {
            if (eat(".")) {
                left = { k: "mem", o: left, p: { k: "lit", v: name() }, opt: false };
            } else if (eat("?.")) {
                if (eat("[")) {
                    left = { k: "mem", o: left, p: expression(), opt: true };
                    need("]");
                } else if (isOp("(")) {
                    throw new Error("no optional calls");
                } else {
                    left = { k: "mem", o: left, p: { k: "lit", v: name() }, opt: true };
                }
            } else if (eat("[")) {
                left = { k: "mem", o: left, p: expression(), opt: false };
                need("]");
            } else if (eat("(")) {
                left = { k: "call", f: left, a: argumentList() };
            } else {
                return left;
            }
        }
    }
    function argumentList() {
        var out = [];
        if (eat(")"))
            return out;
        do {
            out.push(argument());
        } while (eat(","));
        need(")");
        return out;
    }
    function argument() {
        var tok = toks[at];
        if (tok.t === "id" && toks[at + 1].t === "op" && toks[at + 1].v === "=>") {
            var one = name();
            at++;
            return { k: "arrow", ps: [one], b: expression() };
        }
        if (isOp("(")) {
            var look = at + 1;
            while (toks[look].t === "id" && toks[look + 1].t === "op"
                   && toks[look + 1].v === ",")
                look += 2;
            if (toks[look].t === "id")
                look++;
            if (toks[look].t === "op" && toks[look].v === ")"
                    && toks[look + 1].t === "op" && toks[look + 1].v === "=>") {
                need("(");
                var ps = [];
                while (!eat(")")) {
                    ps.push(name());
                    eat(",");
                }
                need("=>");
                return { k: "arrow", ps: ps, b: expression() };
            }
        }
        return expression();
    }
    function primary() {
        var tok = toks[at];
        if (tok.t === "num" || tok.t === "str") {
            at++;
            return { k: "lit", v: tok.v };
        }
        if (tok.t === "id") {
            at++;
            switch (tok.v) {
            case "true": return { k: "lit", v: true };
            case "false": return { k: "lit", v: false };
            case "null": return { k: "lit", v: null };
            case "undefined": return { k: "lit", v: undefined };
            case "NaN": return { k: "lit", v: NaN };
            case "Infinity": return { k: "lit", v: Infinity };
            }
            if (RESERVED[tok.v] || BLOCKED[tok.v])
                throw new Error("forbidden name");
            return { k: "id", n: tok.v };
        }
        if (eat("(")) {
            var inner = expression();
            need(")");
            return inner;
        }
        if (eat("[")) {
            var items = [];
            while (!eat("]")) {
                items.push(expression());
                if (!isOp("]"))
                    need(",");
            }
            return { k: "arr", e: items };
        }
        if (eat("{")) {
            var props = [];
            while (!eat("}")) {
                var key = toks[at];
                if ((key.t !== "id" && key.t !== "str") || BLOCKED[key.v])
                    throw new Error("bad key");
                at++;
                need(":");
                props.push({ key: key.v, value: expression() });
                if (!isOp("}"))
                    need(",");
            }
            return { k: "obj", p: props };
        }
        throw new Error("unexpected token");
    }

    var tree = expression();
    if (toks[at].t !== "end")
        throw new Error("trailing input");
    return tree;
}

function compile(src) {
    if (src in cache)
        return cache[src];
    if (cached >= MAX_CACHE) {
        cache = Object.create(null);
        cached = 0;
    }
    var tree = null;
    try {
        if (src.length <= MAX_SOURCE)
            tree = parseExpression(src);
    } catch (e) {
        tree = null;
    }
    cache[src] = tree;
    cached++;
    return tree;
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

function padWidth(width) {
    return Math.max(0, Math.min(MAX_PAD, Number(width) || 0));
}

var GLOBALS = Object.create(null);
GLOBALS.String = function (v) { return String(v); };
GLOBALS.Number = function (v) { return Number(v); };
GLOBALS.Boolean = function (v) { return !!v; };
GLOBALS.parseInt = function (v, radix) { return parseInt(v, radix); };
GLOBALS.parseFloat = function (v) { return parseFloat(v); };
GLOBALS.isNaN = function (v) { return isNaN(v); };
GLOBALS.isFinite = function (v) { return isFinite(v); };

function pickNative(host, names) {
    var out = Object.create(null);
    names.forEach(function (n) {
        out[n] = function () { return host[n].apply(host, arguments); };
    });
    return out;
}

var SPACES = Object.create(null);
SPACES.Math = pickNative(Math, ["abs", "acos", "asin", "atan", "atan2", "ceil", "cos",
    "exp", "floor", "log", "log10", "log2", "max", "min", "pow", "random", "round",
    "sign", "sin", "sqrt", "tan", "trunc"]);
SPACES.Date = pickNative(Date, ["now", "parse"]);
SPACES.JSON = pickNative(JSON, ["parse", "stringify"]);
SPACES.Object = pickNative(Object, ["keys", "values", "entries"]);
SPACES.Array = pickNative(Array, ["isArray"]);
SPACES.fmt = fmt;

var CONSTANTS = Object.create(null);
CONSTANTS.Math = { PI: Math.PI, E: Math.E, SQRT2: Math.SQRT2, LN2: Math.LN2, LN10: Math.LN10 };

var STRING_CALLS = table(["charAt", "charCodeAt", "concat", "endsWith", "includes",
    "indexOf", "lastIndexOf", "localeCompare", "replace", "slice", "split",
    "startsWith", "substring", "toLowerCase", "toUpperCase", "trim"]);
var NUMBER_CALLS = table(["toFixed", "toPrecision", "toString"]);
var ARRAY_CALLS = table(["concat", "every", "filter", "find", "findIndex", "includes",
    "indexOf", "join", "lastIndexOf", "map", "reduce", "slice", "some"]);

function textArgs(args) {
    args.forEach(function (a) {
        if (typeof a === "function" || (a !== null && typeof a === "object"))
            throw new Error("text method takes plain values");
    });
    return args;
}

function callMethod(self, name, args) {
    if (typeof self === "string") {
        if (name === "padStart" || name === "padEnd") {
            var text = String(args[1] === undefined ? " " : args[1]);
            var fill = "";
            var want = padWidth(args[0]) - self.length;
            while (fill.length < want)
                fill += text;
            fill = fill.slice(0, Math.max(0, want));
            return name === "padStart" ? fill + self : self + fill;
        }
        if (STRING_CALLS[name])
            return String.prototype[name].apply(self, textArgs(args));
    } else if (typeof self === "number") {
        if (NUMBER_CALLS[name])
            return Number.prototype[name].apply(self, textArgs(args));
    } else if (Array.isArray(self)) {
        if (name === "sort" || name === "reverse")
            return Array.prototype[name].apply(self.slice(), args);
        if (ARRAY_CALLS[name])
            return Array.prototype[name].apply(self, args);
    }
    throw new Error("not callable");
}

function member(self, key) {
    if (typeof key !== "string" && typeof key !== "number")
        return undefined;
    var prop = String(key);
    if (BLOCKED[prop])
        return undefined;
    if (typeof self === "string") {
        if (prop === "length")
            return self.length;
        return /^\d+$/.test(prop) ? self.charAt(Number(prop)) || undefined : undefined;
    }
    if (self === null || typeof self !== "object" || !hasOwn.call(self, prop))
        return undefined;
    var value = self[prop];
    return typeof value === "function" ? undefined : value;
}

// ── Evaluation ───────────────────────────────────────────────────────
// A failed expression yields undefined rather than throwing: one bad
// field must not take the whole app down.

function walk(node, scope) {
    if (--steps < 0)
        throw new Error("too long");
    switch (node.k) {
    case "lit":
        return node.v;
    case "id":
        if (node.n in scope)
            return scope[node.n];
        throw new Error("unknown name");
    case "mem": {
        if (node.o.k === "id" && !(node.o.n in scope) && SPACES[node.o.n]) {
            var space = CONSTANTS[node.o.n];
            var konst = walk(node.p, scope);
            return space && hasOwn.call(space, String(konst)) ? space[konst] : undefined;
        }
        var self = walk(node.o, scope);
        if (node.opt && (self === null || self === undefined))
            return undefined;
        if (self === null || self === undefined)
            throw new Error("no such member");
        return member(self, walk(node.p, scope));
    }
    case "call":
        return call(node, scope);
    case "un": {
        if (node.op === "typeof") {
            if (node.x.k === "id" && !(node.x.n in scope))
                return "undefined";
            return typeof walk(node.x, scope);
        }
        var x = walk(node.x, scope);
        return node.op === "!" ? !x : node.op === "-" ? -x : +x;
    }
    case "bin":
        return binary(node, scope);
    case "cond":
        return walk(node.c, scope) ? walk(node.a, scope) : walk(node.b, scope);
    case "arr":
        return node.e.map(function (e) { return walk(e, scope); });
    case "obj": {
        var out = {};
        node.p.forEach(function (p) { out[p.key] = walk(p.value, scope); });
        return out;
    }
    }
    throw new Error("cannot evaluate");
}

function binary(node, scope) {
    var l = walk(node.l, scope);
    switch (node.op) {
    case "&&": return l ? walk(node.r, scope) : l;
    case "||": return l ? l : walk(node.r, scope);
    case "??": return (l === null || l === undefined) ? walk(node.r, scope) : l;
    }
    var r = walk(node.r, scope);
    switch (node.op) {
    case "+": return l + r;
    case "-": return l - r;
    case "*": return l * r;
    case "/": return l / r;
    case "%": return l % r;
    case "**": return Math.pow(l, r);
    case "===": return l === r;
    case "!==": return l !== r;
    case "==": return l == r;
    case "!=": return l != r;
    case "<": return l < r;
    case ">": return l > r;
    case "<=": return l <= r;
    case ">=": return l >= r;
    }
    throw new Error("bad operator");
}

function callback(node, scope) {
    if (node.k === "arrow") {
        return function () {
            var inner = Object.create(scope);
            for (var n = 0; n < node.ps.length; n++)
                inner[node.ps[n]] = arguments[n];
            return walk(node.b, inner);
        };
    }
    if (node.k === "id" && !(node.n in scope) && GLOBALS[node.n])
        return GLOBALS[node.n];
    return walk(node, scope);
}

function plainArg(node, scope) {
    if (node.k === "arrow")
        throw new Error("no callback here");
    return walk(node, scope);
}

function call(node, scope) {
    var f = node.f;
    if (f.k === "id") {
        if (f.n in scope || !GLOBALS[f.n])
            throw new Error("not callable");
        return GLOBALS[f.n].apply(null, node.a.map(function (a) { return plainArg(a, scope); }));
    }
    if (f.k !== "mem")
        throw new Error("not callable");
    var key = walk(f.p, scope);
    if (typeof key !== "string" || BLOCKED[key])
        throw new Error("not callable");
    if (f.o.k === "id" && !(f.o.n in scope) && SPACES[f.o.n]) {
        var space = SPACES[f.o.n];
        if (!hasOwn.call(space, key))
            throw new Error("not callable");
        return space[key].apply(space, node.a.map(function (a) { return plainArg(a, scope); }));
    }
    var self = walk(f.o, scope);
    if (f.opt && (self === null || self === undefined))
        return undefined;
    var wantsCallback = Array.isArray(self);
    return callMethod(self, key, node.a.map(function (a) {
        return wantsCallback ? callback(a, scope) : plainArg(a, scope);
    }));
}

function evaluate(src, ctx, item, index) {
    if (!src || !ctx)
        return undefined;
    var tree = compile(String(src));
    if (!tree)
        return undefined;
    var scope = Object.create(null);
    for (var n = 0; n < ARGS.length; n++)
        scope[ARGS[n]] = ctx[ARGS[n]];
    scope.it = item;
    scope.i = index;
    steps = MAX_STEPS;
    try {
        return walk(tree, scope);
    } catch (e) {
        return undefined;
    }
}

function isLiteral(src) {
    var tree = compile(String(src));
    return !!tree && tree.k === "lit" && typeof tree.v === "string";
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
        cur = member(cur, parts[n]);
    }
    return cur === undefined ? null : cur;
}
