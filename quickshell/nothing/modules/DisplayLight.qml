import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// SUPER+P, second page: how bright, and how warm.
//
// Three different things that all look like "brightness", so each one says
// which it is and what it reaches:
//   - Monitor brightness is the monitor's own backlight, per screen, over
//     DDC/CI. It is the only one that saves power and keeps contrast.
//   - Night light is one colour filter for every screen at once
//     (hyprsunset has a single matrix, not one per output).
//   - Software dim scales the picture down, also on every screen. It goes
//     below what a backlight can, and costs contrast to do it.
Item {
    id: page

    property bool shown: false
    onShownChanged: if (page.shown) Ddc.ensure()

    // One card per screen that is on, matched to its DDC bus by connector;
    // then anything ddcutil found that Hyprland did not name.
    readonly property var cards: {
        const out = [];
        const seen = {};
        for (const s of Displays.active) {
            const d = Ddc.byConnector(s.name);
            if (d)
                seen[d.bus] = true;
            out.push({ name: s.name, label: s.label, bus: d ? d.bus : -1,
                       ok: d ? d.ok : false, wide: s.w / Math.max(1, s.h) > 2 });
        }
        for (const d of Ddc.monitors) {
            if (seen[d.bus])
                continue;
            out.push({ name: d.connector !== "" ? d.connector : "bus " + d.bus,
                       label: [d.mfg.split(" - ").pop(), d.model].filter(x => x).join(" "),
                       bus: d.bus, ok: d.ok, wide: false });
        }
        return out;
    }

    readonly property var timeRe: /^([01]?\d|2[0-3]):[0-5]\d$/

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Monitor brightness ────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Theme.pad
            spacing: Theme.px(10)

            RowLayout {
                Layout.fillWidth: true
                NLabel { text: "Monitor brightness" }
                NLabel { text: "· per screen · DDC/CI"; opacity: 0.6 }
                Item { Layout.fillWidth: true }
                NLabel {
                    visible: Ddc.detecting
                    text: "detecting"
                    color: Theme.c.red
                }
                CircleButton {
                    // Reads again; never writes.
                    icon: "󰑐"
                    size: Theme.px(22)
                    enabled: Ddc.available && !Ddc.detecting
                    opacity: enabled ? 1 : 0.35
                    onActivated: Ddc.refresh()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Ddc.available && Ddc.monitors.filter(m => m.ok).length > 0
                spacing: Theme.px(6)

                NText { text: "Link screens"; color: Theme.c.onDim; font.pixelSize: Theme.f.small }
                NSwitch {
                    checked: Config.ddcLinked
                    onToggled: (v) => { Config.ddcLinked = v; Config.save(); }
                }
                Item { Layout.fillWidth: true }
                Repeater {
                    // For every screen that accepts writes.
                    model: [ { label: "20", v: 0.2 }, { label: "50", v: 0.5 },
                             { label: "80", v: 0.8 }, { label: "100", v: 1 } ]
                    NPillButton {
                        required property var modelData
                        text: modelData.label + "%"
                        onActivated: Ddc.setAll(modelData.v)
                    }
                }
            }

            // Day and evening levels, switched at the night-light hours.
            ColumnLayout {
                Layout.fillWidth: true
                visible: Ddc.available
                spacing: Theme.px(4)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(6)
                    NText {
                        Layout.fillWidth: true
                        text: "Dimmer in the evening"
                        color: Theme.c.onDim
                        font.pixelSize: Theme.f.small
                    }
                    NLabel { text: Config.nightFrom + " – " + Config.nightTo }
                    NSwitch {
                        checked: Config.ddcEvening
                        onToggled: (v) => {
                            Config.ddcEvening = v;
                            Config.save();
                            Ddc.followSchedule();
                        }
                    }
                }

                Repeater {
                    model: Config.ddcEvening
                        ? [ { key: "day", label: "Day" }, { key: "evening", label: "Evening" } ] : []
                    RowLayout {
                        id: lvl
                        required property var modelData
                        readonly property int level: lvl.modelData.key === "day"
                            ? Config.ddcDayLevel : Config.ddcEveningLevel
                        Layout.fillWidth: true
                        NLabel { text: lvl.modelData.label; Layout.preferredWidth: Theme.px(60) }
                        NSlider {
                            Layout.fillWidth: true
                            value: lvl.level / 100
                            onMoved: (v) => {
                                const n = Math.round(v * 20) * 5;
                                if (lvl.modelData.key === "day") Config.ddcDayLevel = n;
                                else Config.ddcEveningLevel = n;
                                saveLevels.restart();
                            }
                        }
                        NText {
                            text: lvl.level + "%"
                            font.family: Theme.f.mono
                            font.pixelSize: Theme.f.small
                            Layout.preferredWidth: Theme.px(36)
                        }
                    }
                }

                Timer {
                    id: saveLevels
                    interval: 600
                    // The level for the period you are in applies at once,
                    // so moving it shows what it does.
                    onTriggered: { Config.save(); Ddc.followSchedule(); }
                }
            }

            NText {
                Layout.fillWidth: true
                visible: Ddc.probed && !Ddc.available
                wrapMode: Text.WordWrap
                color: Theme.c.onDim
                font.pixelSize: Theme.f.small
                text: "ddcutil is not installed, so monitor brightness is out of reach. "
                    + "Install the ddcutil package; night light and software dim below "
                    + "work without it."
            }

            NText {
                Layout.fillWidth: true
                visible: Ddc.fault !== ""
                wrapMode: Text.WordWrap
                color: Theme.c.red
                font.pixelSize: Theme.f.small
                text: Ddc.fault
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: cardCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: cardCol
                    width: parent.width
                    spacing: Theme.px(8)

                    Repeater {
                        model: Ddc.available ? page.cards : []

                        Rectangle {
                            id: card
                            required property var modelData
                            readonly property var st: Ddc.state[modelData.bus] ?? null
                            readonly property bool writable:
                                modelData.ok && st !== null && !st.blocked && st.cur >= 0
                            readonly property real level: Ddc.shown(modelData.bus)
                            readonly property bool pending: st !== null
                                && (st.want >= 0 || st.status === "writing"
                                    || st.status === "verifying")

                            Layout.fillWidth: true
                            implicitHeight: cardBody.implicitHeight + Theme.px(24)
                            radius: Theme.r.chip
                            color: Theme.c.surface2

                            ColumnLayout {
                                id: cardBody
                                anchors.fill: parent
                                anchors.margins: Theme.px(12)
                                spacing: Theme.px(8)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(10)

                                    NText {
                                        text: card.modelData.wide ? "󰹑" : "󰍹"
                                        font.family: Theme.f.glyphs
                                        font.pixelSize: Theme.f.huge
                                        color: card.writable ? Theme.c.on : Theme.c.onFaint
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        NText {
                                            Layout.fillWidth: true
                                            text: card.modelData.label !== ""
                                                ? card.modelData.label : card.modelData.name
                                            elide: Text.ElideRight
                                            font.weight: Font.Medium
                                        }
                                        NText {
                                            text: card.modelData.name
                                                + (card.modelData.bus >= 0
                                                   ? "  ·  i2c-" + card.modelData.bus : "")
                                                + (card.st && card.st.cur >= 0
                                                   ? "  ·  0–" + card.st.max : "")
                                            font.family: Theme.f.mono
                                            font.pixelSize: Theme.f.tiny
                                            color: Theme.c.onDim
                                        }
                                    }

                                    NText {
                                        visible: card.writable || card.pending
                                        text: Math.round(card.level * 100) + "%"
                                        font.family: Theme.f.display
                                        font.pixelSize: Theme.f.huge
                                        color: card.pending ? Theme.c.onDim : Theme.c.on
                                    }
                                }

                                NSlider {
                                    Layout.fillWidth: true
                                    visible: card.modelData.ok
                                    enabled: card.writable
                                    opacity: card.writable ? 1 : 0.35
                                    value: card.level
                                    accent: card.st?.status === "error" ? Theme.c.red : Theme.c.on
                                    onMoved: (v) => {
                                        if (Config.ddcLinked)
                                            Ddc.setAll(v);
                                        else
                                            Ddc.set(card.modelData.bus, v);
                                    }
                                }

                                // Contrast, colour preset and picture mode,
                                // folded away: read from the monitor only
                                // when opened (a capabilities read takes a
                                // second or two of DDC traffic).
                                property bool picture: false
                                readonly property var ex: Ddc.extras[card.modelData.bus] ?? null

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    visible: cardBody.picture
                                    spacing: Theme.px(6)

                                    NText {
                                        visible: cardBody.ex?.loading ?? true
                                        text: "Reading what this monitor offers…"
                                        font.pixelSize: Theme.f.tiny
                                        color: Theme.c.onDim
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: (cardBody.ex?.contrast ?? null) !== null
                                        NLabel { text: "Contrast"; Layout.preferredWidth: Theme.px(70) }
                                        NSlider {
                                            id: contrast
                                            Layout.fillWidth: true
                                            value: (cardBody.ex?.contrast?.cur ?? 0) / (cardBody.ex?.contrast?.max ?? 100)
                                            property real pending: -1
                                            onMoved: (v) => { contrast.pending = v; contrastLater.restart(); }
                                            Timer {
                                                id: contrastLater
                                                interval: 220
                                                onTriggered: Ddc.setExtra(card.modelData.bus, "contrast", contrast.pending)
                                            }
                                        }
                                        NText {
                                            text: Math.max(0, cardBody.ex?.contrast?.cur ?? 0)
                                            font.family: Theme.f.mono
                                            font.pixelSize: Theme.f.small
                                        }
                                    }

                                    Repeater {
                                        model: [ { key: "preset", label: "Colour" }, { key: "mode", label: "Mode" } ]

                                        RowLayout {
                                            id: pick
                                            required property var modelData
                                            readonly property var f: cardBody.ex?.[modelData.key] ?? null
                                            Layout.fillWidth: true
                                            visible: pick.f !== null && pick.f.values.length > 0
                                            NLabel { text: pick.modelData.label; Layout.preferredWidth: Theme.px(70) }
                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: Theme.px(4)
                                                Repeater {
                                                    model: pick.f?.values ?? []
                                                    Rectangle {
                                                        id: chip
                                                        required property var modelData
                                                        readonly property bool on: chip.modelData.code === (pick.f?.cur ?? "")
                                                        implicitWidth: chipText.implicitWidth + Theme.px(16)
                                                        implicitHeight: Theme.px(22)
                                                        radius: Theme.r.pill
                                                        color: chip.on ? Theme.c.on : Theme.c.surface3
                                                        NText {
                                                            id: chipText
                                                            anchors.centerIn: parent
                                                            text: chip.modelData.name
                                                            font.pixelSize: Theme.f.tiny
                                                            color: chip.on ? Theme.c.surface : Theme.c.onDim
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: Ddc.setExtra(card.modelData.bus, pick.modelData.key, chip.modelData.code)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    NText {
                                        Layout.fillWidth: true
                                        visible: (cardBody.ex?.error ?? "") !== "" || ((cardBody.ex?.loaded ?? false)
                                            && !cardBody.ex.contrast && !cardBody.ex.preset && !cardBody.ex.mode)
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: Theme.f.tiny
                                        color: (cardBody.ex?.error ?? "") !== "" ? Theme.c.red : Theme.c.onDim
                                        text: (cardBody.ex?.error ?? "") !== "" ? cardBody.ex.error
                                            : "This monitor offers no contrast or preset over DDC/CI"
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(8)

                                    NText {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: Theme.f.tiny
                                        color: card.st?.status === "error" ? Theme.c.red : Theme.c.onDim
                                        text: {
                                            if (card.modelData.bus < 0)
                                                return Ddc.detecting ? "Looking for DDC/CI…"
                                                     : (Ddc.detected ? "No DDC/CI answer from this screen" : "");
                                            const st = card.st;
                                            if (!st)
                                                return "";
                                            switch (st.status) {
                                            case "reading": return "Reading…";
                                            case "writing": return "Setting…";
                                            case "verifying": return "Checking the monitor took it…";
                                            case "error": return st.error;
                                            case "ok": return "Set on the monitor itself";
                                            default: return "";
                                            }
                                        }
                                    }

                                    NPillButton {
                                        visible: card.modelData.ok && card.st !== null && card.st.cur >= 0
                                        text: cardBody.picture ? "Less" : "Picture"
                                        onActivated: {
                                            cardBody.picture = !cardBody.picture;
                                            if (cardBody.picture)
                                                Ddc.loadExtras(card.modelData.bus);
                                        }
                                    }

                                    NPillButton {
                                        // The one way past a refusal: read the
                                        // monitor again, then writes resume.
                                        visible: card.modelData.ok && (card.st?.blocked ?? false)
                                        text: "Try again"
                                        onActivated: Ddc.retry(card.modelData.bus)
                                    }
                                }
                            }
                        }
                    }

                    NText {
                        Layout.fillWidth: true
                        visible: Ddc.available && page.cards.length === 0
                        text: "No screen to show"
                        color: Theme.c.onFaint
                    }
                }
            }
        }

        Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.c.outline }

        // ── Night light and software dim: every screen ────────────────
        Flickable {
            Layout.preferredWidth: Theme.px(340)
            Layout.fillHeight: true
            contentHeight: rightCol.implicitHeight + Theme.pad * 2
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: rightCol
                x: Theme.pad
                y: Theme.pad
                width: parent.width - Theme.pad * 2
                spacing: Theme.px(10)

                RowLayout {
                    Layout.fillWidth: true
                    NLabel { text: "Night light" }
                    NLabel { text: "· all screens"; opacity: 0.6 }
                    Item { Layout.fillWidth: true }
                    NSwitch {
                        enabled: NightLight.available
                        opacity: enabled ? 1 : 0.35
                        checked: NightLight.active
                        onToggled: (v) => NightLight.setActive(v)
                    }
                }

                NText {
                    Layout.fillWidth: true
                    visible: !NightLight.available
                    wrapMode: Text.WordWrap
                    color: Theme.c.onDim
                    font.pixelSize: Theme.f.small
                    text: "hyprsunset is not installed. Night light and software dim "
                        + "both need it (package hyprsunset)."
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: NightLight.available
                    spacing: Theme.px(10)

                    RowLayout {
                        Layout.fillWidth: true
                        NText {
                            text: NightLight.kelvin + " K"
                            font.family: Theme.f.display
                            font.pixelSize: Theme.px(26)
                            color: NightLight.active ? Theme.c.on : Theme.c.onDim
                        }
                        Item { Layout.fillWidth: true }
                        NText {
                            text: NightLight.status
                            font.pixelSize: Theme.f.tiny
                            color: NightLight.checked && !NightLight.daemonUp
                                   && (NightLight.active || NightLight.gamma < 100)
                                ? Theme.c.red : Theme.c.onDim
                        }
                    }

                    NSlider {
                        Layout.fillWidth: true
                        // Warm on the left, as on a lamp.
                        value: (NightLight.kelvin - NightLight.minKelvin)
                             / (NightLight.maxKelvin - NightLight.minKelvin)
                        accent: NightLight.active ? Theme.c.red : Theme.c.onDim
                        onMoved: (v) => NightLight.setTemperature(NightLight.minKelvin
                            + v * (NightLight.maxKelvin - NightLight.minKelvin))
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        NLabel { text: NightLight.minKelvin + " K warm" }
                        Item { Layout.fillWidth: true }
                        NLabel { text: "neutral " + NightLight.maxKelvin + " K" }
                    }

                    SegmentedControl {
                        Layout.fillWidth: true
                        options: [
                            { label: "Neutral", value: 0 },
                            { label: "Evening", value: 4500 },
                            { label: "Warm", value: 3500 },
                            { label: "Late", value: 2700 }
                        ]
                        current: NightLight.active ? NightLight.kelvin : 0
                        onPicked: (v) => {
                            if (v === 0) {
                                NightLight.setActive(false);
                                return;
                            }
                            NightLight.setTemperature(v);
                            if (!NightLight.active)
                                NightLight.setActive(true);
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(6)
                        NText { text: "Schedule"; Layout.fillWidth: true }
                        NField {
                            implicitWidth: Theme.px(58)
                            text: Config.nightFrom
                            placeholder: "19:00"
                            onCommitted: (v) => {
                                if (page.timeRe.test(v.trim())) { Config.nightFrom = v.trim(); Config.save(); }
                                else text = Config.nightFrom;
                            }
                        }
                        NLabel { text: "to" }
                        NField {
                            implicitWidth: Theme.px(58)
                            text: Config.nightTo
                            placeholder: "06:30"
                            onCommitted: (v) => {
                                if (page.timeRe.test(v.trim())) { Config.nightTo = v.trim(); Config.save(); }
                                else text = Config.nightTo;
                            }
                        }
                        NSwitch {
                            checked: Config.nightAutomatic
                            onToggled: (v) => {
                                Config.nightAutomatic = v;
                                Config.save();
                                if (v) NightLight.apply(NightLight.inSchedule);
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        NText {
                            Layout.fillWidth: true
                            text: "Restore on login"
                        }
                        NSwitch {
                            checked: Config.nightRestore
                            onToggled: (v) => { Config.nightRestore = v; Config.save(); }
                        }
                    }
                    NText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.f.tiny
                        color: Theme.c.onFaint
                        text: "Brings back the last on/off you chose here. The schedule, "
                            + "when on, still decides inside its hours."
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

                RowLayout {
                    Layout.fillWidth: true
                    NLabel { text: "Software dim" }
                    NLabel { text: "· all screens"; opacity: 0.6 }
                    Item { Layout.fillWidth: true }
                    NText {
                        text: NightLight.gamma + "%"
                        font.family: Theme.f.mono
                        color: NightLight.gamma < 100 ? Theme.c.on : Theme.c.onDim
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: NightLight.available
                    spacing: Theme.px(8)

                    NSlider {
                        Layout.fillWidth: true
                        value: (NightLight.gamma - NightLight.gammaLowerLimit)
                             / (100 - NightLight.gammaLowerLimit)
                        onMoved: (v) => NightLight.setGamma(NightLight.gammaLowerLimit
                            + v * (100 - NightLight.gammaLowerLimit))
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        NText {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.f.tiny
                            color: Theme.c.onDim
                            text: "A visual approximation: the picture is scaled down, "
                                + "the backlight is not. Contrast drops with it, so "
                                + "lower the monitor first."
                        }
                        NPillButton {
                            text: "Normal"
                            opacity: NightLight.gamma < 100 ? 1 : 0.45
                            onActivated: NightLight.setGamma(100)
                        }
                    }

                    NText {
                        Layout.fillWidth: true
                        visible: Displays.anyHdr || Displays.anyWide
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.f.tiny
                        color: Theme.c.onDim
                        text: (Displays.anyHdr ? "An HDR output is on. " : "A 10-bit output is on. ")
                            + "Night light and dimming go through Hyprland's colour "
                            + "matrix on top of it and may look different there; "
                            + "your HDR and bit-depth settings are left as they are."
                    }
                }

                NPillButton {
                    Layout.alignment: Qt.AlignRight
                    visible: NightLight.available
                    text: "Restore neutral colours"
                    onActivated: NightLight.neutral()
                }
            }
        }
    }
}
