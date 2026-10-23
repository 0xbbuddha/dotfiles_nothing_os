// Drives services/Ddc.qml's JS against a fake ddcutil to check the queue,
// latest-wins writes, read-back verification and blocking.
const fs = require("fs");
const assert = require("assert");
const src = fs.readFileSync(process.argv[2], "utf8");

// Pull every 4-space-indent function out of the singleton.
const fns = {};
const re = /^    function (\w+)\(([^)]*)\)(?::\s*\w+)?\s*\{\n([\s\S]*?)\n    \}$/gm;
let m;
while ((m = re.exec(src))) {
  const params = m[2].split(",").map(p => p.split(":")[0].trim()).filter(Boolean);
  fns[m[1]] = { params, body: m[3] };
}

function make() {
  const cmds = [];
  let later = [];
  const env = {
    Qt: { callLater: f => { if (!later.includes(f)) later.push(f); } },
    console: { warn: (...a) => env.warns.push(a.join(" ")) },
    warns: [],
    wait: { running: false, interval: 0, restart() { this.running = true; } },
    debounce: { restart() { this.pending = true; }, pending: false },
    timeout: { restart() {}, stop() {} },
    probe: { running: false },
    out: { text: "" }, err: { text: "" },
    worker: { command: [], set running(v) { if (v) cmds.push(this.command.slice()); this._r = v; }, get running() { return this._r; } },
  };
  const root = {
    available: true, probed: true, detecting: false, detected: false, fault: "",
    monitors: [], state: {}, settleFirst: 400, settleSecond: 1200, maxWrites: 2,
    timeoutMs: 12000, wantDetect: false, queue: [], job: null, seq: 0, extras: {}, pendingLevel: -1, evening: false,
    extraCodes: { "12": "contrast", "14": "preset", "DC": "mode" },
    outDone: false, errDone: false, exitCode: -999,
  };
  env.root = root;
  root.standardNames = eval("(" + src.match(/standardNames: \(([\s\S]*?)\)\n/)[1] + ")");
  for (const [name, f] of Object.entries(fns)) {
    const names = Object.keys(env);
    root[name] = new Function(...names, `return function(${f.params.join(",")}) {\n${f.body}\n}`)(...names.map(n => env[n]));
  }
  const flush = () => { while (later.length) { const l = later; later = []; l.forEach(f => f()); } };
  const respond = (code, out, err = "") => {
    env.out.text = out; env.err.text = err;
    root.outDone = true; root.finish(); root.errDone = true; root.finish();
    root.exitCode = code; root.finish(); flush();
  };
  const fireWait = () => { env.wait.running = false; root.pump(); flush(); };
  const fireDebounce = () => { env.debounce.pending = false; root.kick(); flush(); };
  return { root, env, cmds, flush, respond, fireWait, fireDebounce };
}

const DETECT = `Display 1
   I2C bus:  /dev/i2c-4
   DRM_connector:           card1-DP-1
   EDID synopsis:
      Mfg id:               IVM - Iiyama North America
      Model:                PL3467WQ
      Product code:         26213  (0x6665)
      Serial number:
   VCP version:         2.2

Display 2
   I2C bus:  /dev/i2c-5
   DRM_connector:           card1-DP-2
   EDID synopsis:
      Mfg id:               IVM - Iiyama North America
      Model:                PL2745H
   VCP version:         2.2

Invalid display
   I2C bus:  /dev/i2c-7
   DRM_connector:           card1-HDMI-A-1
   EDID synopsis:
      Mfg id:               SAM - Samsung
      Model:                TV
   DDC communication failed
`;
const last = c => c.cmds[c.cmds.length - 1].join(" ");
let n = 0; const t = (name, f) => { f(); n++; console.log("ok -", name); };

