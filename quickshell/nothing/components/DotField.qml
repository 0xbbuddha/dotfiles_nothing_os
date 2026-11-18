import QtQuick
import ".."

// Background dot field, with a wave on page change.
//
// Rendering goes through a shader: the same field as Rectangles would need
// nearly 3000 objects on the settings sheet. If the shader does not compile
// on the machine, fall back to a static Canvas field, painted once.
Item {
    id: root

    property color dotColor: Theme.c.onFaint
    property real step: Theme.px(14)
    property real dotRadius: Theme.px(1)
    property real baseAlpha: 0.55

    // Manga reads as screentone, not as this house's usual "barely
    // there" ambient texture: tighter, bigger, darker dots, applied
    // here rather than in every one of this field's eight callers, so
    // none of their own tuning has to know this theme exists. A
    // multiplier on each caller's own numbers, not a replacement for
    // them - a field already set sparse for its own reasons stays
    // sparser than one set dense, just both read as denser than before.
    readonly property real effStep: Theme.manga
        ? Math.max(5, root.step * 0.55) : root.step
    readonly property real effDotRadius: Theme.manga
        ? root.dotRadius * 1.35 : root.dotRadius
    readonly property real effBaseAlpha: Theme.manga
        ? Math.min(1, root.baseAlpha * 1.5) : root.baseAlpha

    readonly property bool shaderOk: fx.status !== ShaderEffect.Error

    // Trigger the wave from a point, in local coordinates.
    function ripple(x: real, y: real): void {
        if (!root.shaderOk)
            return;
        fx.waveOrigin = Qt.vector2d(x, y);
        wave.restart();
    }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        visible: root.shaderOk
        fragmentShader: Qt.resolvedUrl("../shaders/dotfield.frag.qsb")

        property color dotColor: root.dotColor
        property vector2d res: Qt.vector2d(Math.max(1, width), Math.max(1, height))
        property vector2d waveOrigin: Qt.vector2d(0, 0)
        property real spacing: Math.max(2, root.effStep)
        property real radius: root.effDotRadius
        property real waveTime: 0
        property real baseAlpha: root.effBaseAlpha
    }

    NumberAnimation {
        id: wave
        target: fx
        property: "waveTime"
        from: 0
        to: 1
        duration: Theme.slow * 2
        easing.type: Easing.OutQuad
    }

    Loader {
        anchors.fill: parent
        active: !root.shaderOk
        sourceComponent: Canvas {
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.globalAlpha = root.effBaseAlpha;
                ctx.fillStyle = root.dotColor;
                for (let y = root.effStep / 2; y < height; y += root.effStep) {
                    for (let x = root.effStep / 2; x < width; x += root.effStep) {
                        ctx.beginPath();
                        ctx.arc(x, y, root.effDotRadius, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
    }
}
