import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

// Page header: hazard strip, big left-aligned title, a small mono spec line underneath.
Item {
    id: hdr
    property string title
    property string code
    property color color: Neon.pink
    property bool hasInfo: false
    signal infoClicked()
    width: parent ? parent.width : 0
    height: visible ? titleText.height + codeText.height + 2.5 * Theme.paddingLarge : 0

    Rectangle {
        id: strip
        x: Theme.horizontalPageMargin
        anchors { top: titleText.top; bottom: codeText.bottom }
        width: Theme.paddingMedium
        color: "transparent"
        clip: true
        Image {
            anchors.fill: parent
            source: "../images/ui/hazard-" + (Neon.key(hdr.color) === "yellow" ? "yellow" : "pink") + ".png"
            fillMode: Image.Tile
            rotation: 0
        }
    }
    NeonText {
        id: titleText
        anchors { left: strip.right; leftMargin: Theme.paddingMedium }
        y: Theme.paddingLarge * 1.5
        text: hdr.title.toUpperCase()
        color: hdr.color
        // shrink long titles so they never run under the "?" key or off the screen
        font.pixelSize: Math.min(Theme.fontSizeExtraLarge, Math.floor(Theme.fontSizeExtraLarge * titleRoom / Math.max(1, fullTitle.width)))
        glow: 6
    }
    readonly property real titleRoom: hdr.width - Theme.horizontalPageMargin * 2 - Theme.paddingMedium * 2
                                      - (hdr.hasInfo ? infoKey.width + Theme.paddingMedium : 0)
    TextMetrics { id: fullTitle; text: titleText.text; font.family: titleText.font.family; font.bold: titleText.font.bold; font.pixelSize: Theme.fontSizeExtraLarge }
    Text {
        id: codeText
        anchors { left: titleText.left; top: titleText.bottom }
        width: hdr.width - x - Theme.horizontalPageMargin - (hdr.hasInfo ? infoKey.width + Theme.paddingMedium : 0)
        elide: Text.ElideRight
        text: hdr.code
        visible: text !== ""
        height: visible ? implicitHeight : 0
        color: Neon.alpha(hdr.color, 0.75)
        font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall; letterSpacing: 1 }
    }
    NeonButton {
        id: infoKey
        visible: hdr.hasInfo
        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: titleText.verticalCenter }
        width: Theme.itemSizeExtraSmall; height: Theme.itemSizeExtraSmall * 0.8
        text: "?"
        color: hdr.color
        fontSize: Theme.fontSizeLarge
        onClicked: hdr.infoClicked()
    }
}
