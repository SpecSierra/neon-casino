import QtQuick 2.6
import QtQuick.Window 2.2
import Sailfish.Silica 1.0
import "."

// One playing card. Flips when faceUp changes; slides in when created.
Item {
    id: card
    property string rank
    property string suit
    property bool faceUp: true
    property bool animateIn: true
    readonly property bool red: suit === "hearts" || suit === "diamonds"
    readonly property color ink: red ? Neon.pink : Neon.cyan
    width: Theme.itemSizeLarge * 0.95
    height: width * 1.42

    transform: [ Translate { id: fly }, Rotation {
        id: flip
        origin.x: card.width / 2; origin.y: card.height / 2
        axis { x: 0; y: 1; z: 0 }
        angle: card.faceUp ? 0 : 180
        Behavior on angle { NumberAnimation { duration: 320; easing.type: Easing.InOutQuad } }
    } ]
    readonly property bool showFront: flip.angle < 90

    NeonPanel {
        anchors.fill: parent
        glowColor: card.showFront ? card.ink : Neon.violet
        glowStrength: 0.5
        strong: true
        radius: 8
    }
    // front
    Item {
        anchors.fill: parent
        visible: card.showFront
        Text {
            x: Theme.paddingSmall; y: Theme.paddingSmall / 2
            text: card.rank; color: Qt.lighter(card.ink, 1.3)
            font { pixelSize: Theme.fontSizeLarge; bold: true; family: Neon.display }
        }
        Image {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.paddingSmall }
            width: parent.width * 0.7; height: width
            source: card.suit ? "../images/suit-" + card.suit + ".png" : ""
            smooth: true
        }
    }
    // back
    Item {
        anchors.fill: parent
        visible: !card.showFront
        Rectangle {
            anchors { fill: parent; margins: Theme.paddingSmall }
            radius: 4
            color: Neon.alpha(Neon.violet, 0.25)
            border { width: 1; color: Neon.pink }
            Image {
                anchors { fill: parent; margins: 2 }
                source: "../images/hex.png"; fillMode: Image.Tile; opacity: 0.5
            }
            Image {
                anchors.centerIn: parent
                width: parent.width * 0.6; height: width
                source: "../images/sym-chip.png"
            }
        }
    }

    Component.onCompleted: if (animateIn) { enter.start(); Sound.play("card") }
    ParallelAnimation {
        id: enter
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 160 }
        NumberAnimation { target: fly; property: "x"; from: Screen.width * 0.6; to: 0; duration: 380; easing.type: Easing.OutCubic }
        NumberAnimation { target: fly; property: "y"; from: -Screen.height * 0.25; to: 0; duration: 380; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "rotation"; from: -40; to: 0; duration: 420; easing.type: Easing.OutBack }
        NumberAnimation { target: card; property: "scale"; from: 0.7; to: 1; duration: 380; easing.type: Easing.OutBack }
    }
}
