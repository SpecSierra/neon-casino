import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

// Display text with a chromatic split: magenta and cyan ghosts offset either side, like a
// misregistered print. (Replaces the old shader glow: sharper and cheaper.)
Item {
    id: root
    property alias text: label.text
    property alias font: label.font
    property alias horizontalAlignment: label.horizontalAlignment
    property color color: Neon.cyan
    property real glow: 8                 // sets how far the ghosts drift
    readonly property real split: Math.max(1, glow / 5) * Math.max(0.5, Theme.pixelRatio || 1) / 2 + 0.5
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Text {
        x: -root.split; y: 0
        width: parent.width; height: parent.height
        text: label.text; font: label.font; horizontalAlignment: label.horizontalAlignment
        color: Neon.pink; opacity: 0.55
        visible: !Game.lowFx
    }
    Text {
        x: root.split; y: 0
        width: parent.width; height: parent.height
        text: label.text; font: label.font; horizontalAlignment: label.horizontalAlignment
        color: Neon.cyan; opacity: 0.55
        visible: !Game.lowFx
    }
    Text {
        id: label
        anchors.fill: parent
        color: Qt.lighter(root.color, 1.15)
        font.family: Neon.display
        font.pixelSize: Theme.fontSizeLarge
        font.bold: true
        font.letterSpacing: 1
    }
}
