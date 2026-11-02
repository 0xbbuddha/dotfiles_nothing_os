const fs = require("fs"), assert = require("assert");
const src = fs.readFileSync(process.argv[2], "utf8");
const body = src.match(/^    function hyprColour\(c: var\): string \{\n([\s\S]*?)\n    \}$/m)[1];
const hyprColour = new Function("c", body);

// This is spliced straight into a Lua string literal written to
// accent.lua and run on every Hyprland startup (PR #7 fix) - the
// charset check is the only thing stopping Lua injection here.
assert.strictEqual(hyprColour("ff;os.execute('rm -rf ~')"), "rgba(d71921ff)",
    "non-hex characters must fall back, not reach the Lua string");
assert.strictEqual(hyprColour('"){};os.execute("x")--'), "rgba(d71921ff)",
    "quote/brace injection attempt must fall back");

assert.strictEqual(hyprColour("#00d68f"), "rgba(00d68fff)", "6-digit hex, # stripped");
assert.strictEqual(hyprColour("ff00d68f"), "rgba(00d68fff)", "8-digit aarrggbb reordered to rrggbbaa");
assert.strictEqual(hyprColour(""), "rgba(d71921ff)", "empty input falls back");
assert.strictEqual(hyprColour("12345"), "rgba(d71921ff)", "wrong length falls back");

console.log("accent: 6 checks passed");