t("parseDetect maps bus to connector and skips nothing real", () => {
  const c = make();
  const d = c.root.parseDetect(DETECT);
  assert.deepStrictEqual(d.map(x => [x.bus, x.connector, x.ok, x.model]),
    [[4, "DP-1", true, "PL3467WQ"], [5, "DP-2", true, "PL2745H"], [7, "HDMI-A-1", false, "TV"]]);
  assert.match(d[2].reason, /DDC communication failed/);
  // ddcutil 2.0's spelling
  assert.strictEqual(c.root.parseDetect("Display 1\n   I2C bus:  /dev/i2c-3\n   DRM connector:  card0-DP-3\n")[0].connector, "DP-3");
});

t("parseBrief", () => {
  const c = make();
  assert.deepStrictEqual(c.root.parseBrief("VCP 10 C 40 100\n"), { cur: 40, max: 100 });
  assert.strictEqual(c.root.parseBrief("garbage"), null);
});

function detected() {
  const c = make();
  c.root.detect(); c.flush();
  assert.strictEqual(last(c), "ddcutil detect");
  c.respond(0, DETECT);
  // reads queued for both DDC screens, serially; invalid one blocked at once
  assert.strictEqual(last(c), "ddcutil --bus 4 getvcp 10 --brief");
  assert.strictEqual(c.root.state[7].blocked, true);
  c.respond(0, "VCP 10 C 100 100");
  assert.strictEqual(last(c), "ddcutil --bus 5 getvcp 10 --brief");
  c.respond(0, "VCP 10 C 40 100");
  assert.strictEqual(c.root.state[4].cur, 100);
  assert.strictEqual(c.root.state[5].cur, 40);
  return c;
}
t("detect then serial initial reads", detected);

t("drag coalesces to the last value; write then read-back verifies", () => {
  const c = detected();
  const before = c.cmds.length;
  for (const v of [0.9, 0.8, 0.7, 0.65]) c.root.set(4, v);
  assert.strictEqual(c.cmds.length, before, "nothing written mid-debounce");
  assert.strictEqual(Math.round(c.root.shown(4) * 100), 65);
  c.fireDebounce();
  assert.strictEqual(last(c), "ddcutil --bus 4 --noverify setvcp 10 65");
  assert.strictEqual(c.cmds.length, before + 1);
  c.respond(0, "");
  assert.ok(c.env.wait.running, "settles before reading back");
  c.fireWait();
  assert.strictEqual(last(c), "ddcutil --bus 4 getvcp 10 --brief");
  c.respond(0, "VCP 10 C 65 100");
  assert.strictEqual(c.root.state[4].status, "ok");
  assert.strictEqual(c.root.state[4].cur, 65);
});

t("value moved during a write is the one written next (no stale final value)", () => {
  const c = detected();
  c.root.set(4, 0.5); c.fireDebounce();
  assert.strictEqual(last(c), "ddcutil --bus 4 --noverify setvcp 10 50");
  c.root.set(4, 0.3);               // while the write is in flight
  c.respond(0, ""); c.fireWait();   // verify read of 50
  c.respond(0, "VCP 10 C 50 100");  // read sees newer want, abandons verify
  assert.strictEqual(last(c), "ddcutil --bus 4 --noverify setvcp 10 30");
  c.respond(0, ""); c.fireWait(); c.respond(0, "VCP 10 C 30 100");
  assert.strictEqual(c.root.state[4].status, "ok");
  assert.strictEqual(c.root.state[4].cur, 30);
});

t("slow monitor: first read-back stale, second matches -> ok, one write", () => {
  const c = detected();
  c.root.set(5, 0.6); c.fireDebounce();
  const writes = () => c.cmds.filter(x => x.includes("setvcp")).length;
  c.respond(0, ""); c.fireWait(); c.respond(0, "VCP 10 C 40 100");
  assert.ok(c.env.wait.running);
  c.fireWait(); c.respond(0, "VCP 10 C 60 100");
  assert.strictEqual(c.root.state[5].status, "ok");
  assert.strictEqual(writes(), 1);
});

