import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Slots.js" as Slots
import "../js/SlotThemes.js" as Themes
import "../js/Money.js" as Money

TablePage {
    id: page
    // which machine: set on push from the lobby (or by a bonus waiting to resume)
    property string themeId: "classic"
    readonly property var theme: Themes.byId(themeId)
    readonly property var tb: theme.bonus
    title: theme.name.charAt(0) + theme.name.slice(1).toLowerCase()
    footerHeight: footerCol.height + Theme.paddingLarge

    property var result: null
    property var outcome: null
    property real stakeAmount: 0
    property int reelsDone: 0
    property var winLines: []
    property int lineCount: 5
    readonly property real totalBet: bet.bet * lineCount
    property bool showLines: false       // flash the active paylines after changing the count
    // ---- bonus buy: pay theme.bonus.buy × total bet to go straight to the free spins ----
    readonly property real buyCost: tb.buy * totalBet
    readonly property bool canBuy: !busy && !inBonus && Game.canBet(buyCost)
    property bool buyArmed: false        // first tap arms, second tap within 3 s buys
    property bool buyIntro: false
    Timer { id: disarm; interval: 3000; onTriggered: page.buyArmed = false }
    function buyBonus() {
        if (!canBuy) return
        if (!buyArmed) { buyArmed = true; disarm.restart(); Haptics.tap(); return }
        buyArmed = false
        busy = true
        var cost = buyCost
        Game.stake(cost)
        // saved before anything animates, like every other result
        Game.slotBonus = { bet: totalBet, cost: cost, lines: lineCount, theme: themeId, spins: tb.spins,
                           level: 0, played: 0, won: totalBet * tb.scatterPay, bought: true }
        Game.count("bonusBuys")
        Game.count("bonuses")
        Game.save()
        bonus = Game.slotBonus
        // land a BONUS on every reel
        var g = []
        for (var i = 0; i < 3; ++i) {
            var col = [Slots.pick(theme, false, false), "scatter", Slots.pick(theme, false, false)]
            for (var j = 0; j < 3; ++j) if (j !== 1 && col[j] === "scatter") col[j] = theme.symbols[0]
            g.push(col)
        }
        buyIntro = true
        play({ grid: g, nudged: false }, { winningLines: [], multiplier: 0, scatter: true }, 1)
    }
    Timer { id: hideLines; interval: 1400; onTriggered: page.showLines = false }
    readonly property bool inBonus: Game.slotBonus !== null && Game.slotBonus !== undefined
    // What the banner shows. The saved bonus already holds the result of the spin in play,
    // so the banner only catches up when the reels stop.
    property var bonus: Game.slotBonus
    property int currentMult: 1
    property bool rollingMult: false
    property real lastWin: 0
    property int lastIncrement: 0
    property string featureInfo: ""
    // what the feature meter shows; catches up when the reels stop
    property var shownState: ({})
    readonly property var feat: Slots.feature(theme)
    property bool lastRetrigger: false
    property bool maxWinHit: false
    accent: inBonus ? "#FF9F14" : theme.color
    // free spins play this machine's own remix (the classic machine keeps the original bonus track)
    musicTrack: inBonus ? (theme.music && theme.music !== "slots" ? theme.music + "_bonus" : "bonus") : (theme.music || "slots")
    scene: themeId
    info: {
        var t = "<b>" + feat.text + "</b><br><br>Up to 9 lines: 3 rows, 2 diagonals, 4 V-shapes. You pay the line bet on every line you play.<br><br>"
        t += "<b>Pays × line bet (3 in a row)</b><br>"
        var syms = theme.symbols.slice().reverse()
        for (var i = 0; i < syms.length; ++i)
            t += syms[i].toUpperCase() + ": " + (syms[i] === theme.top ? Slots.topPay(theme, Game.perks) : theme.pay3[syms[i]]) + "×<br>"
        t += "Two " + theme.low2.symbol.toUpperCase() + " from the left: " + theme.low2.pay + "×<br><br>"
        t += "<b>Bonus</b><br>A BONUS symbol on all three reels pays " + tb.scatterPay + "× bet and starts " + tb.spins + " free spins. "
        t += "Retriggers add " + tb.retrigger + " spins. Max win " + tb.maxWin + "× bet. Buying the bonus costs " + tb.buy + "× bet.<br><br>"
        t += "Pull the lever, swipe down the reels or tap Spin. Tap a spinning reel to stop it."
        if (Game.hasPerk("wild")) t += "<br>WILD stands in for any symbol; three WILDs pay " + theme.pay3.wild + "×."
        if (Game.hasPerk("overclock")) t += "<br>Overclock: all wins +25%."
        return t
    }
    code: lineCount + " LINES · " + tb.spins + " FREE SPINS · MAX " + tb.maxWin + "× · RTP ~95%"

    // Every outcome is decided and saved *before* the reels move, so quitting mid-spin
    // can't reroll it (Game.load() settles a leftover pending spin).
    function spin(power) {
        if (busy || inBonus || !Game.canBet(totalBet)) return
        busy = true
        stakeAmount = totalBet
        Game.stake(stakeAmount)
        var r = Slots.spin(theme, Game.perks, false)
        var ev = Slots.evaluate(theme, r.grid, Game.perks, lineCount)
        var st = Game.slotStateFor(themeId)
        var fx = Slots.applyFeature(theme, st, r.grid, ev)
        featureInfo = fx.info
        Game.setSlotState(themeId, st)
        Game.pending = { game: "slots", staked: stakeAmount, scatter: ev.scatter, lines: lineCount, theme: themeId,
                         returned: Math.round(stakeAmount * ev.multiplier * fx.mult * 100) / 100 }
        Game.save()                       // result and feature state saved together, before the reels move
        play(r, ev, power)
    }
    // power 0..1 from the gesture: a harder pull / faster swipe spins longer
    function play(r, ev, power) {
        var scale = power === undefined ? 1 : 0.8 + 0.7 * power
        winLines = []
        result = r
        outcome = ev
        reelsDone = 0
        Sound.play("reel")
        for (var i = 0; i < 3; ++i) {
            reels.itemAt(i).wildOn = Game.hasPerk("wild")
            reels.itemAt(i).bonusOn = inBonus
            reels.itemAt(i).spin(r.grid[i], (900 + i * 380) * scale)
        }
    }
    function reelStopped() {
        Sound.play("tick")
        if (++reelsDone < 3) return
        winLines = outcome.winningLines
        for (var r = 0; r < 3; ++r) {
            var rows = []
            for (var w = 0; w < winLines.length; ++w) rows.push(Slots.lines[winLines[w]][r])
            reels.itemAt(r).lit = rows
        }
        if (buyIntro) {
            buyIntro = false
            Sound.play("perk"); Haptics.rumble(6)
            Game.note("BONUS BOUGHT · " + tb.spins + " FREE SPINS", "#FF9F14")
            bonusIntro.restart()
            return
        }
        if (result.nudged) Game.note("NUDGE!", Neon.pink)
        if (inBonus) { freeSpinShown(); return }

        var p = Game.pending
        if (p.scatter) {
            Haptics.rumble(6)
            Game.startSlotBonus()          // hold the settlement until the free spins are over
            bonus = Game.slotBonus
            Sound.play("perk")
            bonusIntro.restart()
            return
        }
        shownState = Game.slotStateFor(themeId)
        if (featureInfo) { Game.note(featureInfo, theme.color); featureInfo = "" }
        if (shownState.turbo) { Game.note("TURBO READY", "#FF9F14"); Haptics.rumble(2) }
        if (p.returned > 0) page.burst.show(p.returned, p.returned >= p.staked * 10)
        busy = false
        Game.settle(p.staked, p.returned, "slots")
    }

    // ---- free spins ----
    function nextFreeSpin() {
        if (!inBonus) return
        busy = true
        var b = {}, k
        for (k in Game.slotBonus) b[k] = Game.slotBonus[k]
        bonus = b
        if (b.spins <= 0) { endBonus(); return }
        // decide and save this free spin first
        if (Slots.feature(theme).type === "stack") {
            lastIncrement = Slots.rollIncrement(theme, Game.perks)
            currentMult = (b.stack || 1) + lastIncrement
        } else {
            currentMult = Slots.rollMultiplier(theme, b.level, Game.perks)
        }
        var r = Slots.spin(theme, Game.perks, true)
        var ev = Slots.evaluate(theme, r.grid, Game.perks, b.lines || 5)
        var n = {}
        for (k in b) n[k] = b[k]
        lastWin = Math.round(n.bet * ev.multiplier * currentMult * 100) / 100
        n.won += lastWin
        n.stack = currentMult
        n.spins -= 1
        n.played += 1
        lastRetrigger = ev.scatter
        if (ev.scatter) {
            n.spins += tb.retrigger
            n.won += n.bet * tb.scatterPay
            if (n.level < tb.ladders.length - 1) n.level += 1
        }
        maxWinHit = n.won >= n.bet * tb.maxWin
        if (maxWinHit) { n.won = n.bet * tb.maxWin; n.spins = 0 }
        Game.slotBonus = n
        Game.save()
        Game.best("bestMultiplier", currentMult)
        if (ev.scatter) Game.count("retriggers")
        if (maxWinHit) Game.count("maxWins")
        result = r; outcome = ev
        multRoll.start()
    }
    function freeSpinShown() {
        bonus = Game.slotBonus
        if (lastWin > 0) {
            Sound.play(lastWin >= bonus.bet * 20 ? "bigwin" : "win"); spinWin.show(lastWin)
            Haptics.win(lastWin >= bonus.bet * 20)
        }
        if (lastRetrigger) {
            Haptics.rumble(5)
            Game.note("RETRIGGER +" + tb.retrigger + " · LADDER UP", "#FF9F14")
            Sound.play("perk")
        }
        if (maxWinHit) { Game.note("MAX WIN  " + tb.maxWin + "×", Neon.yellow); Haptics.rumble(12) }
        freeSpinTimer.interval = lastRetrigger || maxWinHit ? 1600 : 900
        freeSpinTimer.restart()
    }
    function endBonus() {
        var b = Game.slotBonus
        busy = false
        maxWinHit = false
        currentMult = 1
        page.burst.show(b.won, true)
        Game.best("bestBonusX", Math.round(b.won / b.bet))
        Game.slotBonus = null
        Game.settle(b.cost || b.bet, b.won, "slots")      // a bought bonus staked its price
    }
    Timer { id: freeSpinTimer; onTriggered: page.nextFreeSpin() }
    Timer { id: bonusIntro; interval: 2200; onTriggered: page.nextFreeSpin() }
    // multiplier badge flickers through the ladder before landing
    SequentialAnimation {
        id: multRoll
        ScriptAction { script: page.rollingMult = true }
        PauseAnimation { duration: 650 }
        ScriptAction { script: { page.rollingMult = false; Sound.play("tick"); page.play(page.result, page.outcome) } }
    }
    Component.onCompleted: {
        shownState = Game.slotStateFor(themeId)
        if (inBonus) {
            lineCount = Game.slotBonus.lines || 5
            busy = true; bonusIntro.interval = 900; bonusIntro.restart()
        }
    }

    // base-game feature meter: OVERFLOW combo (hacker) or TURBO fuel (sunset)
    NeonPanel {
        id: featPanel
        visible: !page.inBonus && (page.feat.type === "combo" || page.feat.type === "turbo")
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: visible ? Theme.itemSizeSmall : 0
        glowColor: page.theme.color
        glowStrength: page.feat.type === "turbo" && page.shownState.turbo ? 0.95 : 0.4
        strong: true
        readonly property int level: page.feat.type === "combo" ? (page.shownState.combo || 1) - 1 : (page.shownState.fuel || 0)
        readonly property int slots: page.feat.type === "combo" ? page.feat.max - 1 : (page.feat.fuel || 5)
        Text {
            id: featLabel
            anchors { left: parent.left; leftMargin: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
            text: page.feat.type === "combo" ? "OVERFLOW ×" + (page.shownState.combo || 1)
                  : page.shownState.turbo ? "TURBO READY ×" + page.feat.mult : "FUEL"
            color: Qt.lighter(page.theme.color, 1.2)
            font { pixelSize: Theme.fontSizeSmall; bold: true; letterSpacing: 2; family: Neon.display }
            SequentialAnimation on opacity {
                running: page.feat.type === "turbo" && page.shownState.turbo; loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 250 } NumberAnimation { to: 1; duration: 250 }
            }
        }
        Row {
            anchors { right: parent.right; rightMargin: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
            spacing: Theme.paddingSmall
            Repeater {
                model: featPanel.slots
                Rectangle {
                    width: Theme.paddingLarge * 1.4; height: Theme.paddingLarge * 0.8; radius: 3
                    readonly property bool lit: index < featPanel.level || (page.feat.type === "turbo" && page.shownState.turbo)
                    color: lit ? page.theme.color : Neon.alpha(page.theme.color, 0.15)
                    border { width: 1; color: page.theme.color }
                    scale: lit ? 1 : 0.85
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
    }

    // free-spin banner
    NeonPanel {
        id: bonusPanel
        visible: page.inBonus
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: visible ? bonusCol.height + 2 * Theme.paddingMedium : 0
        glowColor: "#FF9F14"; glowStrength: 0.8; strong: true
        Column {
            id: bonusCol
            anchors { left: parent.left; right: parent.right; margins: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
            spacing: Theme.paddingSmall
            Item {
                width: parent.width; height: multText.height
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    NeonText { text: "FREE SPINS"; color: "#FF9F14"; glow: 8 }
                    Text {
                        text: page.inBonus ? page.bonus.spins + " LEFT · " + page.bonus.played + " PLAYED" : ""
                        color: Neon.alpha("#FF9F14", 0.8)
                        font { pixelSize: Theme.fontSizeExtraSmall; letterSpacing: 2; family: Neon.display }
                    }
                }
                NeonText {
                    id: multText
                    anchors.right: parent.right
                    property var ladder: !page.inBonus ? [1]
                        : page.feat.type === "stack" ? page.feat.increments.map(function (v) { return (page.bonus.stack || 1) + v })
                        : Slots.ladder(page.theme, page.bonus.level, Game.perks)
                    property int flick: 0
                    text: "×" + (page.rollingMult ? ladder[flick % ladder.length] : page.currentMult)
                    color: page.currentMult >= 25 ? Neon.red : page.currentMult >= 10 ? Neon.pink : Neon.yellow
                    font.pixelSize: Theme.fontSizeHuge
                    glow: 16
                    Timer { running: page.rollingMult; interval: 60; repeat: true; onTriggered: parent.flick++ }
                }
            }
            Row {
                spacing: Theme.paddingSmall
                visible: page.feat.type !== "stack"
                Repeater {
                    model: page.tb.ladders.length
                    Rectangle {
                        width: (bonusCol.width - 3 * Theme.paddingSmall) / page.tb.ladders.length
                        height: Theme.paddingSmall
                        radius: height / 2
                        color: page.inBonus && index <= page.bonus.level ? "#FF9F14" : Neon.alpha("#FF9F14", 0.2)
                    }
                }
            }
            Text {
                text: !page.inBonus ? ""
                      : (page.feat.type === "stack"
                         ? "STACKING · +" + page.feat.increments.join("/+") + " EVERY SPIN"
                         : "LADDER " + Slots.ladder(page.theme, page.bonus.level, Game.perks).map(function (v) { return "×" + v }).join(" "))
                      + "   ·   WON " + Money.fmt(page.bonus.won)
                color: Neon.yellow
                font { pixelSize: Theme.fontSizeExtraSmall; bold: true; family: Neon.display }
            }
        }
    }

    Item {
        id: machineHolder
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: machine.height

        Lever {
            id: lever
            anchors { right: parent.right; top: machine.top; bottom: machine.bottom; topMargin: Theme.paddingSmall }
            color: page.inBonus ? "#FF9F14" : Neon.red
            armed: !page.busy && Game.canBet(page.totalBet)
            onPulled: { Haptics.tap(); page.spin(power) }
        }
        NeonPanel {
            id: machine
            width: parent.width - lever.width - Theme.paddingSmall
            height: reelRow.height + 2 * Theme.paddingLarge
            glowColor: page.inBonus ? "#FF9F14" : page.theme.color
            glowStrength: page.winLines.length || page.inBonus ? 0.95 : 0.5
            Behavior on glowStrength { NumberAnimation { duration: 300 } }

            Row {
                id: reelRow
                anchors.centerIn: parent
                spacing: Theme.paddingSmall
                Repeater {
                    id: reels
                    model: 3
                    Item {
                        width: (machine.width - 2 * Theme.paddingLarge - 2 * Theme.paddingSmall) / 3
                        height: reel.height
                        property alias wildOn: reel.wildOn
                        property alias theme: reel.theme
                        property alias bonusOn: reel.bonusOn
                        property alias lit: reel.lit
                        function spin(f, d) { reel.spin(f, d) }
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.35)
                            border { width: 1; color: Neon.alpha(page.theme.color, 0.5) }
                        }
                        Reel { id: reel; width: parent.width; theme: page.theme; onStopped: page.reelStopped() }
                        function slam() { reel.slam() }
                    }
                }
            }
            // swipe down on the reels to spin; tap a spinning reel to slam it to a stop
            MouseArea {
                anchors.fill: reelRow
                preventStealing: true
                property real y0: 0
                property real t0: 0
                property bool swiped: false
                onPressed: { y0 = mouse.y; t0 = Date.now(); swiped = false }
                onPositionChanged: {
                    var dy = mouse.y - y0
                    if (!swiped && dy > Theme.itemSizeSmall && !page.busy) {
                        swiped = true
                        var v = dy / Math.max(1, Date.now() - t0)      // px/ms
                        page.spin(Math.min(1, v / 3))
                    }
                }
                onClicked: {
                    if (!swiped && page.busy && page.reelsDone < 3) {
                        var i = Math.floor(mouse.x / (width / 3))
                        reels.itemAt(Math.max(0, Math.min(2, i))).slam()
                    }
                }
            }
            // winning paylines
            Canvas {
                id: lines
                anchors.fill: reelRow
                property var wins: page.showLines ? [] : page.winLines
                property int count: page.lineCount
                property bool preview: page.showLines
                onWinsChanged: requestPaint()
                onPreviewChanged: requestPaint()
                onCountChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var colW = (width + Theme.paddingSmall) / 3, rowH = height / 3
                    var colors = [Neon.yellow, Neon.cyan, Neon.green, Neon.pink, Neon.violet, "#FF9F14", "#FFFFFF", Neon.red, "#7CFFCB"]
                    var list = preview ? Slots.lines.slice(0, count).map(function (x, i) { return i }) : wins
                    for (var i = 0; i < list.length; ++i) {
                        var l = Slots.lines[list[i]]
                        ctx.strokeStyle = colors[list[i]]
                        ctx.lineWidth = 6
                        ctx.globalAlpha = 0.85
                        ctx.beginPath()
                        for (var r = 0; r < 3; ++r) {
                            var x = colW * r + colW / 2 - Theme.paddingSmall / 2, y = rowH * l[r] + rowH / 2
                            if (r === 0) ctx.moveTo(x - colW / 2, y); ctx.lineTo(x, y)
                            if (r === 2) ctx.lineTo(x + colW / 2, y)
                        }
                        ctx.stroke()
                    }
                }
                SequentialAnimation on opacity {
                    running: page.winLines.length > 0 || page.showLines; loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 300 } NumberAnimation { to: 1; duration: 300 }
                }
            }
        }
    }

    // per-free-spin win, floats over the machine
    Item {
        width: parent.width; height: 0
        NeonText {
            id: spinWin
            anchors.horizontalCenter: parent.horizontalCenter
            y: -machineHolder.height / 2 - height / 2 - Theme.paddingMedium
            color: Neon.green; glow: 12
            font.pixelSize: Theme.fontSizeExtraLarge
            opacity: 0
            function show(v) { text = "+" + Money.fmt(v); fade.restart() }
            SequentialAnimation {
                id: fade
                NumberAnimation { target: spinWin; property: "opacity"; to: 1; duration: 120 }
                PauseAnimation { duration: 700 }
                NumberAnimation { target: spinWin; property: "opacity"; to: 0; duration: 300 }
            }
        }
    }

    Text {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: "PULL THE LEVER · SWIPE DOWN THE REELS · TAP A REEL TO STOP IT"
        color: Neon.alpha(Neon.pink, 0.7)
        font { pixelSize: Theme.fontSizeTiny; letterSpacing: 1; family: Neon.display }
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
                            : "Buy bonus · " + page.tb.buy + "× bet · " + Money.fmt(page.buyCost)
        onClicked: page.buyBonus()
        SequentialAnimation on scale {
            running: page.buyArmed; loops: Animation.Infinite
            NumberAnimation { to: 1.04; duration: 220 } NumberAnimation { to: 1; duration: 220 }
        }
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "LINES"
                color: Neon.alpha(Neon.pink, 0.8)
                font { pixelSize: Theme.fontSizeExtraSmall; bold: true; letterSpacing: 2; family: Neon.display }
            }
            Segmented {
                width: page.width - 2 * Theme.horizontalPageMargin - Theme.itemSizeSmall
                labels: Slots.lineOptions.map(function (n) { return String(n) })
                current: Slots.lineOptions.indexOf(page.lineCount)
                color: Neon.pink
                enabled: !page.busy
                onPicked: {
                    page.lineCount = Slots.lineOptions[index]
                    page.winLines = []
                    page.showLines = true
                    hideLines.restart()
                    Haptics.tick()
                }
            }
        }
        BetSelector {
            id: bet; width: parent.width; locked: page.busy; color: Neon.yellow
            factor: page.lineCount
            caption: "PER LINE"
            // start at the table minimum in total, not per line
            Component.onCompleted: { bet.bet = Math.max(1, Math.ceil(Game.minBet / page.lineCount)); bet.clamp() }
        }
        NeonButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            height: Theme.itemSizeMedium
            text: page.inBonus ? "Free spins…" : page.busy ? "Spinning…"
                  : "Spin " + Money.fmt(page.totalBet) + (page.lineCount > 1 ? "  ·  " + page.lineCount + " lines" : "  ·  1 line")
            color: page.inBonus ? "#FF9F14" : Neon.pink; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: !page.busy && Game.canBet(page.totalBet)
            onClicked: page.spin(0.5)
        }
    }
}
