import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/VoidConfig.js" as Config
import "../js/Void.js" as Void
import "../js/Money.js" as Money

// VOID RUNNER: infinity reels. Ways pay from the left; a win that reaches the last reel opens a
// new reel, which spins on its own; every new reel adds +1 to the multiplier. 3+ portals: free
// spins where the multiplier never resets. The whole chain is decided and saved before the
// first reel moves; the page just reveals it reel by reel.
TablePage {
    id: page
    title: "Void runner"
    accent: m.color
    scene: "void"
    musicTrack: inBonus ? "void_bonus" : "void"
    code: "INFINITY REELS · EVERY NEW REEL +1× · MAX " + m.bonus.maxWin + "×"
    info: "Wins pay ways from the left on 3 or more adjacent reels; the wild (∞) substitutes from reel 2 on.<br>"
          + "If a win reaches the LAST reel, a new reel opens and spins. Wins are recounted, and the spin's multiplier goes up by 1 "
          + "for every reel that opened (up to " + m.maxReels + " reels).<br>"
          + "Pays per way, × your bet, × (length − 2): " + m.symbols.map(function (s) { return s + " " + m.base[s] }).join(" · ") + ".<br>"
          + m.bonus.portals + "+ portals anywhere: " + m.bonus.spins + " FREE SPINS where the multiplier keeps every reel that opens "
          + "(+" + m.bonus.retrigger + " spins on a retrigger). Max win " + m.bonus.maxWin + "× per spin and per bonus. RTP about 95%."
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property var m: Config.machine
    readonly property var reelTheme: ({ prefix: m.prefix, symbols: m.symbols, weights: m.weights, bonus: { scatter: 0, bonusScatter: 0 } })
    readonly property bool inBonus: !!Game.slotBonus && Game.slotBonus.theme === "void"
    property var bonus: Game.slotBonus
    property int reelCount: m.start
    property var result: null            // the decided spin
    property real won: 0
    property int shownMult: 1
    property int reelsDone: 0
    property bool busyReels: false
    busy: busyReels || inBonus

    function spin() {
        if (busy || !Game.canBet(bet.bet)) return
        var stake = bet.bet
        Game.stake(stake)
        var s = Void.play(m)
        var w = Math.round(Math.min(s.ev.pay * (1 + s.added), m.bonus.maxWin) * stake * 100) / 100
        if (s.portals >= m.bonus.portals) {
            Game.slotBonus = { theme: "void", bet: stake, cost: stake, played: 0, mult: 1, won: w, spins: m.bonus.spins, fresh: true }
            Game.count("bonuses")
        } else {
            Game.pending = { game: "slots", staked: stake, returned: w }
        }
        Game.save()
        show(s, 1 + s.added, w)
    }
    function freeSpin() {
        var b = JSON.parse(JSON.stringify(Game.slotBonus))
        bonus = b
        if (b.spins <= 0 || b.won >= m.bonus.maxWin * b.bet) { endBonus(); return }
        var s = Void.play(m)
        b.mult += s.added
        var w = Math.round(s.ev.pay * b.mult * b.bet * 100) / 100
        b.won = Math.min(m.bonus.maxWin * b.bet, Math.round((b.won + w) * 100) / 100)
        b.spins -= 1; b.played += 1; b.fresh = false
        b.retrig = s.portals >= m.bonus.portals
        if (b.retrig) { b.spins += m.bonus.retrigger; Game.count("retriggers") }
        Game.slotBonus = b
        Game.save()
        show(s, b.mult, w)
    }
    function endBonus() {
        var b = Game.slotBonus
        Game.slotBonus = null
        bonus = null
        busyReels = false
        page.burst.show(b.won, true)
        Game.best("bestBonusX", Math.round(b.won / b.bet))
        Game.settle(b.cost || b.bet, b.won, "slots")
    }

    // ---- presentation: spin the first reels, then open the rest one by one ----
    function show(s, mult, w) {
        result = s; won = w
        busyReels = true
        for (var i = 0; i < reels.count; ++i) reels.itemAt(i).lit = []
        reelCount = m.start
        shownMult = inBonus ? bonus.mult - s.added : 1
        reelsDone = 0
        reelStrip.contentX = 0
        Sound.play("reel")
        for (i = 0; i < m.start; ++i) reels.itemAt(i).spin(s.grid[i], 800 + i * 300)
    }
    function reelStopped() {
        Sound.play("tick")
        if (++reelsDone < reelCount) return
        if (reelCount < result.grid.length) {           // a win reached the edge: open a reel
            reelCount += 1
            shownMult += 1
            Game.note("NEW REEL · ×" + shownMult, m.color)
            Sound.play("perk"); Haptics.tap()
            openTimer.restart()
            return
        }
        // done: light the wins
        var lit = [], w, c
        for (var r = 0; r < reelCount; ++r) lit.push([])
        for (w = 0; w < result.ev.wins.length; ++w)
            for (c = 0; c < result.ev.wins[w].cells.length; ++c) lit[result.ev.wins[w].cells[c][0]].push(result.ev.wins[w].cells[c][1])
        for (r = 0; r < reelCount; ++r) reels.itemAt(r).lit = lit[r]
        if (inBonus) {
            bonus = Game.slotBonus
            if (won > 0) { winText.show(won); Sound.play(won >= bonus.bet * 20 ? "bigwin" : "win"); Haptics.win(won >= bonus.bet * 20) }
            if (bonus.fresh || bonus.retrig) {
                Game.note(bonus.fresh ? "PORTALS · " + bonus.spins + " FREE SPINS" : "RETRIGGER +" + m.bonus.retrigger, "#FF9F14")
                Sound.play("perk"); Haptics.rumble(5)
            }
            nextTimer.interval = bonus.fresh ? 1800 : (won > 0 ? 1400 : 800)
            nextTimer.restart()
            return
        }
        var p = Game.pending
        busyReels = false
        if (p.returned > 0) page.burst.show(p.returned, p.returned >= p.staked * 20)
        Game.settle(p.staked, p.returned, "slots")
    }
    Timer {      // after the new reel slides in, spin it
        id: openTimer; interval: 260
        onTriggered: {
            var k = page.reelCount - 1
            scrollAnim.to = Math.max(0, (k + 1) * reelStrip.reelW - reelStrip.width)
            scrollAnim.restart()
            reels.itemAt(k).spin(page.result.grid[k], 900)
        }
    }
    Timer { id: nextTimer; onTriggered: page.freeSpin() }
    Component.onCompleted: if (inBonus) { nextTimer.interval = 900; nextTimer.restart() }

    // ---- the reels ----
    NeonPanel {
        id: cabinet
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: reelStrip.height + 2 * Theme.paddingLarge
        glowColor: m.color
        glowStrength: page.reelCount > m.start ? 0.9 : 0.5
        strong: true
        Flickable {
            id: reelStrip
            anchors.centerIn: parent
            width: parent.width - 2 * Theme.paddingLarge
            readonly property real reelW: width / 5
            height: reelW * m.rows
            contentWidth: Math.max(width, page.reelCount * reelW)
            interactive: false
            clip: true
            NumberAnimation { id: scrollAnim; target: reelStrip; property: "contentX"; duration: 400; easing.type: Easing.OutCubic }
            Row {
                Repeater {
                    id: reels
                    // every reel exists from the start and is only shown when it opens: changing an
                    // int model would rebuild ALL delegates and reset the reels already on screen
                    model: m.maxReels
                    Reel {
                        id: vreel
                        width: reelStrip.reelW; cell: width
                        theme: page.reelTheme
                        onStopped: page.reelStopped()
                        visible: index < page.reelCount
                        onVisibleChanged: if (visible && index >= m.start) { opacity = 0; fadeIn.restart() }
                        NumberAnimation { id: fadeIn; target: vreel; property: "opacity"; to: 1; duration: 250 }
                        Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Neon.alpha(m.color, 0.3) }
                    }
                }
            }
        }
        NeonText {
            anchors { right: parent.right; top: parent.top; margins: Theme.paddingSmall }
            visible: page.shownMult > 1 || page.inBonus
            text: "×" + page.shownMult
            color: Neon.yellow
            font.pixelSize: Theme.fontSizeExtraLarge
        }
    }
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeSmall
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: page.inBonus ? "FREE SPINS " + page.bonus.spins + " · ×" + page.bonus.mult + " · WON " + Money.fmt(page.bonus.won)
                               : page.reelCount + " REELS" + (page.busyReels ? "" : page.won > 0 ? " · WON " + Money.fmt(page.won) : "")
            color: page.inBonus ? "#FF9F14" : Neon.alpha(m.color, 0.9)
            font { family: Neon.mono; pixelSize: Theme.fontSizeSmall }
        }
        Text {
            id: winText
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            color: Neon.green; opacity: 0
            font { family: Neon.mono; pixelSize: Theme.fontSizeMedium; bold: true }
            function show(v) { text = "+" + Money.fmt(v); fade.restart() }
            SequentialAnimation { id: fade; NumberAnimation { target: winText; property: "opacity"; to: 1; duration: 120 } PauseAnimation { duration: 900 } NumberAnimation { target: winText; property: "opacity"; to: 0; duration: 400 } }
        }
    }
    Text {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        text: "A WIN THAT REACHES THE LAST REEL OPENS A NEW ONE · +1× PER REEL"
        color: Theme.secondaryColor
        font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 1 }
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
            text: page.inBonus ? "Free spins…" : page.busyReels ? "Spinning…" : "Spin " + Money.fmt(bet.bet)
            color: m.color; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: !page.busy && Game.canBet(bet.bet)
            onClicked: page.spin()
        }
    }
}
