import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

Rectangle {
    property var perk
    width: t.implicitWidth + 2 * Theme.paddingMedium
    height: t.implicitHeight + Theme.paddingSmall
    radius: height / 2
    color: Neon.alpha(perk.color, 0.15)
    border { width: 1; color: perk.color }
    Text {
        id: t
        anchors.centerIn: parent
        text: perk.name.toUpperCase()
        color: Qt.lighter(perk.color, 1.2)
        font { pixelSize: Theme.fontSizeTiny; bold: true; letterSpacing: 1; family: Neon.display }
    }
}
