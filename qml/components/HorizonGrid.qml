import QtQuick 2.6
import "."

// Synthwave perspective grid rolling toward the viewer. The fan of lines is painted once; the
// horizontal lines are plain rectangles moved by a binding, so nothing is re-rasterised per frame.
Item {
    id: grid
    property color color: "#FF2BD6"
    property real phase: 0
    opacity: 0.35
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = grid.color
            ctx.lineWidth = 1.5
            var cx = width / 2
            for (var i = -12; i <= 12; ++i) {
                ctx.beginPath(); ctx.moveTo(cx, 0); ctx.lineTo(cx + i * width / 6, height); ctx.stroke()
            }
        }
    }
    Repeater {
        model: 9
        Rectangle {
            readonly property real t: (index + grid.phase) / 9
            width: grid.width; height: 1.5
            y: grid.height * t * t
            color: grid.color
            opacity: 0.3 + 0.7 * t
        }
    }
    NumberAnimation on phase {
        from: 0; to: 1; duration: 2600; loops: Animation.Infinite
        running: Qt.application.active && grid.visible && !Game.lowFx
    }
}
