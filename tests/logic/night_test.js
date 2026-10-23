const fs = require("fs"), assert = require("assert");
const src = fs.readFileSync(process.argv[2], "utf8");
const body = src.match(/^    function readStatus\(text: string\): void \{\n([\s\S]*?)\n    \}$/m)[1];
function make(over) {
  const sent = { send: 0, daemon: 0 };
  const root = Object.assign({ checked: false, daemonUp: false, liveKelvin: 0, liveIdentity: true,
    firstStatus: true, commanded: false, resent: 0, active: false, gamma: 100, gammaLowerLimit: 25,
    kelvin: 3500, maxKelvin: 6500, ensureDaemon() { sent.daemon++; } }, over);
  const send = { restart() { sent.send++; } };
  root.readStatus = new Function("root", "send", `return function(text){${body}}`)(root, send);
  return { root, sent };
}
let c = make();
c.root.readStatus("3500\nfalse\n80.000000\n");
assert.ok(c.root.daemonUp && c.root.active && c.root.gamma === 80, "adopts a warm daemon at start");
c = make();
c.root.readStatus("6000\ntrue\n100.000000\n");
assert.ok(c.root.daemonUp && !c.root.active);
c = make({ commanded: true, active: true });
c.root.readStatus("6000\ntrue\n100\n");
assert.strictEqual(c.root.active, true, "restore not undone by the first probe");
assert.strictEqual(c.sent.send, 1, "mismatch resent once");
c.root.readStatus("6000\ntrue\n100\n");
assert.strictEqual(c.sent.send, 1, "only once");
c = make({ firstStatus: false, active: true });
c.root.readStatus("Couldn't connect to /run/user/1000/hypr/x/.hyprsunset.sock. (3)\n");
assert.ok(!c.root.daemonUp && c.sent.send === 1 && c.sent.daemon === 1, "not answering -> restart+resend once");
c = make({ firstStatus: false });
c.root.readStatus("garbage");
assert.strictEqual(c.sent.send, 0, "idle and neutral: no daemon started");
console.log("night: 6 checks passed");
