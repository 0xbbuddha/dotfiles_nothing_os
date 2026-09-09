import QtQuick
import ".."

// Public tile for an Essential App. Size and face live on Widget;
// chrome is the hover edit / drop pair used on the desktop.
Widget {
    id: root
    property bool chrome: false
    property bool closable: true
    property bool flat: false
    tools: root.chrome && root.closable
}
