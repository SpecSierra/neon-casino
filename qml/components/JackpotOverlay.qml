import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/Money.js" as Money
import "."

// Full-screen jackpot celebration: the tier name slams in, the amount counts up, then it
// fades after a few seconds (tap to dismiss). The money is already credited by Game.stake().
Item {
    id: jp
    anchors.fill: parent
    z: 80
    visible: opacity > 0
    opacity: 0
    property string name: ""
    property real amount: 0
    property real shown: 0
    property color tint: name === "GRAND" ? Neon.red : name === "MAJOR" ? Neon.yellow : Neon.cyan

    function show(n, a) {
        name = n; amount = a; shown = 0
        anim.restart()
        Sound.play("bigwin"); Haptics.rumble(n === "GRAND" ? 14 : n === "MAJOR" ? 9 : 5)
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0.02, 0, 0.06, 0.88) }
    Repeater {          // light rays
        model: 12
        Rectangle {
            anchors.centerIn: parent
            width: jp.width * 2.2; height: Theme.paddingLarge * 2
            rotation: index * 15 + rays.angle
            color: Neon.alpha(jp.tint, 0.08)
        }
    }
    QtObject { id: rays; property real angle: 0 }
    NumberAnimation { target: rays; property: "angle"; from: 0; to: 180; duration: 9000; loops: Animation.Infinite; running: jp.visible }
    Column {
        anchors.centerIn: parent
        spacing: Theme.paddingLarge
        NeonText {
            id: title
            anchors.horizontalCenter: parent.horizontalCenter
            text: jp.name
            color: jp.tint
            font.pixelSize: Theme.fontSizeHuge * 1.6
            glow: 24
        }
        NeonText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "JACKPOT"
            color: "white"
            font.pixelSize: Theme.fontSizeExtraLarge
            glow: 12
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "+" + Money.fmt(jp.shown)
            color: Neon.yellow
            font { family: Neon.mono; pixelSize: Theme.fontSizeHuge }
        }
    }
    SequentialAnimation {
        id: anim
        NumberAnimation { target: jp; property: "opacity"; to: 1; duration: 200 }
        ParallelAnimation {
            NumberAnimation { target: title; property: "scale"; from: 3; to: 1; duration: 500; easing.type: Easing.OutBack }
            NumberAnimation { target: jp; property: "shown"; to: jp.amount; duration: 2200; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 2600 }
        NumberAnimation { target: jp; property: "opacity"; to: 0; duration: 500 }
    }
    MouseArea { anchors.fill: parent; enabled: jp.visible; onClicked: { anim.stop(); jp.opacity = 0 } }
}
