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
                text: root.meta?.glyph ?? "󰧵"
                size: Theme.z.iconM
                Layout.preferredWidth: Theme.px(20)
            }

            ColumnLayout {
                Layout.fillWidth: true
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

            DotSwitch {
                visible: root.sid === "matrix"
                checked: Config.glyphEnabled
                onToggled: (v) => { Config.glyphEnabled = v; Config.save(); }
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
