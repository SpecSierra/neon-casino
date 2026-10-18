import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

// An on/off row: label and description on the left, a lit switch on the right.
MouseArea {
    id: t
    property string label
    property string description
    property bool checked: false
    property color color: Neon.cyan
    signal toggled(bool checked)
    width: parent ? parent.width : 0
    height: Math.max(col.height, Theme.itemSizeSmall) + Theme.paddingMedium
    onClicked: { t.toggled(!t.checked); Sound.play("click"); Haptics.tick() }
    Column {
        id: col
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x - sw.width - Theme.paddingLarge
        anchors.verticalCenter: parent.verticalCenter
        Text { width: parent.width; text: t.label; color: "white"; wrapMode: Text.Wrap; font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeSmall } }
        Text { width: parent.width; visible: text !== ""; text: t.description; color: Theme.secondaryColor; wrapMode: Text.Wrap; font.pixelSize: Theme.fontSizeExtraSmall }
    }
    Rectangle {
        id: sw
        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
        width: Theme.itemSizeSmall * 1.2; height: Theme.itemSizeSmall * 0.5
        radius: height / 2
        color: t.checked ? Neon.alpha(t.color, 0.45) : Neon.alpha("white", 0.08)
        border { width: 2; color: t.checked ? t.color : Neon.alpha("white", 0.3) }
        Rectangle {
            width: parent.height - 8; height: width; radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: t.checked ? parent.width - width - 4 : 4
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
            color: t.checked ? "white" : Neon.alpha("white", 0.5)
        }
    }
}
