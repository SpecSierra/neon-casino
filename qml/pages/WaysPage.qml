import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Ways.js" as Ways
import "../js/WaysConfig.js" as Config
import "../js/Money.js" as Money

// NEURAL WAYS: 6 reels whose height changes every spin (2-7 rows, up to 117,649 ways).
// Pays left to right on adjacent reels; 4+ scatters start free spins with a multiplier that
// climbs +1 after every winning spin. Results are decided and saved before the reels move.
TablePage {
    id: page
    readonly property var m: Config.machine
    readonly property var mb: m.bonus
    title: "Neural ways"
    accent: m.color
    scene: "ways"
    code: "6 REELS · 2-7 ROWS · UP TO 117,649 WAYS"
    info: {
        var t = "Every spin each reel shows 2 to 7 symbols. A symbol pays when it lands on 3 or more reels in a row from the left; "
        t += "the win is multiplied by the number of ways (how many times it shows on each of those reels, multiplied together). "
        t += "∞ WILDs land on the middle reels.<br><br><b>Pays × bet per way (3 / 4 / 5 / 6 reels)</b><br>"
        var s = m.symbols.slice().reverse()
        for (var i = 0; i < s.length; ++i) t += s[i].toUpperCase() + ": " + m.pay[s[i]].map(function (v) { return +v.toFixed(3) }).join(" · ") + "<br>"
        t += "<br><b>Bonus</b><br>" + mb.scatters + "+ Ψ BONUS anywhere: " + mb.spins + " free spins (+" + mb.extraPerScatter + " each extra); "
        t += "the multiplier climbs +1 after every winning spin. Max win " + m.maxWin + "× bet. Buying the bonus costs " + (mb.buy || 30) + "× bet."
        return t
    }
    musicTrack: inBonus ? m.music + "_bonus" : m.music
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property bool inBonus: !!Game.slotBonus && Game.slotBonus.theme === "ways"
    property var bonus: Game.slotBonus
    property var grid: Ways.grid(m)
    property var lit: ({})               // "reel,row" -> true for winning cells
    property int reelsDone: 0
    property var outcome: null
    readonly property int ways: Ways.waysCount(grid)
    readonly property real buyCost: (mb.buy || 30) * bet.bet
    readonly property bool canBuy: !busy && !inBonus && Game.canBet(buyCost)
    property bool buyArmed: false
    Timer { id: disarm; interval: 3000; onTriggered: page.buyArmed = false }

    function spin() {
        if (busy || inBonus || !Game.canBet(bet.bet)) return
        busy = true
        var stake = bet.bet
        Game.stake(stake)
        var g = Ways.grid(m), ev = Ways.evaluate(m, g)
        var won = Math.round(ev.total * stake * 100) / 100
        if (ev.scatters >= mb.scatters) {
            Game.slotBonus = { theme: "ways", bet: stake, cost: stake, played: 0, mult: 1, won: won,
                               spins: mb.spins + mb.extraPerScatter * (ev.scatters - mb.scatters), fresh: true }
            Game.count("bonuses")
        } else {
            Game.pending = { game: "slots", staked: stake, returned: won }
        }
        Game.save()
        show(g, ev, won)
    }
    function freeSpin() {
        var b = JSON.parse(JSON.stringify(Game.slotBonus))
        bonus = b
        if (b.spins <= 0 || b.won >= m.maxWin * b.bet) { endBonus(); return }
        busy = true
        var g = Ways.grid(m), ev = Ways.evaluate(m, g)
        var won = Math.round(ev.total * b.bet * b.mult * 100) / 100
        b.lastMult = b.mult
        if (won > 0) b.mult += 1
        b.won = Math.min(m.maxWin * b.bet, Math.round((b.won + won) * 100) / 100)
        b.spins -= 1; b.played += 1; b.fresh = false
        b.retrig = ev.scatters >= mb.scatters
        if (b.retrig) { b.spins += mb.retrigger; Game.count("retriggers") }
        Game.slotBonus = b
        Game.save()
        show(g, ev, won)
    }
    function buyBonus() {
        if (!canBuy) return
        if (!buyArmed) { buyArmed = true; disarm.restart(); Haptics.tap(); return }
        buyArmed = false
        busy = true
        Game.stake(buyCost)
        Game.slotBonus = { theme: "ways", bet: bet.bet, cost: buyCost, played: 0, mult: 1, won: 0, spins: mb.spins, bought: true }
        Game.count("bonuses"); Game.count("bonusBuys")
        Game.save()
        bonus = Game.slotBonus
        Game.note("BONUS BOUGHT · " + mb.spins + " FREE SPINS", "#FF9F14")
        Sound.play("perk"); Haptics.rumble(6)
        nextTimer.interval = 1400; nextTimer.restart()
    }
    function endBonus() {
        var b = Game.slotBonus
        Game.slotBonus = null
        bonus = null
        busy = false
        page.burst.show(b.won, true)
        Game.best("bestBonusX", Math.round(b.won / b.bet))
        Game.settle(b.cost || b.bet, b.won, "slots")
    }

    // ---- presentation ----
    function show(g, ev, won) {
        lit = ({})
        outcome = { ev: ev, won: won }
        grid = g
        reelsDone = 0
        Sound.play("reel")
        for (var i = 0; i < reels.count; ++i) reels.itemAt(i).drop(i * 160)
    }
    function reelStopped() {
        Sound.play("tick"); Haptics.tick()
        if (++reelsDone < m.reels) return
        var l = {}, ev = outcome.ev
        for (var w = 0; w < ev.wins.length; ++w)
            for (var c = 0; c < ev.wins[w].cells.length; ++c) l[ev.wins[w].cells[c][0] + "," + ev.wins[w].cells[c][1]] = true
        lit = l
        if (ev.wins.length) {
            var best = ev.wins[0]
            for (w = 1; w < ev.wins.length; ++w) if (ev.wins[w].pay > best.pay) best = ev.wins[w]
            Game.note(best.n + " REELS · " + best.ways + " WAYS", m.color)
        }
        if (inBonus) {
            bonus = Game.slotBonus
            if (outcome.won > 0) { spinWinText.show(outcome.won); Sound.play(outcome.won >= bonus.bet * 20 ? "bigwin" : "win"); Haptics.win(outcome.won >= bonus.bet * 20) }
            if (bonus.fresh || bonus.retrig) {
                Game.note(bonus.fresh ? "BONUS · " + bonus.spins + " FREE SPINS" : "RETRIGGER +" + mb.retrigger, "#FF9F14")
                Sound.play("perk"); Haptics.rumble(5)
            }
            nextTimer.interval = bonus.fresh ? 1800 : (outcome.won > 0 ? 1300 : 800)
            nextTimer.restart()
            return
        }
        var p = Game.pending
        busy = false
        if (p.returned > 0) page.burst.show(p.returned, p.returned >= p.staked * 10)
        Game.settle(p.staked, p.returned, "slots")
    }
    Timer { id: nextTimer; onTriggered: page.freeSpin() }
    Component.onCompleted: if (inBonus) { busy = true; nextTimer.interval = 1200; nextTimer.restart() }

    // ways counter / bonus banner
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeMedium
        NeonText {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: Money.fmt(page.ways).slice(1) + " WAYS"
            color: page.m.color
            font.pixelSize: Theme.fontSizeMedium
            glow: 10
        }
        NeonText {
            visible: page.inBonus
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: page.bonus ? "×" + page.bonus.mult : ""
            color: page.bonus && page.bonus.mult >= 10 ? Neon.red : Neon.yellow
            font.pixelSize: Theme.fontSizeExtraLarge
            glow: 14
        }
    }
    Text {
        visible: page.inBonus
        x: Theme.horizontalPageMargin
        text: page.bonus ? "FREE SPINS · " + page.bonus.spins + " LEFT · +1× EVERY WIN · WON " + Money.fmt(page.bonus.won) : ""
        color: "#FF9F14"
        font { pixelSize: Theme.fontSizeExtraSmall; bold: true; letterSpacing: 1; family: Neon.display }
    }

    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: machine.height
        Lever {
            id: lever
            anchors { right: parent.right; top: machine.top; bottom: machine.bottom; topMargin: Theme.paddingSmall }
            color: page.inBonus ? "#FF9F14" : page.m.color
            armed: !page.busy && !page.inBonus && Game.canBet(bet.bet)
            onPulled: { Haptics.tap(); page.spin() }
        }
        NeonPanel {
            id: machine
            width: parent.width - lever.width - Theme.paddingSmall
            height: width * 1.05
            glowColor: page.inBonus ? "#FF9F14" : page.m.color
            glowStrength: page.inBonus ? 0.9 : 0.5
            Row {
                id: reelRow
                anchors { fill: parent; margins: Theme.paddingMedium }
                spacing: 3
                Repeater {
                    id: reels
                    model: page.m.reels
                    Item {
                        id: reel
                        width: (reelRow.width - (page.m.reels - 1) * 3) / page.m.reels
                        height: reelRow.height
                        clip: true
                        readonly property var col: page.grid[index] || []
                        readonly property real cellH: height / Math.max(1, col.length)
                        readonly property int reelIndex: index
                        property real offset: 0
                        signal done()
                        onDone: page.reelStopped()
                        function drop(delay) { offset = -height; dropAnim.delay = delay; dropAnim.restart() }
                        SequentialAnimation {
                            id: dropAnim
                            property int delay: 0
                            PauseAnimation { duration: dropAnim.delay }
                            NumberAnimation { target: reel; property: "offset"; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                            ScriptAction { script: reel.done() }
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.35)
                            border { width: 1; color: Neon.alpha(page.m.color, 0.4) }
                        }
                        Column {
                            y: reel.offset
                            width: parent.width
                            Repeater {
                                model: reel.col
                                Item {
                                    id: cellItem
                                    width: reel.width; height: reel.cellH
                                    readonly property bool hot: !!page.lit[reel.reelIndex + "," + index]
                                    Rectangle {
                                        anchors { fill: parent; margins: 2 }
                                        radius: 4
                                        visible: cellItem.hot
                                        color: Neon.alpha(page.m.color, 0.25)
                                        border { width: 2; color: Neon.yellow }
                                    }
                                    Image {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height) * 0.9; height: width
                                        source: "../images/sym-ways-" + modelData + ".png"
                                        SequentialAnimation on scale {
                                            running: cellItem.hot; loops: Animation.Infinite
                                            NumberAnimation { to: 1.15; duration: 350 } NumberAnimation { to: 1.0; duration: 350 }
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            text: reel.col.length
                            color: Neon.alpha(page.m.color, 0.6)
                            font { pixelSize: Theme.fontSizeTiny; bold: true }
                        }
                    }
                }
            }
            MouseArea {      // swipe down on the reels to spin
                anchors.fill: reelRow
                preventStealing: true
                property real y0
                property bool fired
                onPressed: { y0 = mouse.y; fired = false }
                onPositionChanged: if (!fired && mouse.y - y0 > Theme.itemSizeSmall) { fired = true; page.spin() }
            }
        }
    }
    NeonText {
        id: spinWinText
        anchors.horizontalCenter: parent.horizontalCenter
        color: Neon.green; glow: 12
        font.pixelSize: Theme.fontSizeLarge
        opacity: 0
        function show(v) { text = "+" + Money.fmt(v); fade.restart() }
        SequentialAnimation {
            id: fade
            NumberAnimation { target: spinWinText; property: "opacity"; to: 1; duration: 120 }
            PauseAnimation { duration: 800 }
            NumberAnimation { target: spinWinText; property: "opacity"; to: 0; duration: 300 }
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
                            : "Buy bonus · " + (page.mb.buy || 30) + "× bet · " + Money.fmt(page.buyCost)
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
            text: page.inBonus ? "Free spins…" : page.busy ? "Spinning…" : "Spin " + Money.fmt(bet.bet)
            color: page.m.color; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: !page.busy && !page.inBonus && Game.canBet(bet.bet)
            onClicked: page.spin()
        }
    }
}
