import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

// A 0..1 slider in the app's style: label + value on top, a segmented bar you drag or tap.
Item {
    id: slider
    property string label
    property real value: 0.5
    property color color: Neon.cyan
    signal moved(real value)
    width: parent ? parent.width : 0
    height: head.height + bar.height + Theme.paddingSmall
    Item {
        id: head
        x: Theme.horizontalPageMargin; width: parent.width - 2 * x
        height: lab.height
        Text { id: lab; text: slider.label; color: "white"; font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeSmall } }
        Text { anchors.right: parent.right; text: Math.round(slider.value * 100) + "%"; color: slider.color; font { family: Neon.mono; pixelSize: Theme.fontSizeSmall } }
    }
    Row {
        id: bar
        anchors { top: head.bottom; topMargin: Theme.paddingSmall }
        x: Theme.horizontalPageMargin
        spacing: 3
        readonly property int n: 20
        Repeater {
            model: bar.n
            Rectangle {
                width: (slider.width - 2 * Theme.horizontalPageMargin - (bar.n - 1) * 3) / bar.n
                height: Theme.paddingLarge * (0.8 + 0.6 * index / bar.n)
                anchors.bottom: parent.bottom
                color: (index + 0.5) / bar.n <= slider.value ? slider.color : Neon.alpha(slider.color, 0.18)
            }
        }
    }
    MouseArea {
        anchors { fill: bar; topMargin: -Theme.paddingLarge; bottomMargin: -Theme.paddingLarge }
        preventStealing: true
        function set(mx) {
            var v = Math.max(0, Math.min(1, Math.round(mx / bar.width * 20) / 20))
            if (v !== slider.value) { slider.moved(v); Haptics.tick() }
        }
        onPressed: set(mouse.x)
        onPositionChanged: set(mouse.x)
    }
}
