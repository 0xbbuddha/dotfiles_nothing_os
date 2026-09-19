import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"
import "../services"

// Which dot-matrix figure to draw, full-bleed, one shortcut away:
// SUPER+SHIFT+T. Deliberately just this one choice - the rest of the
// look already has a home in Settings, and a picker that tried to be
// both would be neither.
OverlayWindow {
    id: win
    open: GlobalState.wallpaperPickerOpen
    onCloseRequested: GlobalState.wallpaperPickerOpen = false
    sheetWidth: Math.min(Theme.px(720), screen.width * 0.9)
    sheetHeight: col.implicitHeight + Theme.pad * 2
    topBias: 0.42

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.gap

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(8)

            DisplayText { text: "WALLPAPER"; size: Theme.px(22) }
            Item { Layout.fillWidth: true }
            CircleButton {
                icon: "󰅖"
                size: Theme.px(26)
                onActivated: win.requestClose()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.px(4)
            spacing: Theme.px(14)

            Repeater {
                model: Wallpapers.dotWallpaperChars

                Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool active:
                        Wallpapers.dotWallpaperOn
                        && Config.dotWallpaperChar === card.modelData.value

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(230)
                    radius: Theme.r.panel
                    color: Theme.c.surface2
                    border.width: card.active ? 2 : 0
                    border.color: Theme.c.red
                    clip: true

                    scale: ma.pressed ? 0.98 : (ma.containsMouse ? 1.015 : 1)
                    Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
                    Behavior on border.width { NumberAnimation { duration: Theme.fast } }

                    Image {
                        anchors.fill: parent
                        source: "file://" + Wallpapers.dotWallpaperPathFor(card.modelData.value, true)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                    }

                    // A dark floor under the label: the dot-matrix render
                    // is mostly white, and white text on white loses on
                    // half of them.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.px(56)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                        }
                    }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.px(12)
                        spacing: Theme.px(6)

                        Rectangle {
                            visible: card.active
                            width: Theme.px(6); height: width; radius: width / 2
                            color: Theme.c.red
                        }

                        DisplayText { text: card.modelData.label.toUpperCase(); size: Theme.px(16) }

                        Item { Layout.fillWidth: true }

                        NLabel {
                            visible: card.active
                            text: "in use"
                            dim: false
                        }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (card.active)
                                return;
                            Config.dotWallpaperChar = card.modelData.value;
                            Config.wallpaper = Wallpapers.dotWallpaperKey;
                            Config.save();
                        }
                    }
                }
            }
        }
    }
}
