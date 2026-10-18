import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Baccarat.js" as Bac
import "../js/Money.js" as Money

// Punto banco. Bet Player, Banker, Tie and the pair side bets, then deal. Cards land face
// down: tap one to squeeze it open, or let it turn by itself. The coup is decided and saved
// at the deal.
TablePage {
    id: page
    title: "Baccarat"
    accent: "#FFC828"
    scene: "baccarat"
    code: "8 DECKS · PUNTO BANCO · TAP TO SQUEEZE"
    musicTrack: "baccarat"
    footerHeight: footerCol.height + Theme.paddingLarge

    property var shoe: Bac.newShoe()
    property var bets: ({})
    property var lastBets: ({})
    property var coup: null
    property var road: []                     // bead road: "P" | "B" | "T", oldest first
    property int chipIndex: 0
    property string phase: "bet"              // bet | deal | done
    property int revealStep: 0
    readonly property real total: sum(bets)
    busy: phase === "deal"

    readonly property var chipValues: {
        var b = Game.balance, out = [], fr = [0.01, 0.05, 0.2, 0.5]
        for (var i = 0; i < fr.length; ++i) { var v = Math.max(Game.minBet, niceFloor(b * fr[i])); if (out.indexOf(v) < 0) out.push(v) }
        return out
    }
    readonly property real chip: chipValues[Math.min(chipIndex, chipValues.length - 1)]
    function niceFloor(v) {
        if (v < 1) return 1
        var p = Math.pow(10, Math.floor(Math.log(v) / Math.LN10 + 1e-9)), steps = p >= 10 ? [5, 2.5, 2, 1] : [5, 2, 1]
        for (var i = 0; i < steps.length; ++i) if (steps[i] * p <= v + 1e-9) return steps[i] * p
        return p
    }
    function sum(b) { var t = 0; for (var k in b) t += b[k]; return t }
    function place(key) {
        if (busy) return
        if (total + chip > Game.balance + 1e-9) { Game.note("NOT ENOUGH CREDITS", Neon.red); return }
        if (phase === "done") { phase = "bet"; coup = null; pModel.clear(); bModel.clear() }
        var b = {}; for (var k in bets) b[k] = bets[k]
        b[key] = (b[key] || 0) + chip
        bets = b
        Sound.play("tick"); Haptics.tick()
    }
    function clearSpot(key) { if (busy || !bets[key]) return; var b = {}; for (var k in bets) if (k !== key) b[k] = bets[k]; bets = b }

    function deal() {
        if (busy || total < Game.minBet || total > Game.balance + 1e-9) return
        if (shoe.length < 16) { shoe = Bac.newShoe(); Game.note("NEW SHOE", "#FFC828") }
        lastBets = bets
        Game.stake(total)
        var c = Bac.coup(shoe), returned = 0
        for (var k in bets) returned += Bac.payout(k, bets[k], c, Game.perks)
        coup = c
        Game.pending = { game: "baccarat", staked: total, returned: Math.round(returned * 100) / 100 }
        Game.save()                                     // decided before the first card turns
        pModel.clear(); bModel.clear()
        phase = "deal"
        revealStep = 0
        dealer.restart()
    }
    ListModel { id: pModel }
    ListModel { id: bModel }
    // deal P, B, P, B face down, then reveal in order; third cards follow the tableau
    Timer {
        id: dealer
        interval: 380; repeat: true
        onTriggered: {
            var c = page.coup, s = page.revealStep
            if (s < 4) {
                var m = s % 2 ? bModel : pModel, h = s % 2 ? c.banker : c.player
                var card = h[Math.floor(s / 2)]
                m.append({ rank: card.rank, suit: card.suit, up: false })
                page.revealStep++
                return
            }
            stop()
            autoFlip.which = 0; autoFlip.restart()
        }
    }
    // reveal order: P1, B1, P2, B2, then P3 / B3 (each also opens on tap)
    property var revealOrder: []
    Timer {
        id: autoFlip
        property int which: 0
        interval: 600
        onTriggered: page.revealNext()
    }
    function nextHidden() {
        var order = [[pModel, 0], [bModel, 0], [pModel, 1], [bModel, 1], [pModel, 2], [bModel, 2]]
        for (var i = 0; i < order.length; ++i) if (order[i][0].count > order[i][1] && !order[i][0].get(order[i][1]).up) return order[i]
        return null
    }
    function revealNext() {
        var n = nextHidden()
        if (n) { flipCard(n[0], n[1]); return }
        // all visible: third cards?
        if (pModel.count < coup.player.length) { var c3 = coup.player[2]; pModel.append({ rank: c3.rank, suit: c3.suit, up: false }); Game.note("PLAYER DRAWS", Neon.cyan); autoFlip.restart(); return }
        if (bModel.count < coup.banker.length) { var b3 = coup.banker[2]; bModel.append({ rank: b3.rank, suit: b3.suit, up: false }); Game.note("BANKER DRAWS", Neon.red); autoFlip.restart(); return }
        finish()
    }
    function flipCard(model, i) {
        model.setProperty(i, "up", true)
        Sound.play("card"); Haptics.tick()
        // quick for the first four, a beat of suspense before a third card shows
        autoFlip.interval = i >= 1 && model === bModel ? 900 : 450
        autoFlip.restart()
    }
    function tapCard(model, i) {
        if (phase !== "deal" || model.get(i).up) return
        var n = nextHidden()
        if (n && n[0] === model && n[1] === i) flipCard(model, i)
    }
    function handTotal(model) {
        var h = []; for (var i = 0; i < model.count; ++i) if (model.get(i).up) h.push(model.get(i))
        return Bac.total(h)
    }
    function finish() {
        phase = "done"
        var p = Game.pending
        road = road.concat([coup.winner]).slice(-36)
        Game.count("baccarat_" + coup.winner)
        if (coup.ppair || coup.bpair) Game.count("baccaratPairs")
        if (p.returned > p.staked) page.burst.show(p.returned - p.staked, p.returned >= p.staked * 5)
        else if (p.returned < p.staked) Sound.play("lose")
        bets = ({})
        Game.settle(p.staked, p.returned, "baccarat")
    }
    function chipLabel(v) {
        if (v >= 1e9) return +(v / 1e9).toFixed(1) + "B"
        if (v >= 1e6) return +(v / 1e6).toFixed(1) + "M"
        if (v >= 1e3) return +(v / 1e3).toFixed(1) + "K"
        return String(v)
    }

    // ---- table ----
    NeonPanel {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: tableCol.height + 2 * Theme.paddingMedium
        glowColor: "#FFC828"
        Column {
            id: tableCol
            anchors { left: parent.left; right: parent.right; margins: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
            spacing: Theme.paddingSmall
            Row {
                width: parent.width
                Repeater {
                    model: [{ m: pModel, name: "PLAYER", color: Neon.cyan, side: "P" }, { m: bModel, name: "BANKER", color: Neon.red, side: "B" }]
                    Column {
                        id: handCol
                        width: tableCol.width / 2
                        spacing: Theme.paddingSmall
                        readonly property var hm: modelData.m
                        readonly property bool winner: page.phase === "done" && page.coup && page.coup.winner === modelData.side
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.name + (handCol.hm.count ? "  " + page.handTotal(handCol.hm) : "")
                            color: handCol.winner ? Neon.yellow : modelData.color
                            font { pixelSize: Theme.fontSizeSmall; bold: true; letterSpacing: 2; family: Neon.display }
                        }
                        Item {
                            width: parent.width; height: cardProto.height
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: -cardProto.width * 0.4
                                Repeater {
                                    model: handCol.hm
                                    MouseArea {
                                        width: cardProto.width; height: cardProto.height
                                        rotation: index === 2 ? 90 : 0                 // third card dealt sideways
                                        onClicked: page.tapCard(handCol.hm, index)
                                        CardItem { anchors.fill: parent; rank: model.rank; suit: model.suit; faceUp: model.up }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            NeonText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.phase === "done" && page.coup ? (page.coup.winner === "T" ? "TIE" : page.coup.winner === "P" ? "PLAYER WINS" : "BANKER WINS")
                      : page.phase === "deal" ? "TAP A CARD TO SQUEEZE" : "PLACE YOUR BETS"
                color: page.phase === "done" && page.coup ? (page.coup.winner === "T" ? Neon.green : page.coup.winner === "P" ? Neon.cyan : Neon.red) : "#FFC828"
                font.pixelSize: Theme.fontSizeMedium
                glow: 10
            }
        }
        CardItem { id: cardProto; visible: false; animateIn: false; width: Theme.itemSizeLarge * 0.85 }
    }

    // ---- betting spots ----
    Grid {
        id: spots
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        columns: 3
        spacing: Theme.paddingSmall
        property real w: (width - 2 * spacing) / 3
        Repeater {
            model: [
                { key: "ppair", label: "P PAIR 11:1", color: Neon.cyan },
                { key: "tie", label: "TIE 8:1", color: Neon.green },
                { key: "bpair", label: "B PAIR 11:1", color: Neon.red },
                { key: "player", label: "PLAYER 1:1", color: Neon.cyan },
                { key: "", label: "", color: "transparent" },
                { key: "banker", label: Game.hasPerk("commission") ? "BANKER 0.975:1" : "BANKER 0.95:1", color: Neon.red }
            ]
            MouseArea {
                width: spots.w; height: modelData.key === "player" || modelData.key === "banker" ? Theme.itemSizeLarge : Theme.itemSizeSmall
                enabled: modelData.key !== ""
                readonly property real amount: page.bets[modelData.key] || 0
                onClicked: page.place(modelData.key)
                onPressAndHold: page.clearSpot(modelData.key)
                Rectangle {
                    anchors.fill: parent
                    visible: modelData.key !== ""
                    radius: 6
                    color: Neon.alpha(modelData.color, parent.pressed ? 0.45 : (parent.amount > 0 ? 0.3 : 0.12))
                    border { width: 2; color: Neon.alpha(modelData.color, 0.85) }
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: "white"
                    font { pixelSize: Theme.fontSizeExtraSmall; bold: true; family: Neon.display }
                }
                Rectangle {
                    visible: parent.amount > 0
                    anchors { right: parent.right; top: parent.top; margins: 4 }
                    height: Theme.iconSizeSmall; width: Math.max(height, chipT.implicitWidth + 10); radius: height / 2
                    color: Neon.yellow
                    Text { id: chipT; anchors.centerIn: parent; text: page.chipLabel(parent.parent.amount); color: Neon.ink; font { pixelSize: Theme.fontSizeTiny; bold: true } }
                }
            }
        }
    }
    // bead road
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: roadGrid.height
        Grid {
            id: roadGrid
            rows: 6
            flow: Grid.TopToBottom
            spacing: 3
            Repeater {
                model: page.road
                Rectangle {
                    width: Theme.paddingLarge * 1.2; height: width; radius: width / 2
                    color: Neon.alpha(modelData === "P" ? Neon.cyan : modelData === "B" ? Neon.red : Neon.green, 0.35)
                    border { width: 1; color: modelData === "P" ? Neon.cyan : modelData === "B" ? Neon.red : Neon.green }
                    Text { anchors.centerIn: parent; text: modelData; color: "white"; font { pixelSize: Theme.fontSizeTiny * 0.8; bold: true } }
                }
            }
        }
    }
    Label {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        wrapMode: Text.Wrap
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.secondaryColor
        text: "Closest to 9 wins (tens and faces count 0). The third-card rules are automatic. Banker pays 1:1 minus "
              + (Game.hasPerk("commission") ? "2.5%" : "5%") + " commission, Player 1:1, Tie 8:1 (Player and Banker bets push on a tie), "
              + "pairs 11:1 when the first two cards of that hand match. Tap to add a chip, hold to clear a spot."
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingMedium
            Repeater {
                model: page.chipValues
                MouseArea {
                    width: Theme.itemSizeSmall; height: width
                    onClicked: { page.chipIndex = index; Sound.play("click"); Haptics.tick() }
                    Image {
                        anchors.fill: parent; source: "../images/sym-chip.png"
                        opacity: index === page.chipIndex ? 1 : 0.45
                        scale: index === page.chipIndex ? 1.1 : 0.9
                    }
                    Text { anchors.centerIn: parent; text: page.chipLabel(modelData); color: "white"; font { pixelSize: Theme.fontSizeExtraSmall; bold: true; family: Neon.display } }
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            height: Theme.itemSizeMedium
            property real w: (page.width - 2 * Theme.horizontalPageMargin - 2 * spacing) / 4
            NeonButton { width: parent.w; height: parent.height; text: "Clear"; color: Neon.violet; fontSize: Theme.fontSizeSmall; enabled: !page.busy && page.total > 0; onClicked: page.bets = ({}) }
            NeonButton {
                width: parent.w; height: parent.height; text: "Rebet"; color: Neon.cyan; fontSize: Theme.fontSizeSmall
                enabled: !page.busy && page.sum(page.lastBets) > 0 && page.sum(page.lastBets) <= Game.balance
                onClicked: { page.bets = page.lastBets; if (page.phase === "done") { page.phase = "bet"; pModel.clear(); bModel.clear() } }
            }
            NeonButton {
                width: parent.w * 2; height: parent.height
                text: page.busy ? "Dealing…" : "Deal " + Money.fmt(page.total)
                color: "#FFC828"; primary: true
                enabled: !page.busy && page.total >= Game.minBet && page.total <= Game.balance + 1e-9 && Game.canBet(Game.minBet)
                onClicked: page.deal()
            }
        }
    }
}
