import QtQuick 2.6
import "."

// One neon die showing `face` (1-6).
Rectangle {
    id: die
    property int face: 1
    property color ink: Neon.green
    width: 80; height: width
    radius: width * 0.18
    color: Neon.glassStrong
    border { width: 3; color: die.ink }
    readonly property var layouts: ({ 1: [4], 2: [0, 8], 3: [0, 4, 8], 4: [0, 2, 6, 8], 5: [0, 2, 4, 6, 8], 6: [0, 2, 3, 5, 6, 8] })
    Repeater {
        model: 9
        Rectangle {
            visible: die.layouts[die.face].indexOf(index) >= 0
            width: die.width * 0.17; height: width; radius: width / 2
            x: die.width * (0.2 + 0.3 * (index % 3)) - width / 2 + die.width * 0.0
            y: die.width * (0.2 + 0.3 * Math.floor(index / 3)) - width / 2
            color: "white"
            border { width: 2; color: die.ink }
        }
    }
}
