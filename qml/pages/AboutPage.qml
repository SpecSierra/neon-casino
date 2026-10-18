import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Version.js" as Version

Page {
    id: page
    objectName: "about"
    Backdrop { accent: Neon.green; scene: "lobby" }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height + Theme.paddingLarge * 2
        Column {
            id: col
            width: parent.width
            spacing: Theme.paddingLarge
            NeonHeader { title: "About"; code: "VERSION " + Version.version; color: Neon.green }
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeHuge * 1.2; height: width
                source: "../images/app-icon.png"
                sourceSize { width: 172; height: 172 }
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                NeonText { anchors.horizontalCenter: parent.horizontalCenter; text: "NEON"; color: Neon.pink; font.pixelSize: Theme.fontSizeHuge; glow: 12 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "CASINO"; color: "transparent"; style: Text.Outline; styleColor: Neon.cyan
                    font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeExtraLarge; letterSpacing: 8 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "v" + Version.version
                    color: Neon.alpha(Neon.yellow, 0.85)
                    font { family: Neon.mono; pixelSize: Theme.fontSizeSmall }
                }
            }
            Label {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeSmall
                text: "A cyberpunk casino roguelike for Sailfish OS. Start every run with ¤100, climb the tiers, draft perks, "
                      + "and see how far the neon takes you: 10 slot machines, 10 table games, 15 mini games and three progressive jackpots."
            }
            NeonPanel {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                height: fair.height + 2 * Theme.paddingLarge
                glowColor: Neon.yellow
                Label {
                    id: fair
                    anchors { left: parent.left; right: parent.right; margins: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Neon.yellow
                    text: "PLAY MONEY ONLY. Neon credits (¤) have no cash value: nothing to buy, nothing to win. "
                          + "Every game shows its rules and its return to player behind the ? key; each result is decided "
                          + "and saved before it is shown, so quitting never undoes a loss."
                }
            }
            Label {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: "Music: CC0 chiptunes from OpenGameArt (see Music credits).\n"
                      + "Fonts: Neon Display and Neon Mono, modified from Chakra Petch and Share Tech Mono (SIL Open Font License).\n"
                      + "Art, sounds and code made for this app."
            }
            NeonButton {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                text: "Music credits"; color: Neon.violet
                onClicked: pageStack.push(Qt.resolvedUrl("CreditsPage.qml"))
            }
        }
        VerticalScrollDecorator {}
    }
}
