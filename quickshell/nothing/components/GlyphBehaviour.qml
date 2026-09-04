import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// How the Glyph behaves, whichever one is lit.
//
// Its own section, not a block repeated on each surface page. Only one
// Glyph is ever on, and every setting here is stored once: which events
// may light it, the rhythm each one plays, whether it stands in for the
// on-screen popups, and what a click reveals. Showing that three times
// said it was a property of the shape, which it is not, and left you
// wondering which of the three copies was the real one.
ColumnLayout {
    id: root
    spacing: Theme.px(10)

    // Which surface these settings belong to. Per surface, because
    // switching Glyph used to carry over choices made for a different
    // shape, and because the channel list cannot be shared at all: the
    // Strip has three sectors and the Bar six.
    required property string surface

    readonly property bool live: root.surface !== ""

    NText {
        Layout.fillWidth: true
        visible: !root.live
        text: "Turn this Glyph on to set how it behaves."
        color: Theme.c.onDim
        wrapMode: Text.WordWrap
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: Theme.px(640)
        spacing: Theme.px(10)
        visible: root.live

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
                current: String(Config.glyphLevelOf(root.surface))
                onPicked: (v) => {
                    Config.setGlyphLevel(root.surface, parseInt(v));
                }
            }
        }

            NLabel { text: "What lights it"; Layout.topMargin: Theme.px(4) }
            NText {
                Layout.fillWidth: true
                text: "The Glyph is dark otherwise. Switch off anything you "
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

                    readonly property bool on: Config
                        .glyphEventsOf(root.surface)
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
                            Config.glyphPattern(root.surface,
                                    source.modelData.id))
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
                            + "Glyph has already said it"
                        color: Theme.c.onDim
                        font.pixelSize: Theme.f.tiny
                        wrapMode: Text.WordWrap
                    }
                }

                DotSwitch {
                    checked: Config.glyphQuietOf(root.surface)
                    onToggled: (v) => Config.setGlyphQuiet(root.surface, v)
                }
            }

            GlyphComposer { Layout.fillWidth: true }

            // Only the reveal reads these, so they are hidden with it.
            NLabel {
                text: "Segments"
                Layout.topMargin: Theme.px(4)
                visible: Config.glyphEventsOf(root.surface)
                    .indexOf("reveal") >= 0
            }
            NText {
                Layout.fillWidth: true
                visible: Config.glyphEventsOf(root.surface)
                    .indexOf("reveal") >= 0
                // Down the Bar, round the rim of the Matrix and the Strip.
                    text: "In the order they sit on the Glyph"
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
                    visible: Config.glyphEventsOf(root.surface)
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
                            Config.glyphChannelsOf(root.surface)[slot.index] ?? "off")
                        onActivated: {
                            const list = GlyphEvents.channels;
                            const cur = Config.glyphChannelsOf(
                                    root.surface)[slot.index] ?? "off";
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
}
