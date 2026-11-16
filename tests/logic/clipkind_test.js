const fs = require("fs"), assert = require("assert");
const src = fs.readFileSync(process.argv[2], "utf8");
const body = src.match(/^    function clipKind\(preview: string, isImage: bool\): var \{\n([\s\S]*?)\n    \}$/m)[1];
const clipKind = new Function("preview", "isImage", body);

assert.deepStrictEqual(clipKind("#1a2b3c", false), { hexColor: "#1a2b3c", isUrl: false },
    "6-digit hex with #");
assert.deepStrictEqual(clipKind("1a2b3c", false), { hexColor: "#1a2b3c", isUrl: false },
    "6-digit hex without #");
assert.deepStrictEqual(clipKind("#abc", false), { hexColor: "#aabbcc", isUrl: false },
    "3-digit hex expands to 6");
assert.deepStrictEqual(clipKind("https://example.com/path?q=1", false),
    { hexColor: "", isUrl: true }, "a plain URL");
assert.deepStrictEqual(clipKind("check https://example.com out", false),
    { hexColor: "", isUrl: false }, "a URL inside other text is not a bare URL");
assert.deepStrictEqual(clipKind("hello world", false), { hexColor: "", isUrl: false },
    "ordinary text matches neither");
assert.deepStrictEqual(clipKind("#1a2b3c", true), { hexColor: "", isUrl: false },
    "an image preview is never read as a color or a link");

console.log("clipkind: 7 checks passed");
