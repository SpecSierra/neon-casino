import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Cascade.js" as Cascade
import "../js/CascadeConfig.js" as Config
import "../js/Money.js" as Money

// CHAIN REACTION: connect 3+ gems; clusters explode, gems fall, the multiplier doubles
// with every chain. The whole spin is decided and saved first, then animated.
TablePage {
    id: page
    readonly property var m: Config.machine
    title: "Chain reaction"
    accent: m.color
    musicTrack: inBonus ? m.music + "_bonus" : m.music
    scene: "cascade"
    code: "5×5 · CONNECT 3+ · CHAIN ×2 PER DROP"
    info: {
        var t = "Groups of 3 or more touching gems (up, down, left, right) pay and explode; the gems above fall and new ones drop in. "
        t += "Each chain doubles the multiplier, up to ×" + m.multCap + ". Max win " + m.maxWin + "× the bet. Swipe down on the grid to drop.<br><br>"
        t += "<b>Pays × bet for a group of 3</b> (4: ×2.5 · 5: ×6 · 6: ×12 · 7: ×25 · 8: ×50 · 9: ×100 · 10+: ×200)<br>"
        var g = m.gems.slice().reverse()
        for (var i = 0; i < g.length; ++i) t += g[i].toUpperCase() + ": " + m.base[g[i]] + "×<br>"
        t += "<br><b>Bonus</b><br>BONUS cores never match. " + mb.cores + "+ cores on the settled board start " + mb.spins + " free drops (+"
        t += mb.extraPerCore + " per extra core); there the multiplier rises +1 every chain and never resets. " + mb.cores + "+ cores again add "
        t += mb.retrigger + " drops. Buying the bonus costs " + (mb.buy || 20) + "× bet."
        return t
    }
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property real cell: (width - 2 * Theme.horizontalPageMargin - 2 * Theme.paddingMedium - lever.width - Theme.paddingSmall) / m.cols
    // free spins (saved in Game.slotBonus with theme "cascade"): { bet, cost, spins, mult, played, won }
    readonly property bool inBonus: !!Game.slotBonus && Game.slotBonus.theme === "cascade"
    property var bonus: Game.slotBonus
    readonly property var mb: m.bonus
    readonly property real buyCost: (mb.buy || 20) * bet.bet
    readonly property bool canBuy: !busy && !inBonus && Game.canBet(buyCost)
    property bool buyArmed: false
    Timer { id: disarm; interval: 3000; onTriggered: page.buyArmed = false }
    property var result: null
    property int stepIndex: -1
    property int chainMult: 1
    property real spinWin: 0
    property int uidSeq: 0

    ListModel { id: tiles }      // { uid, gem, col, row, drop, delay, dying, hot }

    function addTile(gem, col, row, drop, delay) {
        tiles.append({ uid: ++uidSeq, gem: gem, col: col, row: row, drop: drop, delay: delay, dying: false, hot: false })
    }
    function fillFresh(grid) {
        tiles.clear()
        for (var c = 0; c < m.cols; ++c)
            for (var r = 0; r < m.rows; ++r)
                addTile(grid[c][r], c, r, m.rows + 1, c * 70 + (m.rows - r) * 25)
    }
    Component.onCompleted: {
        // decorative opening board without any 3-matches (they wouldn't pay)
        var g
        do {
            g = []
            for (var c = 0; c < m.cols; ++c) { var col = []; for (var r = 0; r < m.rows; ++r) col.push(Cascade.drawGem(m)); g.push(col) }
        } while (Cascade.clusters(m, g).length)
        fillFresh(g)
        if (inBonus) { busy = true; bonusTimer.interval = 1200; bonusTimer.restart() }   // resume a saved bonus
    }

    function spin() {
        if (busy || inBonus || !Game.canBet(bet.bet)) return
        busy = true
        var stake = bet.bet
        Game.stake(stake)
        result = Cascade.play(m, stake)
        if (result.cores >= mb.cores) {
            // the drop's own win rides into the bonus; everything settles when it ends
            Game.slotBonus = { theme: "cascade", bet: stake, cost: stake, played: 0, mult: 1, won: result.total,
                               spins: mb.spins + mb.extraPerCore * (result.cores - mb.cores) }
            Game.count("bonuses")
        } else {
            Game.pending = { game: "slots", staked: stake, returned: result.total }
        }
        Game.save()                                   // decided before anything falls
        animate()
    }
    function animate() {
        spinWin = 0; stepIndex = -1
        chainMult = inBonus ? bonus.mult : 1
        Sound.play("reel"); Haptics.tap()
        fillFresh(result.start)
        seq.phase = "settle"; seq.interval = 1100; seq.restart()
    }
    function buyBonus() {
        if (!canBuy) return
        if (!buyArmed) { buyArmed = true; disarm.restart(); Haptics.tap(); return }
        buyArmed = false
        busy = true
        Game.stake(buyCost)
        Game.slotBonus = { theme: "cascade", bet: bet.bet, cost: buyCost, played: 0, mult: 1, won: 0, spins: mb.spins, bought: true }
        Game.count("bonuses"); Game.count("bonusBuys")
        Game.save()
        bonus = Game.slotBonus
        Game.note("BONUS BOUGHT · " + mb.spins + " FREE DROPS", "#FF9F14")
        Sound.play("perk"); Haptics.rumble(6)
        bonusTimer.interval = 1500; bonusTimer.restart()
    }
    // one free drop: decided and saved, then animated
    function freeSpin() {
        var b = JSON.parse(JSON.stringify(Game.slotBonus))
        bonus = b
        if (b.spins <= 0 || b.won >= m.maxWin * b.bet) { endBonus(); return }
        busy = true
        result = Cascade.play(m, b.bet, b.mult)
        b.mult = result.bonusMult
        b.won = Math.min(m.maxWin * b.bet, Math.round((b.won + result.total) * 100) / 100)
        b.spins -= 1; b.played += 1
        b.retrig = result.cores >= mb.cores
        if (b.retrig) { b.spins += mb.retrigger; Game.count("retriggers") }
        Game.slotBonus = b
        Game.save()
        animate()
    }
    function endBonus() {
        var b = Game.slotBonus
        Game.slotBonus = null
        bonus = null
        busy = false
        chainMult = 1
        page.burst.show(b.won, true)
        Game.best("bestBonusX", Math.round(b.won / b.bet))
        Game.settle(b.cost || b.bet, b.won, "slots")
    }
    Timer { id: bonusTimer; onTriggered: page.freeSpin() }

    function tileAt(c, r) {
        for (var i = 0; i < tiles.count; ++i) {
            var t = tiles.get(i)
            if (t.col === c && t.row === r && !t.dying) return i
        }
        return -1
    }

    // chain steps: show → explode → fall → next
    Timer {
        id: seq
        property string phase: ""
        onTriggered: {
            var st, i, j
            if (phase === "settle") {
                stepIndex = 0
                if (!result.steps.length) { page.finish(); return }
                phase = "show"; interval = 10; restart()
            } else if (phase === "show") {
                st = result.steps[stepIndex]
                chainMult = st.mult
                for (i = 0; i < st.clusters.length; ++i)
                    for (j = 0; j < st.clusters[i].cells.length; ++j) {
                        var idx = tileAt(st.clusters[i].cells[j][0], st.clusters[i].cells[j][1])
                        if (idx >= 0) tiles.setProperty(idx, "hot", true)
                    }
                spinWin = Math.round((spinWin + st.win) * 100) / 100
                if (page.inBonus) page.chainMult = st.mult
                Sound.play(stepIndex === 0 ? "win" : "tick"); Haptics.tick()
                if (stepIndex > 0) { Game.note("CHAIN ×" + st.mult + "  +" + Money.fmt(st.win), m.color); Haptics.tap() }
                phase = "explode"; interval = 520; restart()
            } else if (phase === "explode") {
                for (i = 0; i < tiles.count; ++i) if (tiles.get(i).hot) tiles.setProperty(i, "dying", true)
                Sound.play("card")
                phase = "fall"; interval = 260; restart()
            } else if (phase === "fall") {
                st = result.steps[stepIndex]
                for (i = tiles.count - 1; i >= 0; --i) if (tiles.get(i).dying) tiles.remove(i)
                for (var c = 0; c < m.cols; ++c) {
                    // survivors in this column, top to bottom, slide down to the bottom
                    var col = []
                    for (i = 0; i < tiles.count; ++i) if (tiles.get(i).col === c) col.push({ idx: i, row: tiles.get(i).row })
                    col.sort(function (a, b) { return a.row - b.row })
                    var fresh = st.refill[c]
                    for (j = 0; j < col.length; ++j) tiles.setProperty(col[j].idx, "row", fresh.length + j)
                    for (j = 0; j < fresh.length; ++j) addTile(fresh[j], c, j, fresh.length + 1, c * 40)
                }
                stepIndex += 1
                if (stepIndex >= result.steps.length) { phase = "end"; interval = 650 }
                else { phase = "show"; interval = 650 }
                restart()
            } else if (phase === "end") {
                page.finish()
            }
        }
    }
    function finish() {
        Game.count("chains", Math.max(0, result.steps.length - 1))
        Game.best("longestChain", result.steps.length)
        if (inBonus) {
            bonus = Game.slotBonus
            if (result.total > 0) Sound.play(result.total >= bonus.bet * 20 ? "bigwin" : "win")
            if (bonus.played === 0 || bonus.retrig) {
                Game.note(bonus.played === 0 ? "BONUS · " + bonus.spins + " FREE DROPS" : "RETRIGGER +" + mb.retrigger, "#FF9F14")
                Sound.play("perk"); Haptics.rumble(5)
            }
            bonusTimer.interval = bonus.played === 0 ? 1800 : 1100
            bonusTimer.restart()
            return
        }
        var p = Game.pending
        busy = false
        if (result.capped) Game.note("MAX WIN " + m.maxWin + "×", Neon.yellow)
        if (p.returned > 0) page.burst.show(p.returned, p.returned >= p.staked * 10)
        Game.settle(p.staked, p.returned, "slots")
    }

    // ---- chain multiplier + spin win ----
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeMedium
        NeonText {
            id: multBadge
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "CHAIN ×" + page.chainMult
            color: page.chainMult >= 16 ? Neon.red : page.chainMult >= 4 ? Neon.yellow : page.m.color
            font.pixelSize: Theme.fontSizeLarge
            glow: 12
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 } }
        }
        Connections {
            target: page
            onChainMultChanged: { multBadge.scale = 1.4; bounceBack.restart() }
        }
        Timer { id: bounceBack; interval: 160; onTriggered: multBadge.scale = 1 }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: page.spinWin > 0 ? "WIN " + Money.fmt(page.spinWin) : "CONNECT 3+"
            color: page.spinWin > 0 ? Neon.green : Neon.alpha(page.m.color, 0.7)
            font { pixelSize: Theme.fontSizeSmall; bold: true; letterSpacing: 2; family: Neon.display }
        }
    }

    // ---- the grid ----
    // free-drop banner
    NeonPanel {
        visible: page.inBonus
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: visible ? Theme.itemSizeMedium : 0
        glowColor: "#FF9F14"; glowStrength: 0.8; strong: true
        Column {
            anchors { left: parent.left; leftMargin: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
            NeonText { text: "FREE DROPS"; color: "#FF9F14"; glow: 8 }
            Text {
                text: page.bonus ? page.bonus.spins + " LEFT · MULTIPLIER NEVER RESETS · WON " + Money.fmt(page.bonus.won) : ""
                color: Neon.alpha("#FF9F14", 0.85)
                font { pixelSize: Theme.fontSizeTiny; letterSpacing: 1; family: Neon.display }
            }
        }
    }
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: board.height
    Lever {
        id: lever
        anchors { right: parent.right; top: board.top; bottom: board.bottom; topMargin: Theme.paddingSmall }
        color: page.inBonus ? "#FF9F14" : page.m.color
        armed: !page.busy && !page.inBonus && Game.canBet(bet.bet)
        onPulled: { Haptics.tap(); page.spin() }
    }
    NeonPanel {
        id: board
        width: parent.width - lever.width - Theme.paddingSmall
        height: width
        glowColor: page.m.color
        glowStrength: page.chainMult > 1 ? 0.95 : 0.5
        Behavior on glowStrength { NumberAnimation { duration: 300 } }
        Item {
            id: well
            anchors { fill: parent; margins: Theme.paddingMedium }
            clip: true
            Repeater {
                model: tiles
                Item {
                    id: tile
                    width: page.cell; height: page.cell
                    x: model.col * page.cell
                    // y is always bound to the row; `lift` (in cells) is the part still to fall
                    property int r: model.row
                    property int lastR: model.row
                    property real lift: model.drop
                    y: (r - lift) * page.cell
                    Component.onCompleted: dropIn.start()
                    onRChanged: { dropIn.stop(); lift = r - lastR + lift; lastR = r; fallOnly.restart() }
                    SequentialAnimation {
                        id: dropIn
                        PauseAnimation { duration: model.delay }
                        NumberAnimation { target: tile; property: "lift"; to: 0; duration: 380; easing.type: Easing.OutBounce }
                    }
                    NumberAnimation {
                        id: fallOnly
                        target: tile; property: "lift"; to: 0; duration: 380; easing.type: Easing.OutBounce
                    }
                    Rectangle {
                        anchors { fill: parent; margins: 3 }
                        radius: 6
                        color: Neon.alpha(page.m.color, model.hot ? 0.35 : 0.06)
                        border { width: model.hot ? 2 : 1; color: model.hot ? Neon.yellow : Neon.alpha(page.m.color, 0.25) }
                    }
                    Image {
                        id: gemImg
                        anchors { fill: parent; margins: page.cell * 0.08 }
                        source: "../images/gem-" + model.gem + ".png"
                        smooth: true
                        scale: model.dying ? 1.6 : 1
                        opacity: model.dying ? 0 : 1
                        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 240 } }
                        SequentialAnimation on rotation {
                            running: model.hot && !model.dying; loops: Animation.Infinite
                            NumberAnimation { to: 8; duration: 90 } NumberAnimation { to: -8; duration: 180 } NumberAnimation { to: 0; duration: 90 }
                        }
                    }
                }
            }
            // swipe down on the grid to spin
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                property real y0
                property bool fired: false
                onPressed: { y0 = mouse.y; fired = false }
                onPositionChanged: if (!fired && mouse.y - y0 > Theme.itemSizeSmall) { fired = true; page.spin() }
            }
        }
    }

    }

    NeonButton {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeSmall
        color: "#FF9F14"
        primary: page.buyArmed
        enabled: page.canBuy
        fontSize: Theme.fontSizeSmall
        text: page.buyArmed ? "Tap again to buy · " + Money.fmt(page.buyCost)
                            : "Buy bonus · " + (page.mb.buy || 20) + "× bet · " + Money.fmt(page.buyCost)
        onClicked: page.buyBonus()
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
            text: page.inBonus ? "Free drops…" : page.busy ? (page.chainMult > 1 ? "Chain ×" + page.chainMult + "…" : "Dropping…") : "Drop " + Money.fmt(bet.bet)
            color: page.m.color; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: !page.busy && Game.canBet(bet.bet)
            onClicked: page.spin()
        }
    }
}