t("refusing monitor: bounded retries, then blocked, no further writes", () => {
  const c = detected();
  c.root.set(5, 0.6); c.fireDebounce();
  for (let i = 0; i < 2; i++) {
    c.respond(0, ""); c.fireWait(); c.respond(0, "VCP 10 C 40 100");
    c.fireWait(); c.respond(0, "VCP 10 C 40 100");
    if (i === 0) { c.fireWait(); assert.strictEqual(last(c), "ddcutil --bus 5 --noverify setvcp 10 60"); }
  }
  const st = c.root.state[5];
  assert.strictEqual(st.status, "error"); assert.strictEqual(st.blocked, true);
  assert.match(st.error, /kept 40 .* set to 60/);
  const before = c.cmds.length;
  c.root.set(5, 0.9); c.fireDebounce();
  assert.strictEqual(c.cmds.length, before, "blocked screen gets no writes");
  assert.strictEqual(Math.round(c.root.shown(5) * 100), 40, "slider shows the real value");
  assert.strictEqual(c.env.warns.length, 1, "logged once");
  // other screen unaffected
  c.root.set(4, 0.2); c.fireDebounce();
  assert.strictEqual(last(c), "ddcutil --bus 4 --noverify setvcp 10 20");
});

t("DDCRC_VERIFY / failing write: one retry, then blocked with the reason, real value re-read", () => {
  const c = detected();
  c.root.set(5, 0.7); c.fireDebounce();
  c.respond(1, "", "Error setting value: DDCRC_VERIFY(-3022)");
  c.fireWait(); assert.strictEqual(last(c), "ddcutil --bus 5 --noverify setvcp 10 70");
  c.respond(1, "", "Error setting value: DDCRC_VERIFY(-3022)");
  assert.strictEqual(last(c), "ddcutil --bus 5 getvcp 10 --brief");
  c.respond(0, "VCP 10 C 40 100");
  const st = c.root.state[5];
  assert.strictEqual(st.blocked, true); assert.strictEqual(st.status, "error");
  assert.match(st.error, /DDCRC_VERIFY/);
  assert.strictEqual(st.cur, 40);
  c.root.retry(5); c.flush();
  assert.strictEqual(last(c), "ddcutil --bus 5 getvcp 10 --brief");
  c.respond(0, "VCP 10 C 40 100");
  assert.strictEqual(c.root.state[5].blocked, false);
  assert.strictEqual(c.root.state[5].status, "ok");
});

t("a write that fails while a newer value is already pending is not reported as refused", () => {
  const c = detected();
  c.root.set(5, 0.7); c.fireDebounce();
  assert.strictEqual(last(c), "ddcutil --bus 5 --noverify setvcp 10 70");
  // The user keeps dragging before this write's result comes back - the
  // slider's own value (not j.value, which is now stale) is what must
  // end up written, and this failure must not be reported as a refusal
  // of a target nobody wants anymore.
  c.root.set(5, 0.9);
  c.respond(1, "", "Error setting value: DDCRC_RETRIES(-3023)");
  assert.strictEqual(c.root.state[5].blocked, false);
  assert.notStrictEqual(c.root.state[5].status, "error");
  assert.strictEqual(last(c), "ddcutil --bus 5 --noverify setvcp 10 90");
  c.respond(0, ""); c.fireWait(); c.respond(0, "VCP 10 C 90 100");
  assert.strictEqual(c.root.state[5].status, "ok");
  assert.strictEqual(c.root.state[5].cur, 90);
});

t("linked mode writes every DDC screen, invalid one untouched", () => {
  const c = detected();
  c.root.setAll(0.25); c.fireDebounce();
  assert.strictEqual(last(c), "ddcutil --bus 4 --noverify setvcp 10 25");
  c.respond(0, ""); c.fireWait(); c.respond(0, "VCP 10 C 25 100");
  assert.strictEqual(last(c), "ddcutil --bus 5 --noverify setvcp 10 25");
  assert.ok(!c.cmds.some(x => x.join(" ").includes("--bus 7 --noverify")));
});

t("detect failure is explained, not hidden", () => {
  const c = make(); c.root.detect(); c.flush();
  c.respond(1, "", "No /dev/i2c devices exist.\nddcutil requires module i2c-dev.");
  assert.match(c.root.fault, /i2c-dev/);
  const d = make(); d.root.detect(); d.flush();
  d.respond(1, "", "Open failed for /dev/i2c-4: errno=EACCES(13): Permission denied");
  assert.match(d.root.fault, /udev rule/);
});

