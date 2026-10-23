import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// Sound: what plays where, what listens, and how loud each app is.
// The control centre's audio panel holds the same things in a hurry;
// this is the page with room for the microphone and every device.
// All of it is Pipewire through Quickshell, live: nothing is written to
// a file, and Pipewire (WirePlumber) remembers the defaults itself.
SettingsPage {
    id: page

    SettingsSection {
        title: "Output"

        SettingRow {
            key: "soundOutput"
            label: "Volume"
            hint: Audio.sink ? Audio.nameOf(Audio.sink) : "No output device"
        }

        LevelRow {
            Layout.fillWidth: true
            visible: Audio.audio !== null
            icon: Audio.muted ? "󰝟" : "󰕾"
            value: Audio.volume
            accent: Audio.muted ? Theme.c.onFaint : Theme.c.on
            onIconClicked: if (Audio.audio) Audio.audio.muted = !Audio.audio.muted
            onMoved: (v) => { if (Audio.audio) Audio.audio.volume = v; }
        }

        SettingRow {
            key: "soundDevice"
            label: "Output device"
            hint: "Click one to make it the default; apps follow"
        }

        SinkList {
            Layout.fillWidth: true
        }

        // Only when there is an actual choice, as in the audio panel.
        SettingRow {
            key: "soundProfile"
            visible: AudioProfiles.profiles.length > 1
            label: "Card profile"
            hint: "Which connector the sound card drives: jack, HDMI…"
        }

        DotPicker {
            visible: AudioProfiles.profiles.length > 1
            options: AudioProfiles.profiles.map(p =>
                ({ label: p.label, value: p.card + "\n" + p.id }))
            current: {
                const a = AudioProfiles.profiles.find(p => p.active);
                return a ? (a.card + "\n" + a.id) : "";
            }
            onPicked: (v) => {
                const parts = v.split("\n");
                AudioProfiles.setProfile(parts[0], parts[1]);
            }
        }
    }

    SettingsSection {
        title: "Microphone"

        SettingRow {
            key: "soundMic"
            label: "Input level"
            hint: Audio.hasMic
                ? Audio.nameOf(Audio.source) + (Audio.micMuted ? " · muted" : "")
                : "No microphone"
        }

        LevelRow {
            Layout.fillWidth: true
            visible: Audio.hasMic
            icon: Audio.micMuted ? "󰍭" : "󰍬"
            value: Audio.mic?.volume ?? 0
            accent: Audio.micMuted ? Theme.c.onFaint : Theme.c.red
            onIconClicked: Audio.toggleMic()
            onMoved: (v) => { if (Audio.mic) Audio.mic.volume = v; }
        }

        SettingRow {
            key: "soundInputDevice"
            label: "Input device"
            visible: Audio.sources.length > 0
            hint: "Mute from anywhere: SUPER+ALT+M"
        }

        SinkList {
            Layout.fillWidth: true
            inputs: true
        }
    }

    SettingsSection {
        title: "Applications"

        SettingRow {
            key: "soundApps"
            label: "Per-app volume"
            hint: Audio.streams.length === 0 ? "Nothing is playing right now"
                : (Audio.sinks.length > 1 ? "Click an app's output to send it elsewhere; it is remembered" : "")
        }

        AppMixer {
            Layout.fillWidth: true
            routes: true
        }
    }
}
