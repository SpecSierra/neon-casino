import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/HiLo.js" as Cards
import "../js/Money.js" as Money

// Card war: one card each, high card wins 1:1. A tie returns half the bet (96.2% RTP).
// Both cards are drawn and saved before they're dealt.
TablePage {
    id: page
    title: "Card war"
    accent: Neon.red
    scene: "felt"
    musicTrack: "war"
    code: "HIGH CARD WINS 1:1 · TIE RETURNS HALF · 96% RTP"
    info: "You and the dealer get one card each (2 low, ace high, suits don't matter). Higher card wins even money. "
          + "On a tie you get half your bet back. Hold Deal to keep playing."
    footerHeight: footerCol.height + Theme.paddingLarge

    property var you: null
    property var dealer: null
    property bool dealing: false
    property string verdict: ""
    property var history: []
    property int dealt: 0
    busy: dealing

    function deal() {
        if (dealing || !Game.canBet(bet.bet)) return false
        var stake = bet.bet
        Game.stake(stake)
        var a = Cards.card(), b = Cards.card(), va = Cards.value(a), vb = Cards.value(b)
        var res = va > vb ? "win" : va < vb ? "lose" : "tie"
        Game.pending = { game: "war", staked: stake, returned: res === "win" ? stake * 2 : res === "tie" ? Math.round(stake * 50) / 100 : 0 }
        Game.save()
        dealing = true
        verdict = res
        you = a; dealer = b; dealt += 1
        Sound.play("card")
        settleTimer.restart()
        return true
    }
    Timer {
        id: settleTimer; interval: 750
        onTriggered: {
            var p = Game.pending
            page.dealing = false
            page.history = [page.verdict].concat(page.history).slice(0, 16)
            if (page.verdict === "win") page.burst.show(p.returned - p.staked, false)
            else if (page.verdict === "lose") Sound.play("lose")
            Haptics.tick()
            Game.settle(p.staked, p.returned, "war")
        }
    }

    NeonPanel {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 0.95
        glowColor: page.dealing || !page.verdict ? Neon.red : page.verdict === "win" ? Neon.green : page.verdict === "tie" ? Neon.yellow : Neon.red
        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingLarge * 2
            Repeater {
                model: 2
                Column {
                    spacing: Theme.paddingMedium
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: index === 0 ? "YOU" : "DEALER"; color: index === 0 ? Neon.cyan : Neon.red; font { family: Neon.mono; pixelSize: Theme.fontSizeSmall; letterSpacing: 3 } }
                    Item {
                        width: page.width * 0.3; height: width * 1.45
                        CardItem {
                            // a new item per deal so the fly-in animation replays
                            id: c
                            anchors.centerIn: parent
                            width: parent.width
                            visible: (index === 0 ? page.you : page.dealer) !== null
                            rank: (index === 0 ? page.you : page.dealer) ? (index === 0 ? page.you : page.dealer).rank : "2"
                            suit: (index === 0 ? page.you : page.dealer) ? (index === 0 ? page.you : page.dealer).suit : "spades"
                            animateIn: false
                            scale: 1
                            SequentialAnimation on scale {
                                id: pop
                                running: false
                                NumberAnimation { from: 0.6; to: 1; duration: 260; easing.type: Easing.OutBack }
                            }
                            Connections { target: page; onDealtChanged: pop.restart() }
                        }
                    }
                }
            }
        }
        NeonText {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.paddingLarge }
            visible: !page.dealing && page.verdict !== ""
            text: page.verdict === "win" ? "YOU WIN" : page.verdict === "tie" ? "WAR! HALF BACK" : "DEALER WINS"
            color: page.verdict === "win" ? Neon.green : page.verdict === "tie" ? Neon.yellow : Neon.red
            font.pixelSize: Theme.fontSizeExtraLarge
        }
    }
    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall
        Repeater {
            model: page.history
            Text { text: modelData === "win" ? "W" : modelData === "tie" ? "T" : "L"; color: modelData === "win" ? Neon.green : modelData === "tie" ? Neon.yellow : Neon.red; font { family: Neon.mono; pixelSize: Theme.fontSizeSmall } }
        }
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        BetSelector { id: bet; width: parent.width; locked: page.busy; color: Neon.yellow }
        NeonButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            height: Theme.itemSizeMedium
            text: "Deal " + Money.fmt(bet.bet) + " · hold to repeat"
            color: Neon.red; primary: true
            fontSize: Theme.fontSizeMedium
            enabled: page.dealing || Game.canBet(bet.bet)
            onClicked: page.deal()
            onPressAndHold: auto.start()
            onReleased: auto.stop()
            onCanceled: auto.stop()
            Timer { id: auto; interval: 250; repeat: true; onTriggered: if (!page.dealing && !page.deal()) stop() }
        }
    }
}
