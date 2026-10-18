import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

CoverBackground {
    Image {
        anchors.fill: parent
        source: "../images/hex.png"; fillMode: Image.Tile; opacity: 0.08
    }
    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingMedium
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "../images/sym-seven.png"
            width: Theme.iconSizeLarge; height: width
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "NEON CASINO"; color: Neon.pink
            font { pixelSize: Theme.fontSizeSmall; bold: true; letterSpacing: 2; family: Neon.display }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Game.runOver ? "FLATLINED" : Money.fmt(Game.balance)
            color: Game.runOver ? Neon.red : Neon.yellow
            font { pixelSize: Theme.fontSizeLarge; bold: true; family: Neon.display }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "TIER " + Game.tier + " · BEST " + Money.fmt(Game.bestPeak)
            color: Neon.cyan
            font { pixelSize: Theme.fontSizeTiny; letterSpacing: 1; family: Neon.display }
        }
    }
}
