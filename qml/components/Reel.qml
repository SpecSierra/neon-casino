import QtQuick 2.6
import "../js/Slots.js" as Slots
import "."

// One slot reel: 3 visible cells. spin() scrolls a strip of random symbols down
// and lands on the given final column.
Item {
    id: reel
    property real cell: width
    property var strip: theme ? theme.symbols.slice(0, 3) : []
    property bool wildOn: false
    property bool bonusOn: false
    property var theme
    property var lit: []                 // rows on a winning line: pulse them
    readonly property bool spinning: anim.running
    signal stopped()
    height: cell * 3
    clip: true

    function spin(finals, duration) {
        lit = []
        var s = finals.slice()
        var n = 14 + Math.floor(duration / 80)
        for (var i = 0; i < n; ++i) s.push(Slots.pick(theme, wildOn, bonusOn))
        s = s.concat(strip.slice(0, 3))
        strip = s
        col.y = -(s.length - 3) * cell
        anim.duration = duration
        anim.restart()
    }

    Column {
        id: col
        width: reel.width
        Repeater {
            model: reel.strip
            Item {
                id: cellItem
                width: reel.width; height: reel.cell
                readonly property bool hot: !reel.spinning && reel.lit.indexOf(index) >= 0
                Rectangle {
                    anchors { fill: parent; margins: 3 }
                    radius: 6
                    color: Qt.rgba(1, 0.17, 0.84, 0.18)
                    border { width: 2; color: "#F8FF3A" }
                    visible: cellItem.hot
                    SequentialAnimation on opacity {
                        running: cellItem.hot; loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.35; duration: 380 }
                        NumberAnimation { from: 0.35; to: 1; duration: 380 }
                    }
                }
                Image {
                    id: symImg
                    anchors { fill: parent; margins: reel.cell * 0.08 }
                    source: reel.theme ? Slots.image(reel.theme, modelData) : ""
                    smooth: true
                    // motion blur feel: stretch + fade while the strip flies by
                    opacity: reel.spinning ? 0.75 : 1
                    transform: Scale { origin.y: symImg.height / 2; yScale: reel.spinning ? 1.25 : 1 }
                    SequentialAnimation on scale {
                        running: cellItem.hot; loops: Animation.Infinite
                        NumberAnimation { to: 1.18; duration: 380; easing.type: Easing.OutQuad }
                        NumberAnimation { to: 1.0; duration: 380; easing.type: Easing.InQuad }
                    }
                    SequentialAnimation on rotation {
                        running: cellItem.hot; loops: Animation.Infinite
                        NumberAnimation { to: 6; duration: 190 } NumberAnimation { to: -6; duration: 380 } NumberAnimation { to: 0; duration: 190 }
                    }
                }
            }
        }
    }
    // stop now: jump to the final symbols (the result is decided before the spin)
    function slam() {
        if (!anim.running) return
        anim.stop()
        col.y = 0
        reel.strip = reel.strip.slice(0, 3)
        thump.restart()
        Haptics.tick()
        Sound.play("tick")
        reel.stopped()
    }
    NumberAnimation {
        id: anim
        target: col; property: "y"; to: 0
        easing.type: Easing.OutBack; easing.overshoot: 0.9
        onStopped: {
            if (col.y !== 0) return          // slam() already finished this spin
            reel.strip = reel.strip.slice(0, 3)
            thump.restart()
            Haptics.tick()
            reel.stopped()
        }
    }
    SequentialAnimation {
        id: thump
        NumberAnimation { target: col; property: "scale"; to: 0.96; duration: 60 }
        NumberAnimation { target: col; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutBack }
    }
    // glass shading top & bottom
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: reel.cell * 0.6
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0.02, 0, 0.06, 0.85) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: reel.cell * 0.6
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0.02, 0, 0.06, 0.85) }
        }
    }
}
