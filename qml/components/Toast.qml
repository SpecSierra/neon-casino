import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

// Small perk-trigger notice that slides in under the HUD.
NeonPanel {
    id: toast
    property alias text: label.text
    width: label.implicitWidth + 2 * Theme.paddingLarge
    height: Theme.itemSizeExtraSmall
    opacity: 0
    strong: true
    z: 40
    function show(t, c) { label.text = t; toast.glowColor = c; anim.restart() }
    Text {
        id: label
        anchors.centerIn: parent
        color: Qt.lighter(toast.glowColor, 1.3)
        font { pixelSize: Theme.fontSizeSmall; bold: true; letterSpacing: 2; family: Neon.display }
    }
    SequentialAnimation {
        id: anim
        NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 150 }
        PauseAnimation { duration: 1600 }
        NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 400 }
    }
}
