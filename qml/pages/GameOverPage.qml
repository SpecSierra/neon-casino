import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money
import "../js/Perks.js" as Perks

Page {
    id: page
    objectName: "gameover"
    backNavigation: false
    Component.onCompleted: { Sound.play("bust"); Haptics.rumble(3) }

    Backdrop { accent: Neon.red }

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.horizontalPageMargin
        spacing: Theme.paddingLarge

        NeonText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "FLATLINED"; color: Neon.red; font.pixelSize: Theme.fontSizeHuge; glow: 18
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "RUN #" + Game.runs + " IS OVER"
            color: Neon.alpha(Neon.red, 0.8)
            font { pixelSize: Theme.fontSizeSmall; letterSpacing: 4; family: Neon.display }
        }
        NeonPanel {
            width: parent.width; height: stats.height + 2 * Theme.paddingLarge
            glowColor: Neon.red; strong: true
            Column {
                id: stats
                anchors { left: parent.left; right: parent.right; margins: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
                NeonDetail { label: "Peak"; value: Money.fmt(Game.peak) }
                NeonDetail { label: "Tier reached"; value: Game.tier }
                NeonDetail { label: "Bets"; value: Game.bets }
                NeonDetail { label: "Biggest win"; value: Money.fmt(Game.runBiggestWin) }
                NeonDetail { label: "Perks"; value: Game.perks.length }
                NeonDetail { label: "Best ever"; value: Money.fmt(Game.bestPeak) }
                NeonDetail {
                    visible: !!Game.lastRound
                    label: "Last round"
                    value: Game.lastRound ? ({ slots: "Slots", blackjack: "Blackjack", roulette: "Roulette", overload: "Overload",
                                               poker: "Video poker", baccarat: "Baccarat", craps: "Craps", keno: "Keno", mines: "Mines", plinko: "Plinko", sicbo: "Sic Bo", hilo: "Hi-Lo", wheel: "Money Wheel", scratch: "Scratch", coinflip: "Coin Flip", dice: "Dice", tower: "Tower", rps: "Rock paper scissors", war: "Card war", race: "Drone race", penalty: "Penalty", reddog: "Red dog", balloon: "Balloon", darts: "Darts", claw: "Claw machine", chests: "Treasure chests" }[Game.lastRound.game] || Game.lastRound.game)
                                            + ": bet " + Money.fmt(Game.lastRound.staked) + ", back " + Money.fmt(Game.lastRound.returned) : ""
                }
            }
        }
        Label {
            width: parent.width
            visible: !Game.custom && Game.peak >= Game.bestPeak && Game.peak > 100
            horizontalAlignment: Text.AlignHCenter
            text: "NEW RECORD"
            color: Neon.yellow
            font { pixelSize: Theme.fontSizeLarge; bold: true; family: Neon.display }
        }
        Text {
            visible: Game.rebootAvailable
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: "REBOOT · ONE TRY · CLEAR " + Game.rebootGates + " FOR " + Money.fmt(Game.rebootAmount) + " · PICK YOUR GAME"
            color: Neon.yellow
            font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall; letterSpacing: 1 }
        }
        Row {
            visible: Game.rebootAvailable
            width: parent.width
            spacing: Theme.paddingMedium
            Repeater {
                model: [{ page: "RebootPage.qml", title: "Drone", sub: "TAP TO FLY", color: Neon.yellow },
                        { page: "FirewallPage.qml", title: "Firewall", sub: "DRAG TO DODGE", color: Neon.cyan }]
                NeonButton {
                    width: (parent.width - Theme.paddingMedium) / 2
                    height: Theme.itemSizeLarge
                    text: modelData.title + "<br><font size='1'>" + modelData.sub + "</font>"
                    color: modelData.color; primary: true
                    fontSize: Theme.fontSizeMedium
                    onClicked: pageStack.push(Qt.resolvedUrl(modelData.page))
                    SequentialAnimation on scale {
                        loops: Animation.Infinite; running: parent.visible
                        NumberAnimation { to: 1.03; duration: 500 } NumberAnimation { to: 1; duration: 500 }
                    }
                }
            }
        }
        NeonButton {
            visible: !Game.rebootAvailable
            width: parent.width
            text: "Custom run…"
            color: Neon.yellow
            onClicked: pageStack.push(Qt.resolvedUrl("NewRunPage.qml"))
        }
        NeonButton {
            visible: !Game.rebootAvailable
            width: parent.width
            text: "Jack in again · " + Money.fmt(100)
            color: Neon.cyan; primary: true
            onClicked: {
                Game.newRun()
                pageStack.pop(pageStack.find(function (p) { return p.objectName === "hub" }),
                              PageStackAction.Immediate)
            }
        }
    }
}
