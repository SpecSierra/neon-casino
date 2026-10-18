import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/Roulette.js" as R
import "."

// An inside bet on the roulette board: a small target centred on a line between numbers
// (split / corner) or on the board's left edge (street / six line). Tap to add a chip,
// long-press to take it back. Shows a faint dot until it holds a chip.
MouseArea {
    id: spot
    property string key
    property var table
    property real size: Theme.paddingLarge * 1.6
    readonly property real amount: table.bets[key] || 0
    readonly property bool won: table.flashN >= 0 && R.covers(key, table.flashN)
    width: size; height: size
    z: 2
    onClicked: { table.place(key); if (!table.busy) Game.note(R.multiName(key), Neon.yellow) }
    onPressAndHold: table.removeBet(key)
    Rectangle {          // the hint dot
        anchors.centerIn: parent
        width: 6; height: 6; radius: 3
        color: Neon.alpha("white", spot.pressed ? 0.9 : 0.35)
        visible: spot.amount === 0
    }
    Rectangle {          // the chip
        anchors.centerIn: parent
        visible: spot.amount > 0
        width: Math.max(spot.size * 0.9, label.implicitWidth + 8); height: spot.size * 0.9; radius: height / 2
        color: spot.won ? Neon.green : Neon.yellow
        border { width: 2; color: Neon.ink }
        Text {
            id: label
            anchors.centerIn: parent
            text: spot.table.chipLabel(spot.amount)
            color: Neon.ink
            font { pixelSize: Theme.fontSizeTiny; bold: true }
        }
        SequentialAnimation on scale {
            running: spot.won; loops: Animation.Infinite
            NumberAnimation { to: 1.25; duration: 300 } NumberAnimation { to: 1; duration: 300 }
        }
    }
}
