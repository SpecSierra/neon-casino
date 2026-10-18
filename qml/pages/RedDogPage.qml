import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/HiLo.js" as Cards
import "../js/Money.js" as Money

// Red dog: two cards are dealt; win if the third falls strictly between them. The narrower the
// gap, the bigger the pay. Consecutive cards push; a pair pays 11:1 if the third makes three of
// a kind (else push). Pays tuned to 96.7% (exact, infinite deck). All three cards are drawn and
// saved when you deal.
TablePage {
    id: page
    title: "Red dog"
    accent: Neon.red
    scene: "felt"
    musicTrack: "reddog"
    code: "THIRD CARD BETWEEN · TIGHTER GAP PAYS MORE · 97% RTP"
    info: "Two cards are dealt face up (2 low, ace high). The gap between them sets the pay if the third card lands "
          + "strictly between: gap 1 pays 6:1, gap 2 pays 4:1, gap 3 pays 5:2, gap 4+ pays 11:10. "
          + "Consecutive cards: push. A pair: if the third card matches it pays 11:1, else push. Hold Deal to repeat."
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property var payFor: ({ 1: 7, 2: 5, 3: 3.5 })      // returned × stake by gap; 4+ returns 2.1
    property var cards: []
    property int shown: 0
    property bool dealing: false
    property string verdict: ""
    property int gap: -1
    property var history: []
    busy: dealing

    function ret(a, b, c) {
        var va = Cards.value(a), vb = Cards.value(b), vc = Cards.value(c)
        if (va === vb) return vc === va ? 12 : 1
        if (Math.abs(va - vb) === 1) return 1
        var lo = Math.min(va, vb), hi = Math.max(va, vb), g = hi - lo - 1
        return vc > lo && vc < hi ? (payFor[g] || 2.1) : 0
    }
    function deal() {
        if (dealing || !Game.canBet(bet.bet)) return false
        var stake = bet.bet
        Game.stake(stake)
        var c = [Cards.card(), Cards.card(), Cards.card()], r = ret(c[0], c[1], c[2])
        Game.pending = { game: "reddog", staked: stake, returned: Math.round(stake * r * 100) / 100 }
        Game.save()
        var va = Cards.value(c[0]), vb = Cards.value(c[1])
        gap = va === vb ? -2 : Math.abs(va - vb) - 1
        cards = c; shown = 2; verdict = ""
        dealing = true
        third.restart()
        Sound.play("card")
        return true
    }
    Timer { id: third; interval: 900; onTriggered: { page.shown = 3; Sound.play("card"); settleT.restart() } }
    Timer {
        id: settleT; interval: 500
        onTriggered: {
            var p = Game.pending
            page.dealing = false
            page.verdict = p.returned > p.staked ? "win" : p.returned === p.staked ? "push" : "lose"
            page.history = [page.verdict].concat(page.history).slice(0, 14)
            if (page.verdict === "win") page.burst.show(p.returned - p.staked, p.returned >= p.staked * 5)
            else if (page.verdict === "lose") Sound.play("lose")
            Haptics.tap()
            Game.settle(p.staked, p.returned, "reddog")
        }
    }

    NeonPanel {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 0.85
        glowColor: page.dealing || !page.verdict ? Neon.red : page.verdict === "win" ? Neon.green : page.verdict === "push" ? Neon.yellow : Neon.red
        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingLarge
            Repeater {
                model: 3
                Item {
                    width: page.width * 0.24; height: width * 1.45
                    y: index === 1 ? -Theme.paddingLarge * 2 : 0
                    Rectangle {
                        anchors.fill: parent; radius: 8
                        color: "transparent"; border { width: 2; color: Neon.alpha(Neon.red, 0.4) }
                        visible: index >= page.shown
                        Text { anchors.centerIn: parent; text: index === 1 ? "?" : ""; color: Neon.alpha(Neon.red, 0.6); font { family: Neon.display; bold: true; pixelSize: parent.height * 0.4 } }
                    }
                    CardItem {
                        anchors.fill: parent
                        // the middle slot is the third card
                        readonly property var c: page.cards.length ? page.cards[index === 1 ? 2 : index === 2 ? 1 : 0] : null
                        visible: c !== null && (index === 1 ? page.shown >= 3 : page.shown >= 2)
                        rank: c ? c.rank : "2"; suit: c ? c.suit : "spades"
                        animateIn: false
                    }
                }
            }
        }
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.paddingLarge }
            text: page.gap === -2 ? "PAIR · TRIPS PAY 11:1" : page.gap === 0 ? "CONSECUTIVE · PUSH" : page.gap > 0 ? "GAP " + page.gap + " · PAYS " + ({ 1: "6:1", 2: "4:1", 3: "5:2" }[page.gap] || "11:10") : "DEAL TO PLAY"
            color: Neon.yellow
            font { family: Neon.mono; pixelSize: Theme.fontSizeSmall; letterSpacing: 1 }
        }
    }
    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall
        Repeater {
            model: page.history
            Text { text: modelData === "win" ? "W" : modelData === "push" ? "P" : "L"; color: modelData === "win" ? Neon.green : modelData === "push" ? Neon.yellow : Neon.red; font { family: Neon.mono; pixelSize: Theme.fontSizeSmall } }
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
            Timer { id: auto; interval: 300; repeat: true; onTriggered: if (!page.dealing && !page.deal()) stop() }
        }
    }
}
