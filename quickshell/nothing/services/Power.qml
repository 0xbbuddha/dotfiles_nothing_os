pragma Singleton

import Quickshell

// Session actions (lock, suspend, log out, reboot, power off)
// and maintenance (reload the shell, reload Hyprland).
//
// Everything goes through execDetached, not Process: a Process stays a child
// of the shell, and Hyprland kills the shell as soon as it starts quitting.
// The command then has no time to fire, which makes logout unreliable.
//
// The name "Session" is already taken by modules/Session.qml, which shell.qml
// imports alongside this folder: hence "Power".
Singleton {
    id: root

    readonly property string lockConfig:
        Quickshell.shellPath("../../hypr/hyprlock.conf")

    function run(cmd: string): void {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function lock(): void {
        root.run(`pidof hyprlock || hyprlock -c ${root.lockConfig}`);
    }

    function suspend(): void {
        root.run("systemctl suspend || loginctl suspend");
    }

    // The Lua parser evaluates the `dispatch` argument as Lua: the classic
    // `hyprctl dispatch exit` does not parse and fails silently
    // (see README, "Hyprland dispatches"). Call hl.dsp.exit() instead.
    //
    // The fallback covers a client that refuses to close and leaves
    // Hyprland stuck: without it the screen stays frozen on the dead session.
    function logout(): void {
        root.run("hyprctl dispatch 'hl.dsp.exit()'; sleep 3;"
               + " pgrep -x Hyprland >/dev/null && pkill -x Hyprland");
    }

    function reboot(): void {
        root.run("systemctl reboot || loginctl reboot");
    }

    function poweroff(): void {
        root.run("systemctl poweroff || loginctl poweroff");
    }

    // Quickshell reloads itself, without killing itself.
    //
    // Do not "pkill -f 'qs -p <dir>'; qs -p <dir> &": pkill -f matches the
    // pattern against the whole command line, and the sh that carries this
    // command itself contains "qs -p <dir>". The sh would kill itself
    // before the relaunch, and the bar would never come back.
    function restartShell(): void {
        Quickshell.reload(true);
    }

    // hyprctl reload re-reads hyprland.lua: binds are not duplicated
    // and "hyprland.start" programs are not relaunched.
    function reloadAll(): void {
        root.run("hyprctl reload");
        Quickshell.reload(true);
    }
}
