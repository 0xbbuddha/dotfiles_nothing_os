//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "modules"
import "services"

ShellRoot {
    id: root

    readonly property bool shellHidden: Config.gameMode && Config.gameHideShell

    // ── Per screen ────────────────────────────────────────────────────
    Variants {
        model: Config.drawWallpaper ? Quickshell.screens : []
        Wallpaper {}
    }

    Variants {
        model: root.shellHidden ? [] : Quickshell.screens
        Bar {}
    }

    Variants {
        model: (Config.showDock && !root.shellHidden) ? Quickshell.screens : []
        Dock {}
    }

    Variants {
        model: Config.osdEnabled ? Quickshell.screens : []
        Osd {}
    }

    Variants {
        model: (Config.osdEnabled && Config.glyphEnabled) ? Quickshell.screens : []
        GlyphOsd {}
    }

    // One widget set per screen, like the Glyph Matrix.
    Variants {
        model: Config.showDesktopWidgets ? Quickshell.screens : []
        Desktop {}
    }

    // Essential Apps live in their own column on the right, so the
    // rice's widgets on the left keep a layout nothing generated can
    // reach into.
    Variants {
        model: (Config.showDeskApps && !root.shellHidden) ? Quickshell.screens : []
        AppsColumn {}
    }

    // One Glyph Matrix per screen: otherwise it only appears on screens[0],
    // often the laptop, while we work on the external display.
    // Two models: hot-swapping the layer is unreliable, so the window is
    // recreated when glyphAbove flips.
    Variants {
        model: (Config.glyphEnabled && !Config.glyphAbove && !root.shellHidden)
            ? Quickshell.screens : []
        GlyphWidget { above: false }
    }

    Variants {
        model: (Config.glyphEnabled && Config.glyphAbove && !root.shellHidden)
            ? Quickshell.screens : []
        GlyphWidget { above: true }
    }

    // Panels exist on every screen and only show on the focused one:
    // opening settings from the secondary display shows them there, not
    // on the primary.
    Variants {
        model: Config.notificationsEnabled ? Quickshell.screens : []
        Notifications {}
    }

    Variants { model: Quickshell.screens; Settings {} }
    Variants { model: Quickshell.screens; Launcher {} }
    Variants { model: Quickshell.screens; Session {} }
    Variants { model: Quickshell.screens; Screenshot {} }
    Variants { model: Quickshell.screens; GameBar {} }
    Variants { model: Quickshell.screens; RegionPicker {} }
    Variants { model: Quickshell.screens; Cheatsheet {} }
    Variants { model: Quickshell.screens; Essential {} }
    Variants { model: Quickshell.screens; EssentialApps {} }
    Variants { model: Quickshell.screens; EssentialFly {} }
    Variants { model: Quickshell.screens; NotificationCenter {} }
    Variants { model: Quickshell.screens; PolkitDialog {} }

    // The crosshair lives on every screen, unmasked: never clickable.
    Variants {
        model: Config.crosshair ? Quickshell.screens : []
        Crosshair {}
    }

    // ── Commands ──────────────────────────────────────────────────────
    // Everything is centralised here: modules are instantiated per screen,
    // an IpcHandler declared inside one would be rejected as a duplicate.

    IpcHandler {
        target: "bar"
        function toggle(): void { GlobalState.controlCenterOpen = !GlobalState.controlCenterOpen; }
        function open(): void { GlobalState.controlCenterOpen = true; }
        function hide(): void { GlobalState.controlCenterOpen = false; }
    }

    IpcHandler {
        target: "shell"
        function reload(): void { Power.restartShell(); }
        function reloadAll(): void { Power.reloadAll(); }
    }

    IpcHandler {
        target: "launcher"
        // toggleLauncher clears the query: without that, the launcher
        // would reopen on the last prefix used.
        function toggle(): void { GlobalState.toggleLauncher(); }
        function open(): void { GlobalState.launchWith(""); }
        function hide(): void { GlobalState.launcherOpen = false; }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { GlobalState.settingsOpen = !GlobalState.settingsOpen; }
        function open(): void { GlobalState.settingsOpen = true; }
        function hide(): void { GlobalState.settingsOpen = false; }
    }

    IpcHandler {
        target: "session"
        function toggle(): void { GlobalState.sessionOpen = !GlobalState.sessionOpen; }
        function open(): void { GlobalState.sessionOpen = true; }
        function hide(): void { GlobalState.sessionOpen = false; }
    }

    // Clipboard, emoji and calculator go through the launcher by
    // pre-filling its prefix. No separate panel to maintain.
    IpcHandler {
        target: "clipboard"
        function toggle(): void { GlobalState.launchWith(";"); }
        function open(): void { GlobalState.launchWith(";"); }
        function hide(): void { GlobalState.launcherOpen = false; }
        function update(): void { Clipboard.refresh(); }
    }

    IpcHandler {
        target: "lens"
        function search(): void { Lens.search(); }
    }

    IpcHandler {
        target: "song"
        function toggle(): void { Songrec.toggle(); }
    }

    IpcHandler {
        target: "emoji"
        function toggle(): void { GlobalState.launchWith(":"); }
    }

    IpcHandler {
        target: "calc"
        function toggle(): void { GlobalState.launchWith("="); }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { GlobalState.notifCenterOpen = !GlobalState.notifCenterOpen; }
        function open(): void { GlobalState.notifCenterOpen = true; }
        function hide(): void { GlobalState.notifCenterOpen = false; }
        function clear(): void { Notifs.clearHistory(); }
        function dnd(): void { Notifs.doNotDisturb = !Notifs.doNotDisturb; }
    }

    IpcHandler {
        target: "game"
        function toggle(): void {
            if (Recorder.picking) {
                Recorder.cancelPick();
                GlobalState.gameBarOpen = true;
                return;
            }
            GlobalState.gameBarOpen = !GlobalState.gameBarOpen;
        }
        function open(): void { GlobalState.gameBarOpen = true; }
        function hide(): void { GlobalState.gameBarOpen = false; }
        function mode(): void { Game.toggle(); }
        function crosshair(): void { Config.crosshair = !Config.crosshair; Config.save(); }
    }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { GlobalState.cheatsheetOpen = !GlobalState.cheatsheetOpen; }
        function open(): void { GlobalState.cheatsheetOpen = true; }
        function hide(): void { GlobalState.cheatsheetOpen = false; }
    }

    IpcHandler {
        target: "essential"
        function toggle(): void {
            if (!Config.essentialEnabled)
                return;
            if (GlobalState.essentialOpen) {
                GlobalState.essentialOpen = false;
                return;
            }
            GlobalState.closeAll();
            GlobalState.essentialOpen = true;
        }
        function open(): void {
            if (!Config.essentialEnabled)
                return;
            GlobalState.closeAll();
            GlobalState.essentialOpen = true;
        }
        function hide(): void { GlobalState.essentialOpen = false; }
    }

    IpcHandler {
        target: "apps"
        function toggle(): void {
            if (GlobalState.appsOpen) {
                GlobalState.appsOpen = false;
                return;
            }
            GlobalState.closeAll();
            GlobalState.appsOpen = true;
        }
        function open(): void {
            GlobalState.closeAll();
            GlobalState.appsOpen = true;
        }
        function hide(): void { GlobalState.appsOpen = false; }
        function refresh(): void { MiniApps.refresh(); }
    }

    IpcHandler {
        target: "record"
        function toggle(): void { Recorder.toggle("screen", false); }
        function region(): void { Recorder.toggle("region", false); }
        function sound(): void { Recorder.toggle("screen", true); }
        function stop(): void { Recorder.stop(); }
    }

    IpcHandler {
        target: "screenshot"
        function toggle(): void { GlobalState.screenshotOpen = !GlobalState.screenshotOpen; }
        function region(): void { Shot.capture("region", "copy"); }
        function window(): void { Shot.capture("window", "copy"); }
        function screen(): void { Shot.capture("screen", "copy"); }
        function save(): void { Shot.capture("screen", "save"); }
        function ocr(): void { Shot.capture("region", "ocr"); }
    }

    IpcHandler {
        target: "brightness"
        function up(): void { Brightness.up(); }
        function down(): void { Brightness.down(); }
    }

    // ── Global shortcuts ──────────────────────────────────────────────
    // Declared on the Hyprland side with hl.dsp.global("quickshell:<name>").
    // onReleased opens the launcher on a tap-and-release of SUPER without
    // interfering with SUPER + other key combinations.

    // Tap-and-release of SUPER alone: opens the launcher.
    // Hyprland only emits this bind's release if no other key was pressed
    // in between (checked at evdev injection), so no extra guard is needed.
    GlobalShortcut {
        name: "launcherToggle"
        description: "App launcher (tap and release SUPER)"
        onReleased: GlobalState.toggleLauncher()
    }

    GlobalShortcut {
        name: "clipboardToggle"
        description: "Clipboard history"
        onPressed: GlobalState.launchWith(";")
    }

    GlobalShortcut {
        name: "gameBarToggle"
        description: "Game bar"
        onPressed: {
            if (Recorder.picking) {
                Recorder.cancelPick();
                GlobalState.gameBarOpen = true;
                return;
            }
            GlobalState.gameBarOpen = !GlobalState.gameBarOpen;
        }
    }

    GlobalShortcut {
        name: "sessionToggle"
        description: "Session menu"
        onPressed: GlobalState.sessionOpen = !GlobalState.sessionOpen
    }

    GlobalShortcut {
        name: "brightnessUp"
        description: "Brightness up (gamma then backlight)"
        onPressed: Brightness.up()
    }

    GlobalShortcut {
        name: "brightnessDown"
        description: "Brightness down (backlight then gamma)"
        onPressed: Brightness.down()
    }

    // ── Capture feedback ──────────────────────────────────────────────
    Connections {
        target: Lens
        function onFinished(message: string): void {
            notify.command = ["notify-send", "-a", "Lens", "-i",
                              "image-x-generic", "Google Lens", message];
            notify.running = true;
        }
    }

    Connections {
        target: Recorder
        function onFinished(message: string): void {
            notify.command = ["notify-send", "-a", "Recording", "-i",
                              "media-record", "Screen recording", message];
            notify.running = true;
        }
    }

    Connections {
        target: Shot
        function onFinished(message: string): void {
            notify.command = ["notify-send", "-a", "Capture", "-i",
                              "camera-photo-symbolic", "Screenshot", message];
            notify.running = true;
        }
    }

    Process { id: notify }
}
