const fs = require("fs");
const assert = require("assert");
const path = require("path");

const dir = process.argv[2];
const read = name => fs.readFileSync(path.join(dir, name), "utf8");
const fnRe = /^    function (\w+)\(([^)]*)\)(?::\s*\w+)?\s*\{\n([\s\S]*?)\n    \}$/gm;

function build(src, env, root) {
  env.root = root;
  let m;
  fnRe.lastIndex = 0;
  while ((m = fnRe.exec(src))) {
    const params = m[2].split(",").map(p => p.split(":")[0].trim()).filter(Boolean);
    const names = Object.keys(env);
    root[m[1]] = new Function(...names, `return function(${params}) {\n${m[3]}\n}`)(...names.map(n => env[n]));
  }
  return root;
}

{
  const idle = { inhibited: true, apply(v) { this.inhibited = v; } };
  const hold = { active: false, before: false };
  const g = build(read("Game.qml"), { Config: { gameInhibitIdle: true }, Idle: idle, idleHold: hold }, {});
  g.holdIdle(true);
  g.holdIdle(true);
  g.holdIdle(false);
  assert.strictEqual(idle.inhibited, true, "caffeine set before game mode survives it");
  idle.inhibited = false;
  g.holdIdle(true);
  assert.strictEqual(idle.inhibited, true);
  g.holdIdle(false);
  assert.strictEqual(idle.inhibited, false);
}

console.log("services: game mode idle hold");