t("refresh never writes", () => {
  const c = detected();
  c.root.refresh(); c.flush();
  c.respond(0, DETECT); c.respond(0, "VCP 10 C 100 100"); c.respond(0, "VCP 10 C 40 100");
  assert.ok(!c.cmds.some(x => x.includes("setvcp")));
});
const CAPS = `Model: PL3467WQ
MCCS version: 2.2
VCP Features:
   Feature: 10 (Brightness)
   Feature: 12 (Contrast)
   Feature: 14 (Select color preset)
      Values:
         01: sRGB
         05: 6500 K
         0b: User 1
   Feature: 60 (Input Source)
      Values:
         0f: DisplayPort-1
   Feature: DC (Display Mode)
      Values: 00 03 05 (interpretation unavailable)
`;
t("capabilities parsed: contrast, presets with names, display mode codes", () => {
  const c = make();
  const p = c.root.parseCaps(CAPS);
  assert.deepStrictEqual(p["14"].map(v => v.code + "=" + v.name), ["01=sRGB", "05=6500 K", "0b=User 1"]);
  assert.deepStrictEqual(p["DC"].map(v => v.code), ["00", "03", "05"]);
  assert.ok(p["12"] && !p["16"]);
});

t("extras: load, read, set preset and contrast, read back, refusal reported", () => {
  const c = detected();
  c.root.loadExtras(4); c.flush();
  assert.strictEqual(last(c), "ddcutil --bus 4 capabilities");
  c.respond(0, CAPS);
  assert.strictEqual(last(c), "ddcutil --bus 4 getvcp 12 --brief");
  c.respond(0, "VCP 12 C 50 100");
  c.respond(0, "VCP 14 SNC x05");
  c.respond(0, "VCP DC SNC x00");
  const e = c.root.extras[4];
  assert.strictEqual(e.contrast.cur, 50); assert.strictEqual(e.preset.cur, "05"); assert.strictEqual(e.mode.cur, "00");
  c.root.setExtra(4, "preset", "01"); c.flush();
  assert.strictEqual(last(c), "ddcutil --bus 4 --noverify setvcp 14 x01");
  c.respond(0, ""); c.fireWait(); assert.strictEqual(last(c), "ddcutil --bus 4 getvcp 14 --brief");
  c.respond(0, "VCP 14 SNC x01");
  assert.strictEqual(c.root.extras[4].error, "");
  c.root.setExtra(4, "preset", "99"); c.flush();
  assert.strictEqual(last(c), "ddcutil --bus 4 getvcp 14 --brief", "unlisted preset never written");
  c.root.setExtra(4, "contrast", 0.7); c.flush();
  assert.strictEqual(last(c), "ddcutil --bus 4 --noverify setvcp 12 70");
  c.respond(0, ""); c.fireWait(); c.respond(0, "VCP 12 C 50 100");
  assert.match(c.root.extras[4].error, /kept/);
  assert.strictEqual(c.root.extras[4].contrast.cur, 50, "shows the real value after a refusal");
  assert.strictEqual(c.root.state[4].blocked, false, "brightness unaffected");
});
t("evening level waits for detection and first reads, then writes once to writable screens", () => {
  const c = make();
  c.root.pendingLevel = 0.35;
  c.root.applyPending();
  assert.strictEqual(c.cmds.length, 0, "nothing before detection");
  c.root.detect(); c.flush(); c.respond(0, DETECT);
  c.respond(0, "VCP 10 C 100 100");
  assert.ok(!c.cmds.some(x => x.includes("setvcp")), "not before every screen is read");
  c.respond(0, "VCP 10 C 40 100");
  c.fireDebounce();
  assert.strictEqual(last(c), "ddcutil --bus 4 --noverify setvcp 10 35");
  assert.strictEqual(c.root.pendingLevel, -1, "applied once");
});
console.log(n + " tests passed");
