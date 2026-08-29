import Quickshell.Io

// A Process that speaks up when it fails.
//
// Quickshell's Process throws away the command's stderr and its exit code
// unless you ask for them, and almost nothing here asked: 63 of the 64
// process calls in this shell were silent. That is how a plain
// "cliphist decode: id 370 not found" reached nobody while the clipboard
// quietly emptied itself, and finding it cost an afternoon.
//
// Drop-in. A call site keeps every Process property it already sets, and
// its own onExited still runs: a handler declared in a component file and
// one declared where it is instantiated both fire, they do not replace
// each other.
Process {
    id: root

    // What to call this in the log. Defaults to the binary being run.
    property string label: ""

    // For commands whose failure is an answer rather than a fault: probing
    // for an optional binary, a grep that finds nothing. Silence here keeps
    // the log worth reading.
    property bool quiet: false

    // stderr is read line by line rather than collected: some of these
    // processes run for the whole session, and a collector would hold every
    // byte they ever complain about.
    property int maxLines: 5
    property int seenLines: 0

    readonly property string logName: {
        if (root.label !== "")
            return root.label;
        const c = root.command;
        if (!c || c.length === 0)
            return "process";
        // ["sh", "-c", script, name, ...]: the script is noise. The name
        // after it is what the call site chose to call the thing.
        if (c[0] === "sh" || c[0] === "bash") {
            if (c.length > 3)
                return String(c[3]);
            // No name passed. The first word of the script beats "sh",
            // which tells you nothing about what actually failed.
            const first = String(c[2] ?? "").trim().split(/\s+/)[0] ?? "";
            return first.length > 0 && first.length <= 24
                ? first : String(c[0]);
        }
        return String(c[0]);
    }

    onRunningChanged: if (running) root.seenLines = 0

    stderr: SplitParser {
        onRead: (line) => {
            if (root.quiet)
                return;
            const t = String(line).trim();
            if (t === "")
                return;
            root.seenLines++;
            if (root.seenLines > root.maxLines) {
                if (root.seenLines === root.maxLines + 1)
                    console.warn(root.logName + ": more stderr follows, muted");
                return;
            }
            console.warn(root.logName + ": " + t);
        }
    }

    onExited: (code, status) => {
        if (!root.quiet && code !== 0)
            console.warn(root.logName + ": exited " + code);
    }
}
