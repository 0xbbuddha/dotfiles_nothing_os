import QtQuick
import QtQuick.Layouts
import ".."

// Connectivity pill: white when on, black when off.
Rectangle {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    signal toggled()
    signal secondary()

    implicitHeight: Theme.px(42)
    implicitWidth: Theme.px(120)
    radius: Theme.r.chip
    color: active ? Theme.c.on : Theme.c.surface2

    Behavior on color { ColorAnimation { duration: Theme.med } }

    readonly property color fg: active ? Theme.c.surface : Theme.c.on
    // An active tile is filled with `on`, so its text sits on the inverted
    // surface and has to be `surface`, dimmed. A hardcoded black was right
    // only by accident: the active fill is white on a dark shell, but black
    // on a light one, where the subtitle then turned black on black.
    readonly property color fgDim: active
        ? ColorUtils.applyAlpha(Theme.c.surface, 0.5)
        : Theme.c.onDim

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(8)
        anchors.rightMargin: Theme.px(8)
        spacing: Theme.px(7)

        Rectangle {
            id: badge
            Layout.preferredWidth: Theme.px(24)
            Layout.preferredHeight: Theme.px(24)
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            color: root.active ? Theme.c.surface : Theme.c.surface3

            readonly property bool wifiGlyph:
                root.icon === "󰖩" || root.icon === "󰖪"

            // The Wi-Fi Nerd Font glyph overflows its advance: draw it so
            // it actually sits in the centre of the circle.
            Canvas {
                id: wifiMark
                visible: badge.wifiGlyph
                anchors.centerIn: parent
                width: Theme.px(12)
                height: Theme.px(12)
                antialiasing: true

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const w = width, h = height;
                    const ink = root.active ? Theme.c.on : Theme.c.onDim;
                    ctx.strokeStyle = ink;
                    ctx.fillStyle = ink;
                    ctx.lineWidth = Math.max(1.2, w * 0.11);
                    ctx.lineCap = "round";

                    // Emitter dot a little below centre, arcs above:
                    // the whole block (dot + 3 arcs) lands in the middle of the square.
                    const cx = w / 2;
                    const cy = h * 0.72;
                    const radii = [h * 0.22, h * 0.42, h * 0.62];
                    for (let i = 0; i < radii.length; i++) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, radii[i], Math.PI * 1.28, Math.PI * 1.72, false);
                        ctx.stroke();
                    }
                    ctx.beginPath();
                    ctx.arc(cx, cy, Math.max(1.05, w * 0.07), 0, Math.PI * 2);
                    ctx.fill();

                    if (root.icon === "󰖪") {
                        ctx.beginPath();
                        ctx.moveTo(w * 0.18, h * 0.82);
                        ctx.lineTo(w * 0.82, h * 0.18);
                        ctx.stroke();
                    }
                }

                Connections {
                    target: root
                    function onIconChanged() { wifiMark.requestPaint(); }
                    function onActiveChanged() { wifiMark.requestPaint(); }
                }
                Component.onCompleted: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            NIcon {
                visible: !badge.wifiGlyph
                anchors.centerIn: parent
                text: root.icon
                size: Theme.px(14)
                color: root.active ? Theme.c.on : Theme.c.onDim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            NText {
                Layout.fillWidth: true
                text: root.title
                color: root.fg
                font.pixelSize: Theme.f.body
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.subtitle
                color: root.fgDim
                font.family: Theme.f.mono
                font.pixelSize: Theme.f.tiny
                font.letterSpacing: 0.6
                font.capitalization: Font.AllUppercase
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (m) => m.button === Qt.RightButton ? root.secondary() : root.toggled()
    }
}
