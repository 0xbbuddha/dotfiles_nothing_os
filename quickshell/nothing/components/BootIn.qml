import QtQuick
import ".."

// Fades a single item in once, on the frame it is first created rather
// than on some later state change - the moment a shell surface maps for
// the first time in a session, which nothing else here has a hook for.
//
// A single item, not a list: Flow and Row already have a `populate`
// transition built in for a repeated set, and duplicating that here
// would just be a second way to do the same thing.
SequentialAnimation {
    id: root
    required property Item target
    property int delay: 0

    running: true
    PauseAnimation { duration: root.delay }
    NumberAnimation {
        target: root.target
        property: "opacity"
        from: 0
        to: 1
        duration: Theme.slow
        easing.type: Theme.ease
    }
}
