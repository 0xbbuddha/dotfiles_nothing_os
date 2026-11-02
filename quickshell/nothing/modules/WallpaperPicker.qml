import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"
import "../services"

// SUPER+SHIFT+T: pick one of the three characters this rice ships with.
//
// Only Tamaki, Frieren and Waguri - no file browser, no folder scan. A
// custom picture is still available from Settings > Appearance or
// Dolphin's "Set as wallpaper" (applications/servicemenus/); this sheet
// is only the quick, no-typing path for the bundled set.
OverlayWindow {
    id: win
    open: GlobalState.wallpaperPickerOpen
    onCloseRequested: GlobalState.wallpaperPickerOpen = false
    sheetWidth: Math.min(Theme.px(820), screen.width * 0.9)
    sheetHeight: col.implicitHeight + Theme.pad * 2
    // Low and out of the way, no scrim: the choice plays out as the
    // reveal on the wallpaper itself, which the sheet must not hide.
    topBias: 0.85
    scrim: "transparent"

    // "" = every screen, else a connector name.
    property string target: ""
    readonly property var screenNames: Quickshell.screens.map(s => s.name)

    function apply(value: string): void {
        Wallpapers.set(value, win.target);
    }

    readonly property bool active:
        win.target === "" ? Config.wallpaper === Wallpapers.dotWallpaperKey
                           : Wallpapers.isCurrent(Wallpapers.dotWallpaperKey, win.target)

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.gap

        // ── Header: for which screen, how ────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(10)

            ColumnLayout {
                spacing: Theme.px(2)
                DisplayText { text: "WALLPAPER"; size: Theme.px(22) }
                NText { text: "Pick a character"; color: Theme.c.onDim; font.pixelSize: Theme.f.small }
            }

            Item { Layout.fillWidth: true }

            SegmentedControl {
                Layout.fillWidth: false
                Layout.preferredWidth: Theme.px(110) * (win.screenNames.length + 1)
                visible: win.screenNames.length > 1
                options: [{ label: "All screens", value: "" }]
                    .concat(win.screenNames.map(n => ({ label: n, value: n })))
                current: win.target
                onPicked: (v) => win.target = v
            }

            SegmentedControl {
                Layout.fillWidth: false
                Layout.preferredWidth: Theme.px(130)
                options: [{ label: "Crop", value: "crop" }, { label: "Fit", value: "fit" }]
                current: Config.wallpaperFill
                onPicked: (v) => { Config.wallpaperFill = v; Config.save(); }
            }

            CircleButton {
                icon: "󰅖"
                size: Theme.px(26)
                onActivated: win.requestClose()
            }
        }

        // ── Characters ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(14)

            Repeater {
                model: Wallpapers.dotWallpaperChars

                Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool active:
                        win.active && Config.dotWallpaperChar === card.modelData.value

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(240)
                    radius: Theme.r.panel
                    color: Theme.c.surface2
                    border.width: card.active ? 2 : 0
                    border.color: Theme.c.red
                    clip: true
                    scale: dma.pressed ? 0.98 : (dma.containsMouse ? 1.02 : 1)
                    Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
                    Behavior on border.width { NumberAnimation { duration: Theme.fast } }

                    Image {
                        id: art
                        anchors.fill: parent
                        source: "file://" + Wallpapers.dotWallpaperPathFor(card.modelData.value, true)
                        sourceSize.width: Theme.px(560)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: card.active || dma.containsMouse ? 1 : 0.72
                        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.px(64)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
                        }
                    }

                    DisplayText {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.px(14)
                        text: card.modelData.label.toUpperCase()
                        size: Theme.px(16)
                        color: "white"
                    }

                    // A clear "this one is on" badge rather than a thin
                    // bottom-left dot: the picker's one job is choosing
                    // between three faces, so the choice should read at
                    // a glance, not on close inspection.
                    Rectangle {
                        visible: card.active
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Theme.px(10)
                        width: Theme.px(26); height: width; radius: width / 2
                        color: Theme.c.red
                        NText {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "white"
                            font.pixelSize: Theme.f.small
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: dma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Config.dotWallpaperChar = card.modelData.value;
                            win.apply(Wallpapers.dotWallpaperKey);
                        }
                    }
                }
            }
        }
    }
}
