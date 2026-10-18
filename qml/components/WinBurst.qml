import QtQuick 2.6
import QtQuick.Particles 2.0
import Sailfish.Silica 1.0
import "../js/Money.js" as Money
import "."

// Win celebration: counting "+¤X", shockwave rings, spark fountain, and for big wins a
// screen shake of `shakeTarget`. call show(amount, big)
Item {
    id: burst
    anchors.fill: parent
    z: 50
    property Item shakeTarget
    property real amount: 0
    property real shown: 0
    property color tint: Neon.green

    function show(v, big) {
        amount = v
        tint = big ? Neon.yellow : Neon.green
        countUp.duration = big ? 1400 : 600
        shown = 0
        countUp.restart()
        emitter.burst(Game.lowFx ? (big ? 90 : 30) : (big ? 320 : 110))     // light mode: a third of the sparks
        if (big) { rain.enabled = !Game.lowFx; rainStop.restart(); shake.restart() }
        ring1.go(); if (big) ring2.go()
        pop.restart()
        Sound.play(big ? "bigwin" : "win")
        Haptics.win(big)
    }

    NumberAnimation { id: countUp; target: burst; property: "shown"; to: burst.amount; easing.type: Easing.OutCubic }

    // shockwave rings
    Rectangle {
        id: ring1
        anchors.centerIn: parent
        width: 10; height: width; radius: width / 2
        color: "transparent"; border { width: 6; color: burst.tint }
        opacity: 0
        function go() { ringAnim1.restart() }
        ParallelAnimation {
            id: ringAnim1
            NumberAnimation { target: ring1; property: "width"; from: 20; to: burst.width * 1.3; duration: 700; easing.type: Easing.OutCubic }
            NumberAnimation { target: ring1; property: "opacity"; from: 0.9; to: 0; duration: 700 }
        }
    }
    Rectangle {
        id: ring2
        anchors.centerIn: parent
        width: 10; height: width; radius: width / 2
        color: "transparent"; border { width: 4; color: Neon.pink }
        opacity: 0
        function go() { ringAnim2.restart() }
        SequentialAnimation {
            id: ringAnim2
            PauseAnimation { duration: 180 }
            ParallelAnimation {
                NumberAnimation { target: ring2; property: "width"; from: 20; to: burst.width * 1.6; duration: 900; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring2; property: "opacity"; from: 0.8; to: 0; duration: 900 }
            }
        }
    }

    ParticleSystem { id: sys; running: Qt.application.active }
    ImageParticle {
        system: sys
        source: "../images/spark.png"
        color: Neon.pink
        colorVariation: 0.6
        alpha: 0.9
        rotationVariation: 180
        entryEffect: ImageParticle.Scale
    }
    Emitter {
        id: emitter
        system: sys
        anchors.centerIn: parent
        width: 40; height: 40
        enabled: false
        lifeSpan: 1200; lifeSpanVariation: 400
        size: Theme.paddingLarge; sizeVariation: Theme.paddingMedium; endSize: 2
        velocity: AngleDirection { angle: 270; angleVariation: 180; magnitude: burst.width * 0.9; magnitudeVariation: burst.width * 0.5 }
        acceleration: PointDirection { y: burst.width * 1.1 }
    }
    // gold rain across the top for big wins
    Emitter {
        id: rain
        system: sys
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        enabled: false
        emitRate: 120
        lifeSpan: 1800
        size: Theme.paddingMedium * 1.5; sizeVariation: Theme.paddingSmall; endSize: 4
        velocity: PointDirection { y: burst.height * 0.45; yVariation: burst.height * 0.2; xVariation: 40 }
    }
    Timer { id: rainStop; interval: 1300; onTriggered: rain.enabled = false }

    NeonText {
        id: label
        anchors.centerIn: parent
        text: "+" + Money.fmt(burst.shown)
        color: burst.tint
        font.pixelSize: Theme.fontSizeHuge
        glow: 14
        opacity: 0
    }
    SequentialAnimation {
        id: pop
        ParallelAnimation {
            NumberAnimation { target: label; property: "opacity"; from: 0; to: 1; duration: 150 }
            NumberAnimation { target: label; property: "scale"; from: 0.3; to: 1.15; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }
        NumberAnimation { target: label; property: "scale"; to: 1; duration: 200 }
        PauseAnimation { duration: countUp.duration }
        ParallelAnimation {
            NumberAnimation { target: label; property: "opacity"; to: 0; duration: 450 }
            NumberAnimation { target: label; property: "anchors.verticalCenterOffset"; from: 0; to: -Theme.itemSizeLarge; duration: 450; easing.type: Easing.InCubic }
        }
        PropertyAction { target: label; property: "anchors.verticalCenterOffset"; value: 0 }
    }
    // screen shake (big wins)
    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeT; property: "x"; to: 14; duration: 40 }
        NumberAnimation { target: shakeT; property: "x"; to: -12; duration: 60 }
        NumberAnimation { target: shakeT; property: "x"; to: 9; duration: 60 }
        NumberAnimation { target: shakeT; property: "x"; to: -6; duration: 60 }
        NumberAnimation { target: shakeT; property: "x"; to: 3; duration: 60 }
        NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
    }
    Translate { id: shakeT }
    Component.onCompleted: if (shakeTarget) shakeTarget.transform = shakeT
}
