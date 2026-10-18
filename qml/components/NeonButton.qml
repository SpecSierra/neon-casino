import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

// Cut-corner button. Primary = solid accent with ink text; secondary = outline. Pressing
// shifts it down-right like a physical key.
MouseArea {
    id: button
    property alias text: label.text
    property color color: Neon.cyan
    property bool primary: false
    property real fontSize: Theme.fontSizeMedium
    readonly property string key: Neon.key(color)
    readonly property real k: Math.max(0.5, Theme.pixelRatio || 1) / 2
    implicitWidth: label.implicitWidth + 2 * Theme.paddingLarge
    implicitHeight: Theme.itemSizeSmall
    opacity: enabled ? 1 : 0.32

    Item {
        id: face
        width: parent.width; height: parent.height
        x: button.pressed ? 3 : 0; y: button.pressed ? 3 : 0
        BorderImage {
            width: face.width / button.k; height: face.height / button.k
            scale: button.k; transformOrigin: Item.TopLeft
            source: "../images/ui/btn-" + button.key + (button.primary || button.pressed ? "-solid" : "-line") + ".png"
            border { left: 30; right: 30; top: 30; bottom: 30 }
        }
        Text {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, face.width - Theme.paddingMedium)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: button.primary || button.pressed ? Neon.ink : Qt.lighter(button.color, 1.2)
            font.family: Neon.display
            font.pixelSize: button.fontSize
            font.bold: true
            font.letterSpacing: 1
            font.capitalization: Font.AllUppercase
        }
    }
    onClicked: Sound.play("click")
}
