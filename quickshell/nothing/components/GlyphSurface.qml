import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// One Glyph surface in the launcher. Today that is the Matrix; the strip
// and the progress bar will be further entries in GlyphRegistry, and this
// switches on the id rather than assuming there is only ever one.
Rectangle {
    id: root
    required property var meta
    readonly property string sid: meta?.id ?? ""

    // The launcher pane names the section above this card, so repeating
    // the name and the hint inside it says everything twice. The switch
    // stays either way: it is the one control that has nowhere else to go.
    property bool titled: true

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + Theme.px(24)
    radius: Theme.r.card
    color: Theme.c.surface2

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.px(12)
        spacing: Theme.px(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(12)

            NIcon {
                visible: root.titled
                text: root.meta?.glyph ?? "󰧵"
                size: Theme.z.iconM
                Layout.preferredWidth: Theme.px(20)
            }

            // Without the name above it the switch was a pair of dots
            // floating in a corner, attached to nothing.
            NText {
                visible: !root.titled
                text: "Enabled"
            }

            Item { Layout.fillWidth: true; visible: !root.titled }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.titled
                spacing: 0
                NText {
                    Layout.fillWidth: true
                    text: root.meta?.label ?? root.sid
                    font.pixelSize: Theme.f.body
                }
                NText {
                    Layout.fillWidth: true
                    text: root.meta?.hint ?? ""
                    color: Theme.c.onDim
                    elide: Text.ElideRight
                }
            }

            // Exclusive: turning one on turns the other off. Turning one
            // off leaves both off, which is allowed.
            DotSwitch {
                visible: root.sid === "matrix"
                checked: Config.glyphEnabled
                onToggled: (v) => Config.enableGlyph("matrix", v)
            }

            DotSwitch {
                visible: root.sid === "bar"
                checked: Config.glyphBarEnabled
                onToggled: (v) => Config.enableGlyph("bar", v)
            }

            DotSwitch {
                visible: root.sid === "strip"
                checked: Config.glyphStripEnabled
                onToggled: (v) => Config.enableGlyph("strip", v)
            }
        }

        // ── Bar ───────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: root.sid === "bar" && Config.glyphBarEnabled
            spacing: Theme.px(14)

            // The strip itself, live, at the size it fits. A row of names
            // would not tell you what any of it looks like, and this is
            // the one setting whose result is entirely visual.
            // The bar itself, in the state it is in on the desktop, at the
            // proportions it has there. It ran a looping demonstration at
            // first, which made the panel livelier and was a lie: the
            // desktop bar is dark, and a preview that is never dark is not
            // a preview. Clicking it fires a reveal, which lights this and
            // the real one together.
            Item {
                readonly property real pad: Theme.px(5)

                Layout.preferredHeight: Theme.px(190)
                Layout.preferredWidth: Math.round(
                    (height - 2 * pad) / GlyphBar.aspect + 2 * pad)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.px(4)
                    color: "#0b0b0b"
                }

                GlyphBarStrip {
                    anchors.fill: parent
                    anchors.margins: parent.pad
                    onColor: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: GlyphEvents.reveal()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: Theme.px(520)
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.px(8)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(10)
                    NLabel { text: "Length"; Layout.preferredWidth: Theme.px(58) }
                    DotSlider {
                        Layout.fillWidth: true
                        count: 12
                        value: (Config.glyphBarLength - 180) / 320
                        display: Config.glyphBarLength + " px"
                        onMoved: (v) => {
                            Config.glyphBarLength = Math.round(180 + v * 320);
                            Config.save();
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(10)
                    NLabel { text: "Brightness"; Layout.preferredWidth: Theme.px(58) }
                    SegmentedControl {
                        Layout.fillWidth: true
                        options: [
                            { label: "Low",    value: "0" },
                            { label: "Medium", value: "1" },
                            { label: "High",   value: "2" }
                        ]
                        current: String(Config.glyphLevel)
                        onPicked: (v) => {
                            Config.glyphLevel = parseInt(v);
                            Config.save();
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(10)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        NText { text: "Always above windows" }
                        NText {
                            Layout.fillWidth: true
                            text: "It rises for an event either way"
                            color: Theme.c.onDim
                            elide: Text.ElideRight
                        }
                    }
                    DotSwitch {
                        checked: Config.glyphBarAbove
                        onToggled: (v) => {
                            Config.glyphBarAbove = v;
                            Config.save();
                        }
                    }
                    NPillButton {
                        text: "Recenter"
                        onActivated: {
                            Config.glyphBarX = -1;
                            Config.glyphBarY = -1;
                            Config.save();
                        }
                    }
                }

            }
        }

        // ── Strip ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: root.sid === "strip" && Config.glyphStripEnabled
            spacing: Theme.px(14)

            // The ring itself, in the state it is in on the desktop.
            GlyphStripRing {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Theme.px(150)
                Layout.preferredHeight: Theme.px(150)
                onColor: "#ffffff"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: GlyphEvents.reveal()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                // Capped: a twelve-dot slider stretched across the whole
                // pane spreads its dots so far apart that it stops reading
                // as one control.
                Layout.maximumWidth: Theme.px(520)
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.px(8)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(10)
                    NLabel { text: "Size"; Layout.preferredWidth: Theme.px(58) }
                    DotSlider {
                        Layout.fillWidth: true
                        count: 12
                        value: (Config.glyphStripSize - 140) / 220
                        display: Config.glyphStripSize + " px"
                        onMoved: (v) => {
                            Config.glyphStripSize = Math.round(140 + v * 220);
                            Config.save();
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(10)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        NText { text: "Always above windows" }
                        NText {
                            Layout.fillWidth: true
                            text: "It rises for an event either way"
                            color: Theme.c.onDim
                            elide: Text.ElideRight
                        }
                    }
                    DotSwitch {
                        checked: Config.glyphStripAbove
                        onToggled: (v) => {
                            Config.glyphStripAbove = v;
                            Config.save();
                        }
                    }
                    NPillButton {
                        text: "Recenter"
                        onActivated: {
                            Config.glyphStripX = -1;
                            Config.glyphStripY = -1;
                            Config.save();
                        }
                    }
                }
            }
        }

        // ── Shared by every event-driven surface ──────────────────────
        //
        // Only one Glyph is ever lit, so which sources you care about and
        // how bright they are belong to you, not to the shape. Keeping a
        // copy per surface would have meant setting them twice and finding
        // out later that they had drifted.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Theme.px(640)
            spacing: Theme.px(10)
            visible: (root.sid === "bar" && Config.glyphBarEnabled)
                || (root.sid === "strip" && Config.glyphStripEnabled)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(10)
                NLabel { text: "Brightness"; Layout.preferredWidth: Theme.px(58) }
                SegmentedControl {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Theme.px(320)
                    options: [
                        { label: "Low",    value: "0" },
                        { label: "Medium", value: "1" },
                        { label: "High",   value: "2" }
                    ]
                    current: String(Config.glyphLevel)
                    onPicked: (v) => {
                        Config.glyphLevel = parseInt(v);
                        Config.save();
                    }
                }
            }

                NLabel { text: "What lights it"; Layout.topMargin: Theme.px(4) }
                NText {
                    Layout.fillWidth: true
                    text: "The bar is dark otherwise. Switch off anything you "
                        + "would rather not be told about."
                    color: Theme.c.onFaint
                    font.pixelSize: Theme.f.tiny
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: GlyphEvents.sources

                    // Named, not reached through parent. Counting parents
                    // up from a nested delegate breaks the moment anything
                    // is wrapped, and it broke here: one of these read the
                    // label off the ColumnLayout, which has no model.
                    RowLayout {
                        id: source
                        required property var modelData

                        readonly property bool on: (Config.glyphEvents ?? [])
                            .indexOf(modelData.id) >= 0

                        Layout.fillWidth: true
                        spacing: Theme.px(8)

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            NText { text: source.modelData.label }
                            NText {
                                Layout.fillWidth: true
                                text: source.modelData.hint
                                color: Theme.c.onDim
                                font.pixelSize: Theme.f.tiny
                                elide: Text.ElideRight
                            }
                        }

                        // The rhythm this event plays. Cycles rather than
                        // opening a menu: nine is short enough to walk,
                        // and a popover inside a popover is two
                        // dismissals to get wrong.
                        //
                        // Picking one plays it on the real surface. A list
                        // of names is meaningless for something whose
                        // entire content is timing, so choosing it is
                        // also how you hear it.
                        NPillButton {
                            visible: source.modelData.rhythm === true
                                && source.on
                            maxWidth: Theme.px(132)
                            text: GlyphEvents.patternLabel(
                                Config.glyphPattern(source.modelData.id))
                            onActivated: {
                                Config.stepGlyphPattern(
                                    source.modelData.id, 1);
                                GlyphEvents.preview(Config.glyphPattern(
                                    source.modelData.id));
                            }
                        }

                        DotSwitch {
                            checked: source.on
                            onToggled: Config.toggleGlyphEvent(
                                source.modelData.id)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.px(4)
                    spacing: Theme.px(8)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        NText { text: "Instead of the popups" }
                        NText {
                            Layout.fillWidth: true
                            text: "No notification card, no volume pill: the "
                                + "bar has already said it"
                            color: Theme.c.onDim
                            font.pixelSize: Theme.f.tiny
                            wrapMode: Text.WordWrap
                        }
                    }

                    DotSwitch {
                        checked: Config.glyphQuiet
                        onToggled: (v) => {
                            Config.glyphQuiet = v;
                            Config.save();
                        }
                    }
                }

                GlyphComposer { Layout.fillWidth: true }

                // Only the reveal reads these, so they are hidden with it.
                NLabel {
                    text: "Segments"
                    Layout.topMargin: Theme.px(4)
                    visible: (Config.glyphEvents ?? []).indexOf("reveal") >= 0
                }
                NText {
                    Layout.fillWidth: true
                    visible: (Config.glyphEvents ?? []).indexOf("reveal") >= 0
                    text: "Top to bottom, as they sit on the strip"
                    color: Theme.c.onFaint
                    font.pixelSize: Theme.f.tiny
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    // How many readings the lit surface can show: six on
                    // the bar, three on the strip, which has three arcs
                    // and no honest place to put a fourth.
                    model: GlyphEvents.slots

                    RowLayout {
                        id: slot
                        required property int index

                        Layout.fillWidth: true
                        spacing: Theme.px(8)
                        visible: (Config.glyphEvents ?? [])
                            .indexOf("reveal") >= 0

                        NLabel {
                            Layout.preferredWidth: Theme.px(16)
                            text: String(slot.index + 1)
                        }

                        // Cycles rather than opening a menu: eight
                        // choices is short enough to walk, and a popover
                        // inside a popover is two dismissals to get wrong.
                        NPillButton {
                            Layout.fillWidth: true
                            maxWidth: Theme.px(150)
                            text: GlyphEvents.channelLabel(
                                (Config.glyphChannels ?? [])[slot.index] ?? "off")
                            onActivated: {
                                const list = GlyphEvents.channels;
                                const cur = (Config.glyphChannels ?? [])[slot.index] ?? "off";
                                let at = list.findIndex(c => c.id === cur);
                                if (at < 0)
                                    at = 0;
                                Config.setGlyphChannel(slot.index,
                                    list[(at + 1) % list.length].id);
                            }
                        }
                    }
                }
        }

        // ── Matrix ────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.sid === "matrix" && Config.glyphEnabled
            spacing: Theme.px(10)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(10)

                NLabel { text: "Size"; Layout.preferredWidth: Theme.px(52) }
                DotSlider {
                    Layout.fillWidth: true
                    count: 12
                    value: (Config.glyphSize - 140) / 220
                    display: Config.glyphSize + " px"
                    onMoved: (v) => {
                        Config.glyphSize = Math.round(140 + v * 220);
                        Config.save();
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(10)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    NText { text: "Above windows" }
                    NText {
                        text: "Otherwise it stays on the desktop, under windows"
                        color: Theme.c.onDim
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                DotSwitch {
                    checked: Config.glyphAbove
                    onToggled: (v) => { Config.glyphAbove = v; Config.save(); }
                }
                NPillButton {
                    text: "Recenter"
                    onActivated: Config.recenterGlyph()
                }
            }

            NLabel { text: "Toys"; Layout.topMargin: Theme.px(4) }
            NText {
                Layout.fillWidth: true
                text: "Left click on the disc cycles the ones that are on."
                color: Theme.c.onDim
                elide: Text.ElideRight
            }

            // A grid: the toys are a set to pick from, and a column of
            // nine full-width rows buried everything below them.
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.px(8)
                rowSpacing: Theme.px(8)

                Repeater {
                    model: GlyphCatalog.all

                    Rectangle {
                        id: toy
                        required property var modelData
                        readonly property bool on:
                            (Config.glyphToys ?? []).includes(modelData.id)

                        Layout.fillWidth: true
                        implicitHeight: Theme.px(42)
                        radius: Theme.r.chip
                        color: toy.on ? Theme.c.surface3 : Theme.c.surface
                        border.width: toy.on ? 0 : 1
                        border.color: Theme.c.outline

                        Behavior on color { ColorAnimation { duration: Theme.fast } }

                        // A lit dot, because the fill alone did not carry
                        // it: side by side, on and off differed by a hair
                        // of grey and a border nobody reads as a state.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.px(12)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(6)
                            height: width
                            radius: width / 2
                            color: toy.on ? Theme.c.red : Theme.c.onFaint
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.px(26)
                            anchors.rightMargin: Theme.px(12)
                            spacing: 0

                            NText {
                                Layout.fillWidth: true
                                text: toy.modelData.label
                                color: toy.on ? Theme.c.on : Theme.c.onDim
                                font.weight: toy.on ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                            }
                            NText {
                                Layout.fillWidth: true
                                text: toy.modelData.hint
                                color: Theme.c.onFaint
                                font.pixelSize: Theme.f.tiny
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.toggleGlyphToy(toy.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
