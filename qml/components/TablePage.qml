import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

// Common frame for the three tables: backdrop, HUD, toasts, win burst, and a
// footer area that stays put while the table scrolls.
Page {
    id: page
    property string title
    property color accent: Neon.pink
    default property alias content: column.data
    property alias footer: footerItem.data
    property real footerHeight: 0
    property alias flickable: flick
    property alias burst: winBurst
    property bool busy: false   // a round is in play: no leaving mid-hand
    property bool showHeader: true
    property string code                    // the spec line under the title
    property string info                    // rules and pays, shown on the "?" sheet instead of on the table
    readonly property bool isTable: true
    property string musicTrack: "lobby"
    property string scene: "lobby"          // Backdrop scene for this table
    onStatusChanged: if (status === PageStatus.Active) Music.track = musicTrack
    onMusicTrackChanged: if (status === PageStatus.Active) Music.track = musicTrack
    // while the rules sheet is open the back swipe is blocked: Close (or a tap) shuts the sheet
    // instead of dropping you out of the game
    backNavigation: !busy && !infoSheet.shown

    Backdrop { accent: page.accent; scene: page.scene }

    SilicaFlickable {
        id: flick
        anchors { fill: parent; bottomMargin: page.footerHeight }
        contentHeight: column.height + Theme.paddingLarge
        interactive: contentHeight > height + 1     // tables are laid out to fit; scroll only as a fallback
        clip: true
        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium
            NeonHeader {
                title: page.title; code: page.code; color: page.accent; visible: page.showHeader
                hasInfo: page.info !== ""
                onInfoClicked: infoSheet.shown = true
            }
            Item { width: 1; height: Theme.paddingSmall; visible: !page.showHeader }
            Hud { x: Theme.horizontalPageMargin; width: parent.width - 2 * x }
        }
        VerticalScrollDecorator {}
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: page.footerHeight + Theme.paddingLarge
        visible: page.footerHeight > 0
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.15; color: Qt.rgba(0.03, 0.0, 0.09, 0.82) }
            GradientStop { position: 1; color: Qt.rgba(0.03, 0.0, 0.09, 0.9) }
        }
        Rectangle { width: parent.width; height: 1; y: parent.height * 0.12; color: Neon.alpha(page.accent, 0.6) }
    }
    Item {
        id: footerItem
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: page.footerHeight
    }
    Toast {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.itemSizeLarge + Theme.itemSizeMedium
    }
    WinBurst { id: winBurst; shakeTarget: flick }
    JackpotOverlay { id: jackpotFx }
    Connections { target: Game; onJackpot: jackpotFx.show(name, amount) }

    // rules / paytable sheet behind the "?" key
    Rectangle {
        id: infoSheet
        property bool shown: false
        anchors.fill: parent
        z: 70
        color: Qt.rgba(0.02, 0.0, 0.06, 0.94)
        visible: opacity > 0
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        MouseArea { anchors.fill: parent; onClicked: infoSheet.shown = false }
        NeonHeader { id: infoHdr; title: page.title + " · rules"; code: "CLOSE BELOW · OR TAP ANYWHERE"; color: page.accent }
        NeonButton {
            id: infoClose
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.horizontalPageMargin }
            height: Theme.itemSizeLarge
            text: "Close rules"
            color: page.accent; primary: true
            fontSize: Theme.fontSizeLarge
            onClicked: infoSheet.shown = false
        }
        SilicaFlickable {
            anchors { left: parent.left; right: parent.right; top: infoHdr.bottom; bottom: infoClose.top; bottomMargin: Theme.paddingMedium }
            contentHeight: infoText.height + Theme.paddingLarge * 2
            clip: true
            Label {
                id: infoText
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                text: page.info
                color: "white"
                font.pixelSize: Theme.fontSizeSmall
                lineHeight: 1.15
            }
            VerticalScrollDecorator {}
        }
    }

    // Bust: keep the losing round on screen, then offer to move on.
    Item {
        id: bustOverlay
        anchors.fill: parent
        z: 60
        property bool shown: false
        visible: Game.runOver && shown
        Connections { target: Game; onBusted: bustDelay.restart() }
        Timer { id: bustDelay; interval: 1800; onTriggered: { bustOverlay.shown = true; slideIn.restart() } }
        Rectangle {           // red edge vignette
            anchors.fill: parent
            color: "transparent"
            border { width: Theme.paddingMedium; color: Neon.alpha(Neon.red, 0.35) }
        }
        NeonPanel {
            id: bustPanel
            anchors { left: parent.left; right: parent.right; margins: Theme.horizontalPageMargin }
            y: parent.height - height - Theme.paddingLarge
            height: bustCol.height + 2 * Theme.paddingLarge
            glowColor: Neon.red; glowStrength: 0.9; strong: true
            Column {
                id: bustCol
                anchors { left: parent.left; right: parent.right; margins: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
                spacing: Theme.paddingSmall
                NeonText { anchors.horizontalCenter: parent.horizontalCenter; text: "OUT OF CREDITS"; color: Neon.red; font.pixelSize: Theme.fontSizeLarge; glow: 14 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "Your last round is still on the table. Take a look, scroll up if you like, then tap here."
                    color: Neon.alpha(Neon.red, 0.9)
                    font { pixelSize: Theme.fontSizeExtraSmall; family: Neon.display }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "TAP TO CONTINUE"
                    color: "white"
                    font { pixelSize: Theme.fontSizeSmall; bold: true; letterSpacing: 3; family: Neon.display }
                    SequentialAnimation on opacity {
                        running: bustOverlay.visible; loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 600 } NumberAnimation { to: 1; duration: 600 }
                    }
                }
            }
            MouseArea { anchors.fill: parent; onClicked: Game.continueToGameOver() }
        }
        NumberAnimation { id: slideIn; target: bustPanel; property: "y"; from: bustOverlay.height; to: bustOverlay.height - bustPanel.height - Theme.paddingLarge; duration: 450; easing.type: Easing.OutBack }
    }
    Connections { target: Game; onNote: toast.show(text, color) }
}
