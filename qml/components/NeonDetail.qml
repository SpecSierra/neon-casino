import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

// Label / value row in the app's fonts (Silica's DetailItem would show amounts in the system font).
Item {
    property string label
    property string value
    width: parent ? parent.width : 0
    height: Math.max(l.height, v.height) + Theme.paddingSmall
    Text {
        id: l
        anchors { right: parent.horizontalCenter; rightMargin: Theme.paddingMedium }
        width: parent.width / 2 - Theme.horizontalPageMargin - Theme.paddingMedium
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        text: parent.label
        color: Theme.secondaryColor
        font { family: Neon.display; pixelSize: Theme.fontSizeSmall }
    }
    Text {
        id: v
        anchors { left: parent.horizontalCenter; leftMargin: Theme.paddingMedium }
        width: parent.width / 2 - Theme.horizontalPageMargin - Theme.paddingMedium
        wrapMode: Text.Wrap
        text: parent.value
        color: "white"
        font { family: Neon.mono; pixelSize: Theme.fontSizeSmall }
    }
}
