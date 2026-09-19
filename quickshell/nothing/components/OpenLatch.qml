import QtQuick

// Flips once and stays flipped. A panel bound to Config/GlobalState only
// needs building the first time it is actually opened; closing it again
// should not tear the tree down; so LazyLoader.active wants "has this
// ever been true", not "is this true right now".
QtObject {
    property bool open: false
    property bool touched: false

    onOpenChanged: if (open) touched = true
}
