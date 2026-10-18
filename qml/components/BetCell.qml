import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/Roulette.js" as R
import "."

// One spot on the roulette board. Looks up its stake in the page's `bets` map.
MouseArea {
    id: cell
    property string key
    property string label
    property color tint: Neon.cyan
    property bool small: false
    property var table      // the RoulettePage
    readonly property real amount: table.bets[key] || 0
    readonly property bool won: table.flashN >= 0 && R.covers(key, table.flashN)
    onClicked: table.place(key)
    onPressAndHold: table.removeBet(key)

    Rectangle {
        anchors.fill: parent
        radius: 2
        color: Neon.alpha(cell.tint, cell.pressed ? 0.5 : (cell.amount > 0 ? 0.32 : 0.14))
        border { width: 1; color: Neon.alpha(cell.tint, 0.8) }
    }
    Rectangle {
        anchors.fill: parent
        radius: 2
        visible: cell.won
        color: Neon.alpha(Neon.yellow, 0.35)
        border { width: 3; color: Neon.yellow }
        SequentialAnimation on opacity {
            running: cell.won; loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.2; duration: 300 }
            NumberAnimation { from: 0.2; to: 1; duration: 300 }
        }
    }
    Text {
        anchors.centerIn: parent
        text: cell.label
        color: "white"
        font { pixelSize: Math.min(cell.small ? Theme.fontSizeExtraSmall : Theme.fontSizeSmall, cell.height * 0.55); bold: true; family: Neon.display }
    }
    Rectangle {
        visible: cell.amount > 0
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 4 }
        height: parent.height * 0.7; width: Math.max(height, chipText.implicitWidth + 8); radius: height / 2
        color: Neon.yellow
        Text {
            id: chipText
            anchors.centerIn: parent
            text: table.chipLabel(cell.amount)
            color: Neon.ink
            font { pixelSize: Theme.fontSizeTiny; bold: true }
        }
    }
}
