import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

// A betting spot for chip tables (Sic Bo): tap to add the page's chip, hold to clear.
// Expects `page.bets`, `page.place(key)`, `page.clearSpot(key)`, `page.chipLabel(v)` on the table.
MouseArea {
    id: cell
    property string key
    property string label
    property string sub
    property color tint: Neon.cyan
    readonly property real amount: page.bets[key] || 0
    onClicked: page.place(key)
    onPressAndHold: page.clearSpot(key)
    Rectangle {
        anchors.fill: parent
        color: Neon.alpha(cell.tint, cell.pressed ? 0.45 : (cell.amount > 0 ? 0.3 : 0.1))
        border { width: 1; color: Neon.alpha(cell.tint, 0.8) }
    }
    Column {
        anchors.centerIn: parent
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: cell.label !== ""
            text: cell.label; color: "white"
            font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeSmall }
        }
        Item { width: 1; height: cell.label === "" ? cell.height * 0.55 : 0 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: cell.sub; color: Neon.alpha(cell.tint, 0.95)
            font { family: Neon.mono; pixelSize: Theme.fontSizeTiny * 0.85 }
        }
    }
    Rectangle {
        visible: cell.amount > 0
        anchors { right: parent.right; top: parent.top; margins: 2 }
        height: Theme.iconSizeSmall * 0.8; width: Math.max(height, t.implicitWidth + 8); radius: height / 2
        color: Neon.yellow
        Text { id: t; anchors.centerIn: parent; text: page.chipLabel(cell.amount); color: Neon.ink; font { pixelSize: Theme.fontSizeTiny; bold: true } }
    }
}
