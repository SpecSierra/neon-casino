import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Cards.js" as Cards
import "../js/Money.js" as Money

// Full blackjack: 6-deck shoe, dealer stands on all 17s, peek for blackjack, insurance,
// double on any two cards (also after a split), split up to 4 hands (split aces get one
// card each), surrender with the Ghost Protocol perk.
TablePage {
    id: page
    title: "Blackjack"
    accent: Neon.cyan
    scene: "felt"
    code: "6 DECKS · DEALER STANDS ON 17 · BLACKJACK 3:2"
    musicTrack: "blackjack"
    footerHeight: footerCol.height + Theme.paddingLarge

    // "bet" → "dealing" → ["insurance"] → "player" → "dealer" → "bet"
    property string phase: "bet"
    property var shoe: Cards.newShoe(6)
    property var hands: []          // [{ cards, stake, done, splitAces, result }]
    property int active: 0
    property var dealer: []
    property real insurance: 0
    property real insuranceReturn: 0
    property string message: "PLACE YOUR BET"
    property color messageColor: Neon.cyan
    property bool holeVisible: false
    property bool holeShown: false      // seen early through the Optic Implant
    busy: phase !== "bet"

    // ---- auto-save: the whole round, shoe included, after every change ----
    // Reopening the app resumes the same hand with the same next cards, so quitting
    // can't dodge a bad draw.
    onPhaseChanged: persistSoon.restart()
    onHandsChanged: persistSoon.restart()
    onDealerChanged: persistSoon.restart()
    onActiveChanged: persistSoon.restart()
    onInsuranceChanged: persistSoon.restart()
    Timer { id: persistSoon; interval: 0; onTriggered: page.persist() }
    function persist() {
        if (phase === "bet") return
        Game.blackjack = { phase: phase, shoe: shoe, hands: hands, active: active, dealer: dealer,
                           insurance: insurance, insuranceReturn: insuranceReturn,
                           holeVisible: holeVisible, holeShown: holeShown, dealStep: dealSeq.step }
        Game.save()
    }
    function restore() {
        var b = Game.blackjack
        shoe = b.shoe; hands = b.hands; active = b.active; dealer = b.dealer
        insurance = b.insurance; insuranceReturn = b.insuranceReturn
        holeVisible = b.holeVisible; holeShown = b.holeShown
        dealerModel.clear()
        for (var i = 0; i < dealer.length; ++i)
            dealerModel.append({ rank: dealer[i].rank, suit: dealer[i].suit, faceUp: i !== 1 || holeVisible || holeShown })
        handsModel.clear()
        for (var h = 0; h < hands.length; ++h) {
            handsModel.append({ cards: [] })
            for (var c = 0; c < hands[h].cards.length; ++c)
                handsModel.get(h).cards.append({ rank: hands[h].cards[c].rank, suit: hands[h].cards[c].suit })
        }
        message = "HAND RESUMED"; messageColor = Neon.violet
        phase = b.phase
        if (phase === "dealing") { dealSeq.step = b.dealStep; dealSeq.start() }
        else if (phase === "insurance") message = "INSURANCE?"
        else if (phase === "dealer") dealerTimer.start()
        else if (phase === "player" && hands[active].cards.length === 1) nextHand.restart()
    }
    Component.onCompleted: if (Game.blackjack) restore()

    readonly property var dealerScore: Cards.score(holeVisible ? dealer : dealer.slice(0, 1))
    readonly property var hand: hands.length > active ? hands[active] : null
    readonly property bool canAct: phase === "player" && hand !== null

    function draw() {
        if (shoe.length < 78) { shoe = Cards.newShoe(6); Game.note("SHUFFLING SHOE", Neon.violet) }
        return shoe.pop()
    }
    function touch() { hands = hands.slice() }           // re-notify bindings after in-place edits
    function giveDealer(faceUp) {
        var c = draw()
        dealer = dealer.concat([c])
        dealerModel.append({ rank: c.rank, suit: c.suit, faceUp: faceUp })
    }
    function giveHand(i) {
        var c = draw()
        hands[i].cards.push(c)
        handsModel.get(i).cards.append({ rank: c.rank, suit: c.suit })
        touch()
    }
    function score(i) { return Cards.score(hands[i].cards).total }
    function revealHole() {
        holeVisible = true
        if (dealerModel.count > 1) dealerModel.setProperty(1, "faceUp", true)
    }

    // ---- round start ----
    function deal() {
        if (phase !== "bet" || !Game.canBet(bet.bet)) return
        // Read the bet before staking: staking lowers the balance, and the selector then
        // clamps itself to what's left (that used to shrink the hand's stake).
        var amount = bet.bet
        phase = "dealing"
        Game.stake(amount)
        hands = [{ cards: [], stake: amount, done: false, splitAces: false, result: "" }]
        handsModel.clear(); handsModel.append({ cards: [] })
        dealer = []; dealerModel.clear()
        active = 0; insurance = 0; insuranceReturn = 0
        holeVisible = false; holeShown = false
        message = ""
        phase = "dealing"
        dealSeq.step = 0
        dealSeq.start()
    }
    Timer {
        id: dealSeq
        property int step: 0
        interval: 260; repeat: true
        onTriggered: {
            if (step === 0 || step === 2) giveHand(0)
            else if (step === 1) giveDealer(true)
            else if (step === 3) {
                giveDealer(false)
                if (Game.hasPerk("optic") && Math.random() < 0.25) {
                    dealerModel.setProperty(1, "faceUp", true)
                    holeShown = true
                    Game.note("OPTIC IMPLANT: HOLE CARD SEEN", Neon.cyan)
                }
            } else { stop(); afterDeal() }
            ++step
        }
    }
    function afterDeal() {
        if (dealer[0].rank === "A" && !Cards.isBlackjack(hands[0].cards) && Game.balance >= hands[0].stake / 2) {
            phase = "insurance"
            message = "INSURANCE?"
            messageColor = Neon.yellow
            return
        }
        peek()
    }
    function takeInsurance(yes) {
        if (phase !== "insurance") return
        if (yes) { insurance = Math.floor(hands[0].stake / 2 * 100) / 100; Game.stake(insurance); Game.count("insurance") }
        message = ""
        peek()
    }
    function peek() {
        var dbj = Cards.isBlackjack(dealer), pbj = Cards.isBlackjack(hands[0].cards)
        if (insurance > 0) {
            if (dbj) { insuranceReturn = insurance * 3; Game.note("INSURANCE PAYS 2:1", Neon.yellow) }
            else Game.note("NO BLACKJACK · INSURANCE LOST", Neon.violet)
        }
        if (dbj || pbj) {
            revealHole()
            hands[0].result = dbj && pbj ? "push" : pbj ? "blackjack" : "lose"
            hands[0].done = true
            touch()
            settleAll()
            return
        }
        phase = "player"
    }

    // ---- player actions ----
    function hit() {
        if (!canAct) return
        giveHand(active)
        afterCard()
    }
    function afterCard() {
        var h = hands[active], s = score(active)
        if (s > 21) { h.result = "bust"; h.done = true }
        else if (h.cards.length >= 5 && Game.hasPerk("charlie")) { h.result = "charlie"; h.done = true }
        else if (s === 21) h.done = true
        touch()
        if (h.done) advance()
    }
    function stand() {
        if (!canAct) return
        hands[active].done = true
        touch()
        advance()
    }
    readonly property bool canDouble: canAct && hand.cards.length === 2 && !hand.splitAces && Game.balance >= hand.stake
    function doubleDown() {
        if (!canDouble) return
        var h = hands[active]
        Game.stake(h.stake)
        Game.count("doubles")
        h.stake *= 2
        h.doubled = true
        giveHand(active)
        if (score(active) > 21) h.result = "bust"
        h.done = true
        touch()
        advance()
    }
    readonly property bool canSplit: canAct && hand.cards.length === 2 && hands.length < 4
                                     && Cards.value(hand.cards[0]) === Cards.value(hand.cards[1])
                                     && Game.balance >= hand.stake
    function split() {
        if (!canSplit) return
        var h = hands[active]
        Game.stake(h.stake)
        Game.count("splits")
        var moved = h.cards.pop()
        handsModel.get(active).cards.remove(1)
        var aces = moved.rank === "A"
        h.splitAces = aces
        hands.splice(active + 1, 0, { cards: [moved], stake: h.stake, done: false, splitAces: aces, result: "" })
        handsModel.insert(active + 1, { cards: [] })
        handsModel.get(active + 1).cards.append({ rank: moved.rank, suit: moved.suit })
        touch()
        Sound.play("card")
        splitDeal.restart()
    }
    // second card for the hand that was just split
    Timer {
        id: splitDeal
        interval: 300
        onTriggered: {
            giveHand(active)
            if (hands[active].splitAces) { hands[active].done = true; touch(); advance() }
            else afterCard()
        }
    }
    readonly property bool canSurrender: canAct && Game.hasPerk("ghost") && hands.length === 1 && hand.cards.length === 2
    function surrender() {
        if (!canSurrender) return
        hands[0].result = "surrender"
        hands[0].done = true
        touch()
        revealHole()
        settleAll()
    }
    // move to the next unfinished hand, or let the dealer play
    function advance() {
        for (var i = active + 1; i < hands.length; ++i) {
            if (hands[i].done) continue
            active = i
            nextHand.restart()
            return
        }
        dealerTurn()
    }
    Timer {
        id: nextHand
        interval: 300
        onTriggered: {
            if (hands[active].cards.length === 1) {
                giveHand(active)
                if (hands[active].splitAces) { hands[active].done = true; touch(); advance(); return }
                afterCard()
            }
        }
    }

    // ---- dealer ----
    function dealerTurn() {
        revealHole()
        var live = hands.some(function (h) { return h.result === "" })
        if (!live) { settleAll(); return }
        phase = "dealer"
        dealerTimer.start()
    }
    Timer {
        id: dealerTimer
        interval: 600; repeat: true
        onTriggered: {
            if (Cards.score(dealer).total < 17) { giveDealer(true); return }
            stop()
            var d = Cards.score(dealer).total
            for (var i = 0; i < hands.length; ++i) {
                var h = hands[i]
                if (h.result !== "") continue
                var p = score(i)
                h.result = d > 21 ? "dealerbust" : p > d ? "win" : p < d ? "lose" : "push"
            }
            touch()
            settleAll()
        }
    }

    function payout(h) {
        switch (h.result) {
        case "blackjack": return h.stake * (Game.hasPerk("natural") ? 3 : 2.5)
        case "charlie": return h.stake * 3
        case "win": case "dealerbust": return h.stake * 2
        case "push": return h.stake
        case "surrender": return h.stake / 2
        }
        return 0
    }
    function settleAll() {
        var staked = insurance, returned = insuranceReturn
        for (var i = 0; i < hands.length; ++i) { staked += hands[i].stake; returned += payout(hands[i]) }
        returned = Math.round(returned * 100) / 100
        var net = returned - staked
        if (hands.length === 1) {
            var r = hands[0].result
            message = { blackjack: "BLACKJACK", charlie: "FIVE-CARD CHARLIE", win: "YOU WIN", dealerbust: "DEALER BUSTS",
                        push: "PUSH", surrender: "SURRENDERED", bust: "BUST" }[r] || "DEALER WINS"
        } else {
            message = net > 0 ? "NET +" + Money.fmt(net) : net < 0 ? "NET −" + Money.fmt(-net) : "EVEN"
        }
        messageColor = net > 0 ? Neon.green : net < 0 ? Neon.red : Neon.violet
        if (net > 0) page.burst.show(net, net >= staked * 1.5)
        else if (net < 0) Sound.play("lose")
        for (var j = 0; j < hands.length; ++j) {
            if (hands[j].result === "blackjack") Game.count("blackjacks")
            if (hands[j].result === "charlie") Game.count("charlies")
        }
        Game.count("hands", hands.length)
        Game.blackjack = null
        phase = "bet"
        Game.settle(staked, returned, "blackjack")
    }

    ListModel { id: dealerModel }
    ListModel { id: handsModel }      // one entry per hand, each with a nested `cards` list

    function resultLabel(r) {
        return { blackjack: "BLACKJACK", charlie: "CHARLIE", win: "WIN", dealerbust: "WIN", push: "PUSH",
                 surrender: "FOLD", bust: "BUST", lose: "LOSE" }[r] || ""
    }
    function resultColor(r) {
        return r === "bust" || r === "lose" ? Neon.red : r === "push" || r === "surrender" ? Neon.violet : Neon.green
    }

    NeonPanel {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: tableCol.height + 2 * Theme.paddingLarge
        glowColor: Neon.cyan

        Column {
            id: tableCol
            anchors { left: parent.left; right: parent.right; margins: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
            spacing: Theme.paddingMedium

            Text {
                text: "DEALER" + (dealer.length ? "  ·  " + page.dealerScore.total + (holeVisible ? "" : " + ?") : "")
                color: Neon.alpha(Neon.pink, 0.9)
                font { pixelSize: Theme.fontSizeSmall; bold: true; letterSpacing: 3; family: Neon.display }
            }
            Item {
                width: parent.width; height: cardSize.height
                Row {
                    spacing: -cardSize.width * 0.35
                    Repeater {
                        model: dealerModel
                        CardItem { rank: model.rank; suit: model.suit; faceUp: model.faceUp }
                    }
                }
            }
            Item {
                width: parent.width; height: Theme.itemSizeSmall
                NeonText {
                    anchors.centerIn: parent
                    text: page.message
                    color: page.messageColor
                    glow: 10
                }
            }
            // player hands, side by side after a split
            Row {
                id: handsRow
                width: parent.width
                property real handW: width / Math.max(1, handsModel.count)
                property real cardScale: handsModel.count > 2 ? 0.72 : 1
                Repeater {
                    model: handsModel
                    Item {
                        id: handItem
                        readonly property int handIndex: index
                        readonly property var info: page.hands.length > index ? page.hands[index] : null
                        readonly property bool isActive: page.phase === "player" && page.active === index && page.hands.length > 1
                        width: handsRow.handW
                        height: cardSize.height * handsRow.cardScale + handLabel.height + Theme.paddingSmall * 2

                        Rectangle {
                            anchors { fill: parent; margins: 2 }
                            radius: 4
                            color: handItem.isActive ? Neon.alpha(Neon.yellow, 0.10) : "transparent"
                            border { width: handItem.isActive ? 2 : 0; color: Neon.yellow }
                        }
                        Row {
                            id: cardRow
                            x: Theme.paddingSmall; y: Theme.paddingSmall
                            property real cw: cardSize.width * handsRow.cardScale
                            property int n: Math.max(1, model.cards.count)
                            spacing: n > 1 ? Math.min(-cw * 0.35, (handItem.width - 2 * Theme.paddingSmall - cw) / (n - 1) - cw) : 0
                            Repeater {
                                model: cards
                                CardItem {
                                    width: cardRow.cw
                                    rank: model.rank; suit: model.suit
                                }
                            }
                        }
                        Text {
                            id: handLabel
                            anchors { left: parent.left; leftMargin: Theme.paddingSmall; bottom: parent.bottom; bottomMargin: Theme.paddingSmall / 2 }
                            width: parent.width - Theme.paddingSmall
                            elide: Text.ElideRight
                            property var sc: handItem.info ? Cards.score(handItem.info.cards) : null
                            text: !handItem.info ? "" :
                                  (handItem.info.result ? page.resultLabel(handItem.info.result) + " · " : "")
                                  + sc.total + (sc.soft && sc.total < 21 ? "s" : "") + " · " + Money.fmt(handItem.info.stake)
                            color: handItem.info && handItem.info.result ? page.resultColor(handItem.info.result)
                                   : Neon.alpha(Neon.cyan, 0.9)
                            font { pixelSize: Theme.fontSizeExtraSmall; bold: true; letterSpacing: 1; family: Neon.display }
                        }
                    }
                }
            }
            Text {
                visible: handsModel.count === 0
                text: "YOU"
                color: Neon.alpha(Neon.cyan, 0.9)
                font { pixelSize: Theme.fontSizeSmall; bold: true; letterSpacing: 3; family: Neon.display }
            }
            Item { visible: handsModel.count === 0; width: 1; height: cardSize.height }
        }
        CardItem { id: cardSize; visible: false; animateIn: false; rank: ""; suit: "" }
    }
    Label {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        wrapMode: Text.Wrap
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.secondaryColor
        text: "Dealer stands on all 17s and peeks for blackjack. Insurance pays 2:1. Double any two cards,"
              + " also after a split. Split pairs up to 4 hands; split aces get one card."
              + (Game.hasPerk("natural") ? " Blackjack pays 2:1." : " Blackjack pays 3:2.")
              + (Game.hasPerk("charlie") ? " Five cards under 22 win 2:1." : "")
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        BetSelector {
            id: bet; width: parent.width; locked: page.busy; color: Neon.yellow
            visible: page.phase === "bet" || page.phase === "dealing"
        }
        // insurance
        Row {
            visible: page.phase === "insurance"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            height: Theme.itemSizeMedium
            property real w: (page.width - 2 * Theme.horizontalPageMargin - spacing) / 2
            NeonButton {
                width: parent.w; height: parent.height; color: Neon.yellow; primary: true
                fontSize: Theme.fontSizeSmall
                text: "Insure " + Money.fmt(page.hands.length ? Math.floor(page.hands[0].stake / 2 * 100) / 100 : 0)
                onClicked: page.takeInsurance(true)
            }
            NeonButton {
                width: parent.w; height: parent.height; color: Neon.violet
                fontSize: Theme.fontSizeSmall
                text: "No thanks"
                onClicked: page.takeInsurance(false)
            }
        }
        // actions: two rows so five buttons stay thumb-sized
        Column {
            visible: page.phase === "player" || page.phase === "dealer"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            Row {
                spacing: Theme.paddingSmall
                property real w: (page.width - 2 * Theme.horizontalPageMargin - spacing) / 2
                NeonButton { width: parent.w; height: Theme.itemSizeMedium; text: "Hit"; color: Neon.green; primary: true; enabled: page.canAct; onClicked: page.hit() }
                NeonButton { width: parent.w; height: Theme.itemSizeMedium; text: "Stand"; color: Neon.cyan; primary: true; enabled: page.canAct; onClicked: page.stand() }
            }
            Row {
                spacing: Theme.paddingSmall
                property int count: Game.hasPerk("ghost") ? 3 : 2
                property real w: (page.width - 2 * Theme.horizontalPageMargin - (count - 1) * spacing) / count
                NeonButton { width: parent.w; height: Theme.itemSizeSmall; text: "Double"; color: Neon.yellow; fontSize: Theme.fontSizeSmall; enabled: page.canDouble; onClicked: page.doubleDown() }
                NeonButton { width: parent.w; height: Theme.itemSizeSmall; text: "Split"; color: Neon.pink; fontSize: Theme.fontSizeSmall; enabled: page.canSplit; onClicked: page.split() }
                NeonButton {
                    visible: Game.hasPerk("ghost")
                    width: parent.w; height: Theme.itemSizeSmall; text: "Fold"; color: Neon.violet
                    fontSize: Theme.fontSizeSmall
                    enabled: page.canSurrender
                    onClicked: page.surrender()
                }
            }
        }
        NeonButton {
            visible: page.phase === "bet" || page.phase === "dealing"
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            height: Theme.itemSizeMedium
            text: page.phase === "dealing" ? "Dealing…" : "Deal " + Money.fmt(bet.bet)
            color: Neon.cyan; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: page.phase === "bet" && Game.canBet(bet.bet)
            onClicked: page.deal()
        }
    }
}
