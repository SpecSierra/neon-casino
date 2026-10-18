import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/Roulette.js" as R
import "."

// European wheel with a ball. spinTo(n) animates both and emits landed(n).
Item {
    id: root
    property real wheelAngle: 0
    property real ballAngle: 0
    property real ballRadius: width / 2 - width * 0.04
    property int target: 0
    signal landed(int n)
    property double spinStart: 0
    // the ball rattles over the frets: clacks space out as it slows, the roll fades with it
    Timer {
        id: clacker
        repeat: true
        running: spin.running
        onTriggered: {
            var t = (Date.now() - root.spinStart) / 4200
            if (t > 0.55) Sound.play("clack")
            Sound.ballroll.volume = Math.max(0.05, 0.55 * (1 - t))
            interval = 50 + 330 * t * t
        }
    }

    function spinTo(n) {
        target = n
        var seg = 360 / 37
        var i = R.wheel.indexOf(n)
        var wEnd = wheelAngle + 540 + Math.random() * 360
        var t = wEnd + i * seg
        var bEnd = t - 360 * Math.ceil((t - ballAngle) / 360) - 360 * 4
        wheelAnim.to = wEnd
        ballAnim.to = bEnd
        spinStart = Date.now()
        Sound.loop("ballroll", true, 0.55)
        clacker.interval = 60
        spin.restart()
    }

    Canvas {
        id: face
        anchors.fill: parent
        rotation: root.wheelAngle
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var c = width / 2, r = c - 2, seg = 2 * Math.PI / 37
            ctx.lineWidth = 1.5
            for (var i = 0; i < 37; ++i) {
                var n = R.wheel[i]
                var mid = -Math.PI / 2 + i * seg
                ctx.beginPath()
                ctx.moveTo(c, c)
                ctx.arc(c, c, r, mid - seg / 2, mid + seg / 2, false)
                ctx.closePath()
                var col = R.colorOf(n)
                ctx.fillStyle = col === "red" ? "rgba(255,51,85,0.85)" : col === "green" ? "rgba(57,255,136,0.85)" : "rgba(16,10,40,0.9)"
                ctx.fill()
                ctx.strokeStyle = "rgba(0,240,255,0.7)"
                ctx.stroke()
                ctx.save()
                ctx.translate(c, c)
                ctx.rotate(mid + Math.PI / 2)
                ctx.fillStyle = "white"
                ctx.font = "bold " + Math.round(r * 0.11) + "px sans-serif"
                ctx.textAlign = "center"
                ctx.fillText(String(n), 0, -r * 0.80)
                ctx.restore()
            }
            // inner hub
            ctx.beginPath(); ctx.arc(c, c, r * 0.62, 0, 2 * Math.PI)
            ctx.fillStyle = "rgba(10,6,24,0.92)"; ctx.fill()
            ctx.strokeStyle = "#FF2BD6"; ctx.lineWidth = 3; ctx.stroke()
            ctx.beginPath(); ctx.arc(c, c, r * 0.68, 0, 2 * Math.PI)
            ctx.strokeStyle = "rgba(0,240,255,0.8)"; ctx.lineWidth = 2; ctx.stroke()
            for (var k = 0; k < 8; ++k) {
                var a = k * Math.PI / 4
                ctx.beginPath(); ctx.moveTo(c, c)
                ctx.lineTo(c + Math.cos(a) * r * 0.55, c + Math.sin(a) * r * 0.55)
                ctx.strokeStyle = "rgba(255,43,214,0.6)"; ctx.lineWidth = 2; ctx.stroke()
            }
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.16; height: width; radius: width / 2
        color: Neon.ink
        border { width: 3; color: Neon.cyan }
    }
    Item {
        anchors.fill: parent
        rotation: root.ballAngle
        Rectangle {
            id: ball
            width: root.width * 0.055; height: width; radius: width / 2
            x: (root.width - width) / 2
            y: root.width / 2 - root.ballRadius - height / 2 + root.width * 0.02
            color: "white"
            border { width: 1; color: Neon.cyan }
        }
    }
    SequentialAnimation {
        id: spin
        ParallelAnimation {
            NumberAnimation { id: wheelAnim; target: root; property: "wheelAngle"; duration: 4200; easing.type: Easing.OutCubic }
            NumberAnimation { id: ballAnim; target: root; property: "ballAngle"; duration: 4200; easing.type: Easing.OutQuart }
            SequentialAnimation {
                PauseAnimation { duration: 2400 }
                NumberAnimation { target: root; property: "ballRadius"; to: root.width * 0.36; duration: 1200; easing.type: Easing.OutBounce }
            }
        }
        ScriptAction {
            script: {
                Sound.loop("ballroll", false)
                Sound.play("pocket")
                root.wheelAngle = root.wheelAngle % 360
                root.ballAngle = root.ballAngle % 360
                root.landed(root.target)
            }
        }
    }
    function resetBall() { ballRadius = width / 2 - width * 0.04 }
}
