import QtQuick
import QtQuick.Layouts
import ".."

// Shared base for settings pages: scrolling, spaced column, and
// cascade appearance of blocks when the page takes over.
Flickable {
    id: root
    default property alias content: col.data

    // 0 = nothing shown, 1 = page fully laid. Blocks light up one after
    // another along this progress, at the pace of the wave crossing the
    // background field.
    property real enter: 1

    readonly property bool current: StackLayout.isCurrentItem
    onCurrentChanged: if (root.current) root.playEnter()

    function playEnter(): void { enterAnim.restart(); }

    NumberAnimation {
        id: enterAnim
        target: root
        property: "enter"
        from: 0
        to: 1
        duration: Theme.slow
        easing.type: Easing.OutQuad
    }

    // Without these two lines the page claims no width in a StackLayout
    // and the panel collapses.
    Layout.fillWidth: true
    Layout.fillHeight: true

    contentWidth: width
    contentHeight: col.implicitHeight + Theme.pad * 2
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    ColumnLayout {
        id: col
        width: root.width - Theme.pad * 2
        x: Theme.pad
        y: Theme.pad
        spacing: Theme.px(14)

        // The stagger is set here rather than in each page: blocks are
        // declared by child pages, which need not know about the cascade.
        Component.onCompleted: {
            const n = col.children.length;
            for (let i = 0; i < n; i++) {
                const child = col.children[i];
                const step = () =>
                    Math.max(0, Math.min(1, root.enter * (n + 2) - i));
                child.opacity = Qt.binding(step);
                // And a short lift. Fading alone reads as a page slowly
                // becoming legible; a block that arrives from below reads
                // as one being placed, which is the difference between a
                // transition and a delay.
                child.transform = riseFor(child, step);
            }
        }

        // A translation rather than an animated y: these blocks are placed
        // by the ColumnLayout, and moving y fights the layout and leaves
        // them stacked on top of each other.
        function riseFor(child: var, step: var): var {
            const t = Qt.createQmlObject(
                "import QtQuick; Translate {}", child, "rise");
            t.y = Qt.binding(() => (1 - step()) * Theme.px(14));
            return [t];
        }
    }
}
