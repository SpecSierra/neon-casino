import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

// One-armed-bandit lever: drag the knob down and let go to spin.
// pulled(power) fires on release when pulled past 70%; power is 0..1 (pull depth + speed).
Item {
    id: lever
    property color color: Neon.red
    property bool armed: true
    signal pulled(real power)
    width: Theme.itemSizeExtraSmall * 0.75

    readonly property real knobSize: width * 0.9
    readonly property real trackTop: knobSize / 2
    readonly property real travel: height - knobSize
    property real pull: 0                       // 0 = up, 1 = fully down
    property real lastY: 0
    property real lastT: 0
    property real speed: 0

    // slot the stick runs in
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: lever.trackTop; width: 6; height: lever.travel; radius: 3
        color: Neon.alpha(lever.color, 0.18)
        border { width: 1; color: Neon.alpha(lever.color, 0.5) }
    }
    // stick from the pivot (bottom) to the knob
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: knob.y + knob.height / 2
        width: 8; radius: 4
        height: lever.height - y - Theme.paddingSmall
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(lever.color, 1.4) }
            GradientStop { position: 1; color: Neon.alpha(lever.color, 0.3) }
        }
    }
    Rectangle {          // pivot housing
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        width: lever.width * 0.8; height: width * 0.6; radius: 4
        color: Neon.glassStrong
        border { width: 2; color: lever.color }
    }
    Rectangle {
        id: knob
        width: lever.knobSize; height: width; radius: width / 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: lever.pull * lever.travel
        color: Neon.alpha(lever.color, drag.pressed ? 0.9 : 0.65)
        border { width: 2; color: Qt.lighter(lever.color, 1.5) }
        Rectangle {        // highlight
            x: parent.width * 0.22; y: parent.height * 0.18
            width: parent.width * 0.3; height: width; radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.55)
        }
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        enabled: lever.armed
        preventStealing: true
        property real grabOffset: 0
        onPressed: {
            springBack.stop()
            grabOffset = mouse.y - knob.y
            lever.lastY = mouse.y; lever.lastT = Date.now(); lever.speed = 0
        }
        onPositionChanged: {
            var p = Math.max(0, Math.min(1, (mouse.y - grabOffset) / lever.travel))
            var now = Date.now()
            if (now > lever.lastT) lever.speed = (mouse.y - lever.lastY) / (now - lever.lastT)   // px/ms
            lever.lastY = mouse.y; lever.lastT = now
            if (p >= 0.98 && lever.pull < 0.98) Sound.play("tick")
            lever.pull = p
        }
        onReleased: {
            if (lever.pull > 0.7) {
                var power = Math.min(1, 0.5 * lever.pull + 0.5 * Math.min(1, lever.speed / 3))
                lever.pulled(power)
            }
            springBack.restart()
        }
        onCanceled: springBack.restart()
    }
    SpringAnimation { id: springBack; target: lever; property: "pull"; to: 0; spring: 4; damping: 0.18; epsilon: 0.005 }
    opacity: armed ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: 200 } }
}
