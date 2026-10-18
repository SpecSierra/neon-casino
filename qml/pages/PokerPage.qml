import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Poker.js" as Poker
import "../js/Money.js" as Money

// Jacks or Better (9/6). Deal 5, tap cards to hold, draw. After a win: collect, or play
// Double-or-Nothing up to 5 times (beat the dealer's card). The deck order is fixed at the
// deal and the whole hand is saved after every action, so quitting can't change the draw.
TablePage {
    id: page
    title: "Video poker"
    accent: Neon.violet
    scene: "poker"
    code: "JACKS OR BETTER · 9/6 · 99.5% RTP"
    musicTrack: "poker"
    footerHeight: footerCol.height + Theme.paddingLarge

    // bet | hold | won | double | dresult
    property string phase: "bet"
    property var deck: []
    property var hand: []
    property var held: [false, false, false, false, false]
    property real stake: 0
    property real win: 0                 // what's on the table right now
    property var result: null            // evaluate() of the final hand
    property var dbl: null               // { dealer, cards, pick, round }
    property string message: "BET, THEN DEAL"
    property color messageColor: Neon.violet
    busy: phase !== "bet"

    function save() {
        if (phase === "bet") { Game.poker = null }
        else Game.poker = { phase: phase, deck: deck, hand: hand, held: held, stake: stake, win: win, result: result, dbl: dbl }
        Game.save()
    }
    Component.onCompleted: {
        var p = Game.poker
        if (!p) return
        phase = p.phase; deck = p.deck; hand = p.hand; held = p.held; stake = p.stake; win = p.win; result = p.result; dbl = p.dbl
        message = "HAND RESUMED"; rebuild()
    }
    ListModel { id: cardsModel }
    function rebuild() {
        cardsModel.clear()
        for (var i = 0; i < hand.length; ++i) cardsModel.append({ rank: hand[i].rank, suit: hand[i].suit, up: true })
    }

    function deal() {
        if (phase !== "bet" || !Game.canBet(bet.bet)) return
        stake = bet.bet
        Game.stake(stake)
        deck = Poker.shuffled()
        hand = deck.splice(0, 5)
        held = [false, false, false, false, false]
        win = 0; result = null; dbl = null
        phase = "hold"
        var r = Poker.evaluate(hand, Game.perks)
        message = r ? r.name + " · HOLD AND DRAW" : "TAP CARDS TO HOLD"
        messageColor = r ? Neon.green : Neon.violet
        save()
        rebuild()
    }
    function toggle(i) {
        if (phase !== "hold") return
        var h = held.slice(); h[i] = !h[i]; held = h
        Sound.play("click"); Haptics.tick()
        save()
    }
    function draw() {
        if (phase !== "hold") return
        var h = hand.slice()
        for (var i = 0; i < 5; ++i) if (!held[i]) { h[i] = deck.shift(); cardsModel.set(i, { rank: h[i].rank, suit: h[i].suit, up: false }) }
        hand = h
        result = Poker.evaluate(hand, Game.perks)
        win = result ? Math.round(stake * result.pay * 100) / 100 : 0
        phase = win > 0 ? "won" : "bet"
        save()                                                // before the cards flip
        flipTimer.i = 0; flipTimer.start()
    }
    Timer {
        id: flipTimer
        property int i: 0
        interval: 140; repeat: true
        onTriggered: {
            while (i < 5 && cardsModel.get(i).up) ++i
            if (i < 5) { cardsModel.setProperty(i, "up", true); Sound.play("card"); ++i; return }
            stop()
            page.showResult()
        }
    }
    function showResult() {
        if (result) {
            message = result.name + " · " + Money.fmt(win)
            messageColor = Neon.green
            Game.count("poker_" + result.id)
            if (result.pay >= 25) { page.burst.show(win - stake, true) } else Sound.play("win")
            Haptics.win(result.pay >= 25)
        } else {
            message = "NO WIN"; messageColor = Neon.red
            Sound.play("lose")
            Game.settle(stake, 0, "poker")
            stake = 0
        }
        held = [false, false, false, false, false]
    }
    function collect() {
        if (phase !== "won" && phase !== "dresult") return
        var w = win, s = stake
        phase = "bet"; save()
        if (w > s) page.burst.show(w - s, w >= s * 10)
        Game.settle(s, w, "poker")
        message = "COLLECTED " + Money.fmt(w); messageColor = Neon.green
        stake = 0; win = 0
    }
    // Double-or-Nothing: dealer shows a card, you pick one of four. Higher doubles, equal pushes.
    function startDouble() {
        if (phase !== "won" && phase !== "dresult") return
        if (dbl && dbl.round >= 5) return
        var d = Poker.shuffled()
        dbl = { dealer: d[0], cards: d.slice(1, 5), pick: -1, round: dbl ? dbl.round + 1 : 1 }
        phase = "double"
        message = "BEAT THE DEALER · PICK A CARD"; messageColor = Neon.yellow
        save()
        Sound.play("card")
    }
    function pick(i) {
        if (phase !== "double") return
        var d = JSON.parse(JSON.stringify(dbl)); d.pick = i; dbl = d
        var a = Poker.rv(d.cards[i]), b = Poker.rv(d.dealer)
        if (a > b) { win = win * 2; message = "DOUBLED · " + Money.fmt(win); messageColor = Neon.green; Sound.play("win"); Haptics.win(false) }
        else if (a === b) { message = "PUSH · " + Money.fmt(win); messageColor = Neon.violet }
        else { win = 0; message = "LOST IT ALL"; messageColor = Neon.red; Sound.play("lose"); Haptics.rumble(2) }
        Game.count("doubleUps")
        if (win > 0) { phase = "dresult"; save() }
        else { phase = "bet"; save(); Game.settle(stake, 0, "poker"); stake = 0 }
    }

    // ---- paytable ----
    NeonPanel {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: payCol.height + 2 * Theme.paddingMedium
        glowColor: Neon.violet
        Column {
            id: payCol
            anchors { left: parent.left; right: parent.right; margins: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
            Repeater {
                model: Poker.table
                Item {
                    width: payCol.width; height: Theme.fontSizeSmall * 1.35
                    readonly property bool hit: page.result && page.result.id === modelData.id && page.phase !== "hold"
                    Rectangle { anchors.fill: parent; radius: 3; visible: parent.hit; color: Neon.alpha(Neon.yellow, 0.25) }
                    Text {
                        anchors { left: parent.left; leftMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
                        text: modelData.name
                        color: parent.hit ? Neon.yellow : Neon.alpha(Neon.violet, 0.9)
                        font { pixelSize: Theme.fontSizeExtraSmall; bold: true; letterSpacing: 1; family: Neon.display }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
                        text: Money.fmt((modelData.id === "full" && Game.hasPerk("fullhouse") ? 10 : modelData.pay) * (page.stake || bet.bet))
                        color: parent.hit ? Neon.yellow : Neon.alpha(Neon.cyan, 0.85)
                        font { pixelSize: Theme.fontSizeExtraSmall; bold: true; family: Neon.display }
                    }
                }
            }
        }
    }
    NeonText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: page.message
        color: page.messageColor
        font.pixelSize: Theme.fontSizeSmall
        glow: 10
    }

    // ---- the hand ----
    Row {
        visible: page.phase !== "double" && page.phase !== "dresult"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.paddingSmall
        height: cardW * 1.42 + Theme.itemSizeExtraSmall
        property real cardW: (page.width - 2 * Theme.horizontalPageMargin - 4 * Theme.paddingSmall) / 5
        Repeater {
            model: cardsModel
            MouseArea {
                width: parent.cardW; height: parent.height
                onClicked: page.toggle(index)
                CardItem {
                    width: parent.width
                    y: page.held[index] ? 0 : Theme.paddingLarge
                    Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    rank: model.rank; suit: model.suit; faceUp: model.up
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                    text: "HELD"
                    visible: page.held[index]
                    color: Neon.yellow
                    font { pixelSize: Theme.fontSizeSmall; bold: true; letterSpacing: 2; family: Neon.display }
                }
            }
        }
    }
    // ---- double-up ----
    Column {
        visible: page.phase === "double" || page.phase === "dresult"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.paddingMedium
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ROUND " + (page.dbl ? page.dbl.round : 0) + "/5 · " + Money.fmt(page.win) + " ON THE LINE"
            color: Neon.yellow
            font { pixelSize: Theme.fontSizeTiny; bold: true; letterSpacing: 1; family: Neon.display }
        }
        Row {
            spacing: Theme.paddingSmall
            property real cardW: (page.width - 2 * Theme.horizontalPageMargin - 4 * Theme.paddingSmall) / 5
            CardItem {
                width: parent.cardW
                rank: page.dbl ? page.dbl.dealer.rank : ""; suit: page.dbl ? page.dbl.dealer.suit : ""
                faceUp: true
            }
            Repeater {
                model: 4
                MouseArea {
                    width: parent.cardW; height: width * 1.42
                    onClicked: page.pick(index)
                    CardItem {
                        anchors.fill: parent
                        rank: page.dbl ? page.dbl.cards[index].rank : ""; suit: page.dbl ? page.dbl.cards[index].suit : ""
                        faceUp: !!page.dbl && page.dbl.pick >= 0 && (page.dbl.pick === index || page.phase !== "double")
                        opacity: page.dbl && page.dbl.pick >= 0 && page.dbl.pick !== index ? 0.45 : 1
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "DEALER  ·  PICK ONE OF FOUR"
            color: Neon.alpha(Neon.violet, 0.8)
            font { pixelSize: Theme.fontSizeTiny; letterSpacing: 2; family: Neon.display }
        }
    }
    Label {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        wrapMode: Text.Wrap
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.secondaryColor
        text: "Jacks or Better, full-pay 9/6 table: about 99.5% back with perfect play. Tap cards to hold them, then draw. "
              + "After a win, collect it or risk it on Double or Nothing: beat the dealer's card (aces high) to double, "
              + "tie to keep it, up to 5 times in a row."
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        BetSelector { id: bet; width: parent.width; locked: page.busy; color: Neon.yellow; visible: page.phase === "bet" }
        NeonButton {
            visible: page.phase === "bet" || page.phase === "hold"
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            height: Theme.itemSizeMedium
            text: page.phase === "hold" ? "Draw" : "Deal " + Money.fmt(bet.bet)
            color: page.phase === "hold" ? Neon.green : Neon.violet
            primary: true
            fontSize: Theme.fontSizeLarge
            enabled: page.phase === "hold" || Game.canBet(bet.bet)
            onClicked: page.phase === "hold" ? page.draw() : page.deal()
        }
        Row {
            visible: page.phase === "won" || page.phase === "dresult"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            property real w: (page.width - 2 * Theme.horizontalPageMargin - spacing) / 2
            NeonButton { width: parent.w; height: Theme.itemSizeMedium; text: "Take " + Money.fmt(page.win); color: Neon.green; primary: true; fontSize: Theme.fontSizeExtraSmall; onClicked: page.collect() }
            NeonButton {
                width: parent.w; height: Theme.itemSizeMedium; text: "Double up"; color: Neon.yellow; fontSize: Theme.fontSizeExtraSmall
                enabled: !page.dbl || page.dbl.round < 5
                onClicked: page.startDouble()
            }
        }
        Item { visible: page.phase === "double"; width: 1; height: Theme.itemSizeMedium }
    }
}
