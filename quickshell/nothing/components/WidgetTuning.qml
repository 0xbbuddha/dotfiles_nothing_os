import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// The handful of widgets that need telling something.
//
// Every one of these sections is hidden until its widget is actually on
// the desktop. A settings page that lists knobs for things you do not have
// is how the old one grew to a wall you had to read past; a knob that
// appears with its widget is a knob you know the purpose of.
ColumnLayout {
    id: root
    spacing: Theme.px(16)

    readonly property bool anyWorldClock:
        ["worldClock", "worldClockSimple", "worldClockPair", "worldClockOne"]
            .some(id => Config.hasWidget(id))

    // Cities that cover most of a working day. Zone ids, because that is
    // what the widget hands to date(1); the label is derived from the id
    // so a city can never be listed under the wrong clock.
    readonly property var cityPool: [
        "Europe/Paris", "Europe/London", "Europe/Berlin", "Europe/Lisbon",
        "Europe/Moscow", "America/New_York", "America/Chicago",
        "America/Los_Angeles", "America/Sao_Paulo", "Africa/Lagos",
        "Africa/Johannesburg", "Asia/Dubai", "Asia/Kolkata",
        "Asia/Shanghai", "Asia/Tokyo", "Asia/Seoul", "Asia/Singapore",
        "Australia/Sydney", "Pacific/Auckland", "UTC"
    ]

    // ── Countdown ─────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.px(6)
        visible: Config.hasWidget("countdown")
            || Config.hasWidget("countdownSimple")

        NLabel { text: "Countdown" }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.px(96)
            radius: Theme.r.chip
            color: Theme.c.surface2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.px(12)
                spacing: Theme.px(8)

                NField {
                    Layout.fillWidth: true
                    text: Config.countdownLabel
                    placeholder: "What are you counting to"
                    onCommitted: (v) => {
                        Config.countdownLabel = v;
                        Config.save();
                    }
                }

                // A plain field rather than a picker. A calendar popover
                // over a panel that is itself a popover is two layers of
                // dismissal to get wrong, and this is typed once.
                NField {
                    Layout.fillWidth: true
                    text: Config.countdownDate
                    placeholder: "YYYY-MM-DD"
                    onCommitted: (v) => {
                        const t = v.trim();
                        // Refused rather than stored: a date the widget
                        // cannot read would show "--" with no way to tell
                        // that the typing was the problem.
                        if (t !== "" && !/^\d{4}-\d{2}-\d{2}$/.test(t))
                            return;
                        Config.countdownDate = t;
                        Config.save();
                    }
                }
            }
        }

        // The twelve shapes, as themselves. A list of names would be
        // meaningless: they are shapes, so you pick them by looking.
        Flickable {
            id: shapes
            Layout.fillWidth: true
            implicitHeight: Theme.px(56)
            contentWidth: shapeRow.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Row {
                id: shapeRow
                height: shapes.height
                spacing: Theme.px(6)

                Repeater {
                    model: NShapes.count

                    Rectangle {
                        required property int index
                        readonly property bool on: Config.countdownShape === index

                        width: shapes.height
                        height: width
                        radius: Theme.r.chip
                        color: on ? Theme.c.surface3 : Theme.c.surface2
                        border.width: on ? 1 : 0
                        border.color: Theme.c.red

                        NShape {
                            anchors.fill: parent
                            anchors.margins: Theme.px(9)
                            index: parent.index
                            color: parent.on ? Theme.c.red : Theme.c.onDim
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.countdownShape = parent.index;
                                Config.save();
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Screen time ───────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.px(6)
        visible: Config.hasWidget("screenTime")

        NLabel { text: "Screen time" }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.px(78)
            radius: Theme.r.chip
            color: Theme.c.surface2

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(14)
                anchors.rightMargin: Theme.px(14)
                anchors.topMargin: Theme.px(10)
                anchors.bottomMargin: Theme.px(10)
                spacing: Theme.px(2)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(10)

                    NText {
                        Layout.fillWidth: true
                        text: "Stop smiling after"
                        elide: Text.ElideRight
                    }

                    DisplayText {
                        readonly property int m: Config.screenTimeLimit
                        text: m >= 60 ? Math.floor(m / 60) + "H "
                                        + (m % 60 === 0 ? "" : (m % 60) + "M")
                                      : m + "M"
                        color: ScreenTime.over ? Theme.c.red : Theme.c.on
                    }
                }

                // Half an hour to twelve, in quarters. Below thirty the
                // face would be red before you had finished logging in.
                NSlider {
                    Layout.fillWidth: true
                    value: (Config.screenTimeLimit - 30) / (720 - 30)
                    onMoved: (v) => {
                        Config.screenTimeLimit =
                            30 + Math.round(v * (720 - 30) / 15) * 15;
                        Config.save();
                    }
                }
            }
        }
    }

    // ── World clock ───────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.px(6)
        visible: root.anyWorldClock

        RowLayout {
            Layout.fillWidth: true
            NLabel { Layout.fillWidth: true; text: "Cities" }
            NLabel {
                text: Config.worldClocks.length + "/" + Config.worldClockMax
                color: Config.worldClocks.length >= Config.worldClockMax
                    ? Theme.c.red : Theme.c.onFaint
            }
        }

        // Chosen first, in order, because the card reads them top to
        // bottom and the order is the only thing the pool cannot say.
        Repeater {
            model: Config.worldClocks

            Rectangle {
                id: chosen
                required property string modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: Theme.px(40)
                radius: Theme.r.chip
                color: Theme.c.surface2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(14)
                    anchors.rightMargin: Theme.px(10)
                    spacing: Theme.px(8)

                    NText {
                        Layout.fillWidth: true
                        text: WorldTime.shortName(chosen.modelData)
                        elide: Text.ElideRight
                    }

                    NLabel { text: chosen.modelData }

                    CircleButton {
                        icon: "󰁝"
                        size: Theme.px(24)
                        enabled: chosen.index > 0
                        opacity: enabled ? 1 : 0.25
                        onActivated: Config.moveCity(chosen.index, -1)
                    }
                    CircleButton {
                        icon: "󰁅"
                        size: Theme.px(24)
                        enabled: chosen.index < Config.worldClocks.length - 1
                        opacity: enabled ? 1 : 0.25
                        onActivated: Config.moveCity(chosen.index, 1)
                    }
                    CircleButton {
                        icon: "󰅖"
                        size: Theme.px(24)
                        onActivated: Config.toggleCity(chosen.modelData)
                    }
                }
            }
        }

        // The rest, as chips. Scrolled sideways like the widget shelves,
        // for the same reason: twenty cities stacked would be longer than
        // everything else on the tab put together.
        Flickable {
            id: pool
            Layout.fillWidth: true
            Layout.topMargin: Theme.px(2)
            implicitHeight: Theme.px(34)
            contentWidth: chips.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Row {
                id: chips
                height: pool.height
                spacing: Theme.px(6)

                Repeater {
                    model: root.cityPool.filter(z => !Config.hasCity(z))

                    NPillButton {
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        text: WorldTime.shortName(modelData)
                        // Full is full. Greying out says why nothing
                        // happens, where a chip that silently ignores the
                        // tap reads as a broken chip.
                        opacity: Config.worldClocks.length
                            >= Config.worldClockMax ? 0.3 : 1
                        onActivated: Config.toggleCity(modelData)
                    }
                }
            }
        }
    }
}
