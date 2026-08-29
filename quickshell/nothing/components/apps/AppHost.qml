import QtQuick
import QtQuick.Layouts
import "../.."
import ".."
import "../../services"

// One Essential App, drawn in a card. A pure view: the state, the tick
// and the network reads belong to MiniApps, so the same app can be shown
// on the desktop and in the panel without counting twice.
NCard {
    id: root

    required property var spec
    property bool chrome: true
    property bool closable: true
    // The library card draws its own frame, so the host inside it must
    // not draw a second one.
    property bool flat: false
    // Surface-specific header buttons: the gallery pins, the desktop
    // column unpins, and AppHost stays ignorant of both.
    property alias tools: toolRow.data

    signal edited()
    signal dropped()

    readonly property string appId: root.spec?.id ?? ""
    readonly property bool broken: !root.spec?.body || root.spec.body.length === 0

    // MiniApps mutates the state object in place, so the identity never
    // changes and QML would never re-evaluate. `pulse` is what makes the
    // binding dirty; the wrapper it returns is new every time.
    readonly property var ctx: {
        MiniApps.pulse;
        return root.spec ? MiniApps.ctxFor(root.spec) : null;
    }

    implicitHeight: body.implicitHeight + Theme.px(24)
    outlined: !root.flat
    color: root.flat ? "transparent" : Qt.lighter(Theme.c.surface, 1)
    radius: root.flat ? 0 : Theme.r.card
    // Last line of defence. Blocks elide on their own, but a generated
    // spec must not be able to paint outside its card whatever it asks
    // for, so the card cuts anything that still tries.
    clip: true

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: Theme.px(12)
        spacing: Theme.px(8)

        // ── Header ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: root.chrome
            spacing: Theme.px(8)

            NIcon {
                text: root.spec?.icon ?? "󰀻"
                size: Theme.z.icon
                color: Theme.c.onDim
            }

            NLabel {
                Layout.fillWidth: true
                text: root.spec?.name ?? ""
                elide: Text.ElideRight
            }

            NIcon {
                text: "󰖩"
                size: Theme.px(9)
                color: Theme.c.onFaint
                visible: !!root.spec?.fetch
                opacity: 0.8
            }

            Row {
                id: toolRow
                spacing: Theme.px(4)
                opacity: hostArea.containsMouse ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            }

            CircleButton {
                icon: "󰏫"
                size: Theme.px(20)
                opacity: hostArea.containsMouse ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                onActivated: root.edited()
            }

            CircleButton {
                icon: "󰅖"
                size: Theme.px(20)
                visible: root.closable && opacity > 0.01
                opacity: hostArea.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                onActivated: root.dropped()
            }
        }

        // ── Body ─────────────────────────────────────────────────────
        Repeater {
            model: root.broken ? [] : root.spec.body

            AppSlot {
                required property var modelData
                block: modelData
                appId: root.appId
                ctx: root.ctx
            }
        }

        NText {
            Layout.fillWidth: true
            visible: root.broken
            text: "This app has nothing to show. Edit it and describe what it should display."
            color: Theme.c.onDim
            wrapMode: Text.WordWrap
        }
    }

    // Hover only reveals the header buttons; clicks fall through to the
    // blocks, which own their own MouseAreas.
    MouseArea {
        id: hostArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
