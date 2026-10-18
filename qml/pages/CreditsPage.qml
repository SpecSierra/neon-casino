import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/MusicCredits.js" as C

// Where the music comes from: public-domain pieces, arranged for the casino.
Page {
    Backdrop { accent: Neon.violet }
    SilicaListView {
        anchors.fill: parent
        header: Column {
            width: parent.width
            NeonHeader { title: "Music credits"; code: "CC0 CHIPTUNES · 9 COMPOSERS"; color: Neon.violet }
            Label {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: "Every track is a chiptune released into the public domain (CC0) on OpenGameArt by Zane Little Music, "
                      + "Juhani Junkala (SubspaceAudio), ansimuz, celestialghost8, Spring Spring, LordZintick, skrjablin and 3xBlast. Thank you! Free spins play the machine's track sped up. "
                      + "Fonts: Neon Display and Neon Mono, modified from Chakra Petch and Share Tech Mono (SIL Open Font "
                      + "License) to add the credit-chip currency sign.\n"
            }
        }
        model: C.credits
        delegate: Item {
            x: Theme.horizontalPageMargin
            width: ListView.view.width - 2 * x
            height: col.height + Theme.paddingMedium
            Column {
                id: col
                width: parent.width
                Text { text: modelData.track.toUpperCase(); color: Neon.violet; font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 2 } }
                Text { width: parent.width; wrapMode: Text.Wrap; text: modelData.title; color: "white"; font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeSmall } }
                Text { width: parent.width; wrapMode: Text.Wrap; text: modelData.by; color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeExtraSmall }
            }
        }
        VerticalScrollDecorator {}
    }
}
