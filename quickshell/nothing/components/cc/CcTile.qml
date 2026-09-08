import QtQuick
import "../.."
import ".."
import "../../services"

// One tile of the control centre, chosen by id.
//
// The panel held two hardcoded rows, so an element could only ever be
// where it was written. Everything the grid can hold lives here instead,
// and the grid is a Repeater over Config.ccTiles.
//
// `cc` is passed down rather than reached for: the tiles that open a
// panel in place need the control centre's own expand(), and a component
// that walks back up its parents breaks the moment anything wraps it.
// Named `cc` and not `panel`, so nothing at the call site can shadow it.
Loader {
    id: slot
    required property string itemId
    required property var cc

    // A tile whose service is missing is not drawn at all, and a Flow
    // skips an invisible child, so the grid closes up behind it rather
    // than leaving a hole where WARP would have been.
    //
    // A plain condition, never a reading of `visible`: binding a parent's
    // visibility to a child's and the child's back to the parent settles
    // both on false, which is how the whole centre of the bar once
    // disappeared.
    visible: slot.applies
    readonly property bool applies: {
        switch (slot.itemId) {
        case "warp":    return Warp.available;
        case "light":   return Brightness.available;
        case "mic":     return Audio.hasMic;
        case "night":   return NightLight.available;
        case "songrec": return Songrec.available;
        default:        return true;
        }
    }

    sourceComponent: {
        switch (slot.itemId) {
        case "wifi":      return wifiTile;
        case "bluetooth": return btTile;
        case "warp":      return warpTile;
        case "sound":     return soundTile;
        case "light":     return lightTile;
        case "notify":    return notifyTile;
        case "night":     return nightTile;
        case "theme":     return themeTile;
        case "mic":       return micTile;
        case "game":      return gameTile;
        case "record":    return recordTile;
        case "songrec":   return songrecTile;
        case "voice":     return voiceTile;
        case "dock":      return dockTile;
        default:          return null;
        }
    }

    // ── Connectivity ──────────────────────────────────────────────────
    Component {
        id: wifiTile
        Toggle {
            icon: Net.glyph
            title: Net.kind === "ethernet" ? "Ethernet" : "Wi-Fi"
            subtitle: Net.name
            active: Net.kind !== "none"
            // Ethernet has no radio to turn off, and pretending otherwise
            // would drop the machine off the network with no way back.
            onToggled: if (Net.kind !== "ethernet") Net.toggleWifi()
            onSecondary: slot.cc.expand("wifi")
        }
    }

    Component {
        id: btTile
        Toggle {
            icon: Net.btConnected.length > 0 ? "󰂱" : "󰂯"
            title: "Bluetooth"
            subtitle: Net.btLabel
            active: Net.btPowered
            onToggled: Net.toggleBt()
            onSecondary: slot.cc.expand("bt")
        }
    }

    Component {
        id: warpTile
        Toggle {
            icon: "󰖂"
            title: "WARP"
            subtitle: Warp.busy ? "…" : (Warp.connected ? "on" : "off")
            active: Warp.connected
            onToggled: Warp.toggle()
        }
    }

    // ── Sound and light ───────────────────────────────────────────────
    Component {
        id: soundTile
        Toggle {
            icon: Audio.muted ? "󰝟" : (Audio.volume > 0.5 ? "󰕾" : "󰖀")
            title: "Sound"
            subtitle: Audio.muted ? "muted" : (Math.round(Audio.volume * 100) + "%")
            active: !Audio.muted
            onToggled: if (Audio.audio) Audio.audio.muted = !Audio.audio.muted
            onSecondary: slot.cc.expand("audio")
        }
    }

    Component {
        id: lightTile
        Toggle {
            icon: Brightness.extraDim
                ? "󰖔" : (Brightness.value > 0.5 ? "󰃠" : "󰃞")
            title: "Light"
            subtitle: Math.round(Brightness.combined * 100) + "%"
            // Brightness has no off. The tile stays lit and both buttons
            // open the slider, because that is the only thing to do here.
            active: true
            onToggled: slot.cc.expand("light")
            onSecondary: slot.cc.expand("light")
        }
    }

    Component {
        id: micTile
        Toggle {
            icon: Audio.micMuted ? "󰍭" : "󰍬"
            title: "Microphone"
            subtitle: Audio.micMuted ? "muted" : "live"
            active: !Audio.micMuted
            onToggled: Audio.toggleMic()
        }
    }

    // ── Notifications ─────────────────────────────────────────────────
    Component {
        id: notifyTile
        Toggle {
            readonly property bool off: !Config.notificationsEnabled
            icon: (off || Notifs.doNotDisturb) ? "󰂛" : "󰂚"
            title: "Notify"
            subtitle: off
                ? "off"
                : (Notifs.doNotDisturb
                    ? "silenced"
                    : (Notifs.unread > 0 ? Notifs.unread + " unread" : "on"))
            active: !off && !Notifs.doNotDisturb
            // Do not disturb is what "off" means day to day: the server
            // keeps taking them, the history keeps filling, nothing pops
            // up. Two presses get you back where you started.
            //
            // The exception is the feature switched off in settings
            // entirely. The tile could hide itself, but then there is no
            // way back from here; it says "off" and turns it on instead.
            // Only ever in that direction, so the press still means the
            // thing it looks like it means.
            onToggled: {
                if (off) {
                    Config.notificationsEnabled = true;
                    Config.save();
                    Notifs.doNotDisturb = false;
                    return;
                }
                Notifs.doNotDisturb = !Notifs.doNotDisturb;
            }
            onSecondary: {
                slot.cc.requestClose();
                GlobalState.notifCenterOpen = true;
            }
        }
    }

    // ── Look ──────────────────────────────────────────────────────────
    Component {
        id: nightTile
        Toggle {
            icon: "󰖔"
            title: "Night light"
            subtitle: NightLight.active
                ? Config.nightTemperature + "K"
                : (Config.nightAutomatic
                    ? Config.nightFrom + " to " + Config.nightTo : "off")
            active: NightLight.active
            onToggled: NightLight.toggle()
        }
    }

    Component {
        id: themeTile
        Toggle {
            readonly property bool light: Config.theme === "light"
            icon: "󰔎"
            title: "Theme"
            subtitle: light ? "light" : "dark"
            // Lit on light, which is the one that is doing something to
            // the screen. On dark the tile is dark, which is the point.
            active: light
            onToggled: {
                Config.theme = light ? "dark" : "light";
                Config.save();
            }
        }
    }

    Component {
        id: dockTile
        Toggle {
            icon: "󱂩"
            title: "Dock"
            subtitle: Config.showDock
                ? (Config.dockAutoHide ? "auto hide" : "shown") : "hidden"
            active: Config.showDock
            onToggled: {
                Config.showDock = !Config.showDock;
                Config.save();
            }
        }
    }

    // ── Capture and play ──────────────────────────────────────────────
    Component {
        id: gameTile
        Toggle {
            icon: "󰊗"
            title: "Game mode"
            subtitle: Game.applying ? "…" : (Config.gameMode ? "on" : "off")
            active: Config.gameMode
            onToggled: Game.toggle()
        }
    }

    Component {
        id: recordTile
        Toggle {
            icon: Recorder.recording ? "󰙧" : "󰑊"
            title: "Recording"
            subtitle: Recorder.recording
                ? "stop" : (Recorder.picking ? "pick a region" : "screen")
            active: Recorder.recording
            // The panel gets out of the way first: it sits over the top of
            // the screen, and a recording that opens with the control
            // centre in frame is a recording nobody wanted.
            onToggled: {
                slot.cc.requestClose();
                Recorder.toggle("screen", true);
            }
        }
    }

    Component {
        id: songrecTile
        Toggle {
            icon: "󰎈"
            title: "What is this"
            subtitle: Songrec.listening
                ? (Songrec.duration - Songrec.elapsed) + "s"
                : (Songrec.hasResult ? Songrec.title : "listen")
            active: Songrec.listening
            onToggled: Songrec.toggle()
        }
    }

    Component {
        id: voiceTile
        Toggle {
            icon: "󱑽"
            title: "Voice note"
            subtitle: Voice.recording ? "stop" : "record"
            active: Voice.recording
            onToggled: Voice.toggle()
        }
    }
}
