import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// One MPRIS source: cover in the background, gradient if no image, independent pause.
Item {
    id: root
    required property var player

    readonly property bool playing: Player.isPlaying(player)
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property bool hasArt: bg.status === Image.Ready

    implicitHeight: Theme.px(54)
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.r.chip
        color: Theme.c.surface3
        clip: true

        Image {
            id: bg
            anchors.fill: parent
            anchors.leftMargin: root.hasArt ? -Math.round(parent.width * 0.12) : 0
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: root.hasArt
        }

        // Scrim: the text stays readable, the cover shows through on the right.
        Rectangle {
            anchors.fill: parent
            visible: root.hasArt
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.78) }
                GradientStop { position: 0.42; color: Qt.rgba(0, 0, 0, 0.52) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.18) }
            }
        }

        // No cover: surface → accent gradient, Nothing-style.
        Rectangle {
            anchors.fill: parent
            visible: !root.hasArt
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.c.surface3 }
                GradientStop { position: 0.55; color: Theme.c.surface2 }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(Theme.c.red.r, Theme.c.red.g, Theme.c.red.b, 0.32)
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.px(8)
            anchors.rightMargin: Theme.px(8)
            spacing: Theme.px(9)

            Rectangle {
                Layout.preferredWidth: Theme.px(34)
                Layout.preferredHeight: Theme.px(34)
                radius: Theme.r.tiny
                color: Qt.rgba(0, 0, 0, 0.35)
                clip: true

                Image {
                    id: art
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                AppIcon {
                    anchors.centerIn: parent
                    size: Theme.px(16)
                    appId: root.player?.desktopEntry ?? ""
                    visible: art.status !== Image.Ready && (root.player?.desktopEntry ?? "") !== ""
                }

                NIcon {
                    anchors.centerIn: parent
                    text: "󰎆"
                    size: Theme.z.iconM
                    color: Theme.c.onFaint
                    visible: art.status !== Image.Ready && (root.player?.desktopEntry ?? "") === ""
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: Player.titleOf(root.player) || (root.player?.identity ?? "Player")
                    color: Theme.c.on
                    font.family: Theme.f.sans
                    font.pixelSize: Theme.f.body
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        const sub = Player.subtitleOf(root.player);
                        const who = root.player?.identity ?? "";
                        if (sub !== "" && sub !== who)
                            return who !== "" ? who + " · " + sub : sub;
                        return who;
                    }
                    color: Theme.c.onDim
                    font.family: Theme.f.sans
                    font.pixelSize: Theme.f.small
                    elide: Text.ElideRight
                }
            }

            CircleButton {
                icon: root.playing ? "󰏤" : "󰐊"
                filled: root.playing
                enabled: root.player?.canTogglePlaying ?? false
                onActivated: Player.playPause(root.player)
            }
        }
    }
}
