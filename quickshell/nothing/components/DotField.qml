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
        property real spacing: Math.max(2, root.step)
        property real radius: root.dotRadius
        property real waveTime: 0
        property real baseAlpha: root.baseAlpha
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
                ctx.globalAlpha = root.baseAlpha;
                ctx.fillStyle = root.dotColor;
                for (let y = root.step / 2; y < height; y += root.step) {
                    for (let x = root.step / 2; x < width; x += root.step) {
                        ctx.beginPath();
                        ctx.arc(x, y, root.dotRadius, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
    }
}
