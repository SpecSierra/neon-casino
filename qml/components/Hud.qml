import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/Money.js" as Money
import "."

// Credits readout on top of every table: an accent rail, LED-style mono digits, a solid tier
// tag, and a segmented bar toward the next tier. No box: it reads as an instrument, not a card.
Item {
    id: hud
    property var game: Game
    property real shown: game.balance
    Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    property real last: game.balance
    readonly property bool atPeak: game.balance >= game.peak - 0.001
    readonly property real from: Money.tierThreshold(game.tier, game.scale)
    readonly property real progress: Math.max(0, Math.min(1, (game.netWorth - from) / Math.max(1, game.nextTierAt - from)))
    height: Theme.itemSizeMedium + Theme.paddingMedium
    Connections {
        target: hud.game
        onBalanceChanged: {
            var d = hud.game.balance - hud.last
            hud.last = hud.game.balance
            if (Math.abs(d) < 0.005) return
            flash.color = d > 0 ? Neon.green : Neon.red
            flashAnim.restart()
        }
    }

    Rectangle {            // accent rail
        id: rail
        width: Theme.paddingSmall; height: parent.height - Theme.paddingMedium
        color: hud.atPeak ? Neon.yellow : Neon.cyan
    }
    Rectangle {
        id: flash
        anchors { left: rail.right; right: parent.right; top: rail.top; bottom: rail.bottom }
        opacity: 0
    }
    NumberAnimation { id: flashAnim; target: flash; property: "opacity"; from: 0.28; to: 0; duration: 650; easing.type: Easing.OutQuad }

    Column {
        anchors { left: rail.right; leftMargin: Theme.paddingMedium; verticalCenter: rail.verticalCenter }
        Text {
            text: hud.game.vault > 0 ? "CREDITS  //  VAULT " + Money.fmt(hud.game.vault) : "CREDITS"
            color: Neon.alpha(Neon.cyan, 0.75)
            font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 2 }
        }
        Text {
            text: Money.fmt(hud.shown)
            color: hud.atPeak ? Neon.yellow : "white"
            font { family: Neon.mono; pixelSize: Theme.fontSizeExtraLarge }
            style: Text.Raised; styleColor: Neon.alpha(hud.atPeak ? Neon.yellow : Neon.cyan, 0.45)
        }
    }
    Column {
        anchors { right: parent.right; verticalCenter: rail.verticalCenter }
        spacing: Theme.paddingSmall / 2
        Rectangle {          // tier tag
            anchors.right: parent.right
            width: tierText.implicitWidth + 2 * Theme.paddingMedium; height: tierText.implicitHeight + Theme.paddingSmall
            color: Neon.pink
            Text {
                id: tierText
                anchors.centerIn: parent
                text: "TIER " + hud.game.tier
                color: Neon.ink
                font { family: Neon.display; pixelSize: Theme.fontSizeExtraSmall; bold: true; letterSpacing: 1 }
            }
        }
        Text {
            anchors.right: parent.right
            text: "MIN " + Money.fmt(hud.game.minBet) + "  ·  NEXT " + Money.fmt(hud.game.nextTierAt)
            color: Neon.alpha(Neon.pink, 0.85)
            font { family: Neon.mono; pixelSize: Theme.fontSizeTiny }
        }
        Text {               // the grand jackpot, ticking up with every bet
            anchors.right: parent.right
            text: "JACKPOT " + Money.fmt(hud.game.jackpotValue("grand"))
            color: Neon.alpha(Neon.red, 0.95)
            font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; bold: true }
        }
    }
    Row {                    // segmented progress to the next tier
        anchors { left: rail.right; leftMargin: Theme.paddingMedium; right: parent.right; bottom: parent.bottom }
        spacing: 3
        Repeater {
            model: 16
            Rectangle {
                width: (hud.width - rail.width - Theme.paddingMedium - 15 * 3) / 16
                height: Theme.paddingSmall
                color: index < Math.round(hud.progress * 16) ? Neon.pink : Neon.alpha(Neon.pink, 0.15)
                Behavior on color { ColorAnimation { duration: 250 } }
            }
        }
    }
}
