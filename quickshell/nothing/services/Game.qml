pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Game mode: toggles Hyprland's expensive options and the FPS limiter.
// Hot changes go through "hyprctl eval", because "hyprctl keyword"
// refuses to work with the Lua parser ("can't work with non-legacy
// parsers. Use eval.").
Singleton {
    id: root

    property bool applying: false
    property bool mangohudAvailable: false

    NProcess {
        // Absent is an answer here, not a fault.
        quiet: true
        running: true
        command: ["sh", "-c", "command -v mangohud >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: root.mangohudAvailable = text.trim() === "yes"
        }
    }

    NProcess { id: runner }

    function hyprEval(lua: string): void {
        runner.command = ["hyprctl", "eval", lua];
        runner.running = true;
    }

    function apply(on: bool): void {
        root.applying = true;

        // A Lua table cannot hold the same key twice: blur and shadow must
        // be grouped under a single "decoration", otherwise the second
        // overwrites the first and blur never toggles.
        const deco = [];
        if (Config.gameNoBlur)
            deco.push(`blur = { enabled = ${on ? "false" : "true"} }`);
        if (Config.gameNoShadow)
            deco.push(`shadow = { enabled = ${on ? "false" : "true"} }`);

        const parts = [];
        if (Config.gameNoAnimations)
            parts.push(`animations = { enabled = ${on ? "false" : "true"} }`);
        if (deco.length > 0)
            parts.push(`decoration = { ${deco.join(", ")} }`);
        if (Config.gameTearing)
            parts.push(`general = { allow_tearing = ${on ? "true" : "false"} }`);
        parts.push(`misc = { render_unfocused_fps = ${on ? Config.gameUnfocusedFps : 0} }`);

        if (parts.length > 0)
            root.hyprEval(`hl.config({ ${parts.join(", ")} })`);

        // hypridle is started directly by the Hyprland config, not by
        // systemd: go through the dedicated service.
        if (Config.gameInhibitIdle) Idle.apply(on);

        applyDone.restart();
    }

    Timer { id: applyDone; interval: 400; onTriggered: root.applying = false }

    function toggle(): void {
        Config.gameMode = !Config.gameMode;
        Config.save();
        root.apply(Config.gameMode);
    }

    // FPS cap via MangoHud: write its config and send SIGUSR2 so it
    // reloads it live.
    NProcess { id: fps }

    function setFpsLimit(value: int): void {
        Config.gameFpsLimit = Math.max(0, value);
        Config.save();
        if (!root.mangohudAvailable) return;
        // The limit arrives as $1 and the path is built inside the script,
        // so both stay quoted. Unquoted, a $HOME with a space split the
        // command into pieces and MangoHud never saw its new config.
        fps.command = ["sh", "-c", `
            conf="$HOME/.config/MangoHud/MangoHud.conf"
            mkdir -p "$(dirname "$conf")" && touch "$conf" || exit 1
            if grep -q '^fps_limit=' "$conf"; then
                sed -i "s/^fps_limit=.*/fps_limit=$1/" "$conf"
            else
                printf 'fps_limit=%s\n' "$1" >> "$conf"
            fi
            pkill -SIGUSR2 mangohud 2>/dev/null || true
        `, "fps-limit", String(Config.gameFpsLimit)];
        fps.running = true;
    }

    // Restore state at shell start, in case it restarted while game mode
    // was on.
    Component.onCompleted: if (Config.gameMode) root.apply(true)
}
