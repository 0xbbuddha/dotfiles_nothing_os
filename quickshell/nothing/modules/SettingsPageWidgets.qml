import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// Desktop widget management: enable, order, preview.
SettingsPage {
    id: page

    SettingsSection {
        title: "Glyph Matrix"

        SettingRow {
            key: "glyphEnabled"
            label: "Show the matrix"
            hint: "A disc on every screen"
            DotSwitch {
                checked: Config.glyphEnabled
                onToggled: (v) => { Config.glyphEnabled = v; Config.save(); }
            }
        }

        SettingRow {
            key: "glyphSize"
            label: "Size"
            hint: "Diameter of the disc"
            DotSlider {
                implicitWidth: Theme.px(180)
                count: 12
                value: (Config.glyphSize - 140) / 220
                display: Config.glyphSize + " px"
                onMoved: (v) => {
                    Config.glyphSize = Math.round(140 + v * 220);
                    Config.save();
                }
            }
        }

        SettingRow {
            key: "glyphAbove"
            label: "Above windows"
            hint: "Otherwise it stays on the desktop, under windows"
            DotSwitch {
                checked: Config.glyphAbove
                onToggled: (v) => { Config.glyphAbove = v; Config.save(); }
            }
        }

        SettingRow {
            key: "glyphPos"
            label: "Position"
            hint: "Drag the disc, or put it back on the right"
            NPillButton {
                text: "Recenter"
                onActivated: Config.recenterGlyph()
            }
        }

        SettingRow {
            key: "glyphToys"
            label: "Toys"
            hint: "Left click cycles those that are on"
        }

        Repeater {
            model: GlyphCatalog.all

            Rectangle {
                id: toy
                required property var modelData
                readonly property bool on: (Config.glyphToys ?? []).includes(modelData.id)

                Layout.fillWidth: true
                implicitHeight: Theme.px(44)
                radius: Theme.r.chip
                color: toy.on ? Theme.c.surface2 : "transparent"
                border.width: toy.on ? 0 : 1
                border.color: Theme.c.outline

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(16)
                    anchors.rightMargin: Theme.px(14)
                    spacing: Theme.px(12)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: toy.modelData.label
                            color: Theme.c.on
                            font.family: Theme.f.sans
                            font.pixelSize: Theme.f.body
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: toy.modelData.hint
                            color: Theme.c.onDim
                            font.family: Theme.f.sans
                            font.pixelSize: Theme.f.small
                            elide: Text.ElideRight
                        }
                    }

                    DotSwitch {
                        checked: toy.on
                        onToggled: Config.toggleGlyphToy(toy.modelData.id)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Config.hasGlyphToy("visualizer") && !Cava.available
            text: "cava is not installed. The visualizer stays blank until it is. sudo pacman -S cava"
            color: Theme.c.onDim
            wrapMode: Text.WordWrap
            font.family: Theme.f.sans
            font.pixelSize: Theme.f.small
        }
    }

    SettingsSection {
        title: "Shown"

        SettingRow {
            key: "widgets"
            label: "Desktop widgets"
            hint: Config.widgets.length + " in the column, ordered top to bottom"
        }

        Text {
            Layout.fillWidth: true
            visible: Config.widgets.length === 0
            text: "No widgets. Add one from the list below."
            color: Theme.c.onDim
            font.family: Theme.f.sans
            font.pixelSize: Theme.f.small
        }

        Repeater {
            model: Config.widgets

            Rectangle {
                id: row
                required property string modelData
                required property int index
                readonly property var meta: WidgetRegistry.meta(modelData)

                Layout.fillWidth: true
                implicitHeight: Theme.px(50)
                radius: Theme.r.chip
                color: Theme.c.surface2

                // Position in the stack, in red
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.px(3)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(3)
                    height: Theme.px(18)
                    radius: width / 2
                    color: Theme.c.red
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(16)
                    anchors.rightMargin: Theme.px(10)
                    spacing: Theme.px(12)

                    NIcon {
                        text: WidgetRegistry.icon(row.modelData)
                        size: Theme.z.iconM
                        color: Theme.c.on
                        Layout.preferredWidth: Theme.px(18)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: row.meta?.label ?? row.modelData
                            color: Theme.c.on
                            font.family: Theme.f.sans
                            font.pixelSize: Theme.f.body
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.meta?.hint ?? ""
                            color: Theme.c.onDim
                            font.family: Theme.f.sans
                            font.pixelSize: Theme.f.small
                            elide: Text.ElideRight
                        }
                    }

                    NLabel { text: (row.index + 1) + "/" + Config.widgets.length }

                    CircleButton {
                        icon: "󰁝"
                        size: Theme.px(24)
                        enabled: row.index > 0
                        opacity: enabled ? 1 : 0.25
                        onActivated: Config.moveWidget(row.index, -1)
                    }
                    CircleButton {
                        icon: "󰁅"
                        size: Theme.px(24)
                        enabled: row.index < Config.widgets.length - 1
                        opacity: enabled ? 1 : 0.25
                        onActivated: Config.moveWidget(row.index, 1)
                    }
                    CircleButton {
                        icon: "󰅖"
                        size: Theme.px(24)
                        onActivated: Config.removeWidget(row.modelData)
                    }
                }
            }
        }
    }

    SettingsSection {
        title: "Available"

        Repeater {
            model: WidgetRegistry.all.filter(w => !Config.hasWidget(w.id))

            Rectangle {
                id: avail
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: Theme.px(44)
                radius: Theme.r.chip
                color: ama.containsMouse ? Theme.c.surface2 : "transparent"
                border.width: ama.containsMouse ? 0 : 1
                border.color: Theme.c.outline
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(16)
                    anchors.rightMargin: Theme.px(14)
                    spacing: Theme.px(12)

                    NIcon {
                        text: avail.modelData.icon
                        size: Theme.z.iconM
                        color: Theme.c.onDim
                        Layout.preferredWidth: Theme.px(18)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: avail.modelData.label
                            color: Theme.c.on
                            font.family: Theme.f.sans
                            font.pixelSize: Theme.f.body
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: avail.modelData.hint
                            color: Theme.c.onDim
                            font.family: Theme.f.sans
                            font.pixelSize: Theme.f.small
                            elide: Text.ElideRight
                        }
                    }

                    NIcon { text: "󰐕"; size: Theme.z.icon; color: Theme.c.onDim }
                }

                MouseArea {
                    id: ama
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.addWidget(avail.modelData.id)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: WidgetRegistry.all.length === Config.widgets.length
            text: "Every widget is already shown."
            color: Theme.c.onDim
            font.family: Theme.f.sans
            font.pixelSize: Theme.f.small
        }
    }

    SettingsSection {
        title: "Column"

        SettingRow {
            key: "widgetsShown"
            label: "Show widgets"
            hint: "On every screen"
            DotSwitch {
                checked: Config.showDesktopWidgets
                onToggled: (v) => { Config.showDesktopWidgets = v; Config.save(); }
            }
        }
    }
}
