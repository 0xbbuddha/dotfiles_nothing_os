import QtQuick
import QtQuick.Layouts

// One slot in an app's tree.
//
// AppBlock cannot instantiate itself by name: the QML engine rejects
// that statically, whatever Component or Repeater it is buried in. The
// tree is grown through a Loader whose source is a URL resolved at
// runtime, which is what breaks the static cycle. Layout policy lives
// here rather than in AppBlock, because this is the object the
// surrounding RowLayout or ColumnLayout actually measures.
Loader {
    id: slot

    required property var block
    property string appId: ""
    property var ctx: null
    property var item: null
    property int idx: 0

    readonly property string kind: slot.block?.t ?? ""

    // Buttons, icons and switches keep their natural width so a row can
    // pack them against a stat; everything else spreads. An image spreads
    // only when the spec gave it no width of its own.
    Layout.fillWidth: slot.kind === "image"
        ? (slot.block.width ?? 0) === 0
        : !["button", "icon", "toggle", "spacer"].includes(slot.kind)
    Layout.alignment: Qt.AlignVCenter
    // Layouts inherit their children's implicit width as a minimum, so a
    // long value propagated all the way up and nothing could shrink,
    // which is what let text run outside the card instead of eliding.
    Layout.minimumWidth: 0

    Component.onCompleted: slot.setSource(Qt.resolvedUrl("AppBlock.qml"), {
        block: Qt.binding(() => slot.block),
        appId: Qt.binding(() => slot.appId),
        ctx: Qt.binding(() => slot.ctx),
        item: Qt.binding(() => slot.item),
        idx: Qt.binding(() => slot.idx)
    })
}
