import QtQuick
import ".."

// Manga speed lines, radiating from a corner. A Canvas, painted once
// and cached like any other Canvas in this shell (DialFace's hands,
// DotField's own fallback) - no shader, nothing per-frame, nothing 3D.
// The lengths and weights vary a little so the fan reads as drawn
// rather than plotted, but the variation is index-based, not
// Math.random: the same instance repaints identically every time.
Canvas {
    id: root

    property color lineColor: Theme.c.on
    // In local coordinates; default is the top-right corner.
    property point origin: Qt.point(width, 0)
    property int lineCount: 14
    property real minLen: 0.28   // shortest line, as a fraction of the diagonal
    property real maxLen: 0.92
    property real thickness: 1.3
    property real spreadDeg: 75   // how wide an arc the fan covers
    property real startDeg: 180   // fan direction: 0 = right, 90 = down, 180 = left

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (width <= 0 || height <= 0 || root.lineCount <= 0)
            return;

        const diag = Math.sqrt(width * width + height * height);
        const startRad = root.startDeg * Math.PI / 180;
        const spreadRad = root.spreadDeg * Math.PI / 180;
        ctx.strokeStyle = root.lineColor;
        ctx.lineCap = "round";

        for (let i = 0; i < root.lineCount; i++) {
            const t = root.lineCount === 1 ? 0.5 : i / (root.lineCount - 1);
            const angle = startRad - spreadRad / 2 + spreadRad * t;
            const lenFrac = root.minLen
                + (root.maxLen - root.minLen) * ((i * 37) % 11) / 10;
            const len = diag * lenFrac;
            const x2 = root.origin.x + Math.cos(angle) * len;
            const y2 = root.origin.y + Math.sin(angle) * len;

            ctx.lineWidth = root.thickness * (0.55 + 0.45 * ((i * 53) % 7) / 6);
            ctx.beginPath();
            ctx.moveTo(root.origin.x, root.origin.y);
            ctx.lineTo(x2, y2);
            ctx.stroke();
        }
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onOriginChanged: requestPaint()
    Component.onCompleted: requestPaint()
}
