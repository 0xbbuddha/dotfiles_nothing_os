import QtQuick
import QtQuick.Layouts
import ".."

// used / free / total row under a gauge, like ii's resources popup.
Text {
    Layout.fillWidth: true
    Layout.leftMargin: Theme.px(63)
    color: Theme.c.onDim
    font.family: Theme.f.mono
    font.pixelSize: Theme.f.micro
    font.letterSpacing: 0.2
    elide: Text.ElideRight
}
