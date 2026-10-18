import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Heist.js" as Heist
import "../js/HeistConfig.js" as Config
import "../js/Money.js" as Money

// DATA HEIST: 5×3, 10 lines. 6+ data chips start the heist: chips lock, 3 respins, every new
// chip resets them to 3, a full board adds the GRAND. The spin and the whole heist are decided
// and saved before anything moves.
TablePage {
    id: page
    readonly property var m: Config.machine
    title: "Data heist"
    accent: m.color
    scene: "heist"
    code: "HOLD & WIN · 10 LINES · GRAND 1000×"
    info: {
        var t = "10 lines pay left to right (3, 4 or 5 in a row). Data chips carry a cash value. Land " + m.trigger + " or more to start a heist: "
        t += "the chips lock, you get " + m.respins + " respins, and every new chip resets them. When the respins run out every chip pays. "
        t += "Fill all 15 cells for the GRAND (" + m.grand + "× bet). MINI 25×, MINOR 50×, MAJOR 150×.<br><br><b>Pays × bet (3 / 4 / 5 in a row)</b><br>"
        var s = m.symbols.slice().reverse()
        for (var i = 0; i < s.length; ++i) t += s[i].toUpperCase() + ": " + m.pay[s[i]].map(function (v) { return +(v / m.lines.length).toFixed(2) }).join(" · ") + "<br>"
        t += "<br>Buying a heist costs " + (m.bonus ? m.bonus.buy : 80) + "× bet."
        return t
    }
    musicTrack: phase === "heist" ? m.music + "_bonus" : m.music
    footerHeight: footerCol.height + Theme.paddingLarge

    property string phase: "idle"             // idle | spin | heist
    property var grid: emptyGrid()
    property var values: zeroGrid()
    property var locked: ({})                 // "reel,row" -> true while the heist runs
    property var lit: ({})
    property var plan: null                   // { lineWins, feature, stake, total }
    property int respinsLeft: 0
    property int stepIndex: 0
    property real heistTotal: 0
    readonly property real buyCost: (m.bonus && m.bonus.buy ? m.bonus.buy : 80) * bet.bet
    readonly property bool canBuy: !busy && Game.canBet(buyCost)
    property bool buyArmed: false
    busy: phase !== "idle"
    Timer { id: disarm; interval: 3000; onTriggered: page.buyArmed = false }

    function emptyGrid() {
        var g = []
        for (var r = 0; r < m.reels; ++r) {
            var c = []
            for (var j = 0; j < m.rows; ++j) { var s; do { s = Heist.pick(m) } while (s === "chip"); c.push(s) }
            g.push(c)
        }
        return g
    }
    function zeroGrid() { var g = []; for (var r = 0; r < m.reels; ++r) g.push([0, 0, 0]); return g }
    function cellChips() {
        var out = []
        for (var r = 0; r < m.reels; ++r) for (var c = 0; c < m.rows; ++c) if (grid[r][c] === "chip") out.push({ reel: r, row: c, value: values[r][c] })
        return out
    }

    function spin() {
        if (busy || !Game.canBet(bet.bet)) return
        var stake = bet.bet
        Game.stake(stake)
        var sg = Heist.spinGrid(m), lw = Heist.lines(m, sg.grid)
        var chips = []
        for (var r = 0; r < m.reels; ++r) for (var c = 0; c < m.rows; ++c) if (sg.grid[r][c] === "chip") chips.push({ reel: r, row: c, value: sg.values[r][c] })
        var feature = chips.length >= m.trigger ? Heist.heist(m, chips) : null
        var total = Math.min(m.maxWin, lw.total + (feature ? feature.total : 0))
        plan = { lineWins: lw.wins, feature: feature, stake: stake, total: Math.round(total * stake * 100) / 100 }
        Game.pending = { game: "slots", staked: stake, returned: plan.total }
        if (feature) Game.count("heists")
        Game.save()                                     // decided, heist included, before anything moves
        lit = ({}); locked = ({}); heistTotal = 0
        phase = "spin"
        values = sg.values
        grid = sg.grid
        dropAll()
    }
    function buyBonus() {
        if (!canBuy) return
        if (!buyArmed) { buyArmed = true; disarm.restart(); Haptics.tap(); return }
        buyArmed = false
        var cost = buyCost, stake = bet.bet
        Game.stake(cost)
        var start = Heist.boughtStart(m), feature = Heist.heist(m, start)
        plan = { lineWins: [], feature: feature, stake: stake, total: Math.round(feature.total * stake * 100) / 100 }
        Game.pending = { game: "slots", staked: cost, returned: plan.total }
        Game.count("heists"); Game.count("bonusBuys")
        Game.save()
        var g = [], v = []
        for (var r = 0; r < m.reels; ++r) { g.push(["", "", ""]); v.push([0, 0, 0]) }
        for (var i = 0; i < start.length; ++i) { g[start[i].reel][start[i].row] = "chip"; v[start[i].reel][start[i].row] = start[i].value }
        lit = ({}); locked = ({}); heistTotal = 0
        phase = "spin"
        values = v; grid = g
        dropAll()
    }
    property int reelsDone: 0
    function dropAll() {
        reelsDone = 0
        Sound.play("reel")
        for (var i = 0; i < reelRep.count; ++i) reelRep.itemAt(i).drop(i * 140)
    }
    function reelStopped() {
        Sound.play("tick"); Haptics.tick()
        if (++reelsDone < m.reels) return
        var l = {}
        for (var w = 0; w < plan.lineWins.length; ++w) {
            var line = m.lines[plan.lineWins[w].line]
            for (var r = 0; r < plan.lineWins[w].n; ++r) l[r + "," + line[r]] = true
        }
        lit = l
        if (plan.feature) startHeist()
        else finish()
    }
    function startHeist() {
        var k = {}, chips = cellChips(), t = 0
        for (var i = 0; i < chips.length; ++i) { k[chips[i].reel + "," + chips[i].row] = true; t += chips[i].value }
        locked = k
        heistTotal = t
        respinsLeft = m.respins
        stepIndex = 0
        phase = "heist"
        Game.note("HEIST! " + chips.length + " CHIPS LOCKED", m.color)
        Sound.play("perk"); Haptics.rumble(6)
        heistTimer.interval = 1600; heistTimer.restart()
    }
    Timer {
        id: heistTimer
        onTriggered: {
            var f = page.plan.feature
            if (page.stepIndex >= f.steps.length) { page.endHeist(); return }
            var st = f.steps[page.stepIndex++]
            flicker.restart()
            if (st.added.length) {
                var g = JSON.parse(JSON.stringify(page.grid)), v = JSON.parse(JSON.stringify(page.values)), k = {}, key
                for (key in page.locked) k[key] = true
                for (var i = 0; i < st.added.length; ++i) {
                    var a = st.added[i]
                    g[a.reel][a.row] = "chip"; v[a.reel][a.row] = a.value; k[a.reel + "," + a.row] = true
                    page.heistTotal += a.value
                }
                page.values = v; page.grid = g; page.locked = k
                Sound.play("win"); Haptics.tap()
                if (st.added.length > 1) Game.note("+" + st.added.length + " CHIPS · RESPINS RESET", page.m.color)
            } else {
                Sound.play("tick")
            }
            page.respinsLeft = st.left
            interval = st.added.length ? 1100 : 800
            restart()
        }
    }
    function endHeist() {
        if (plan.feature.grand) { Game.note("GRAND · +" + m.grand + "× BET", Neon.yellow); Haptics.rumble(12) }
        finish()
    }
    function finish() {
        var p = Game.pending
        phase = "idle"
        if (p.returned > 0) page.burst.show(p.returned, p.returned >= p.staked * 10)
        Game.settle(p.staked, p.returned, "slots")
    }

    // ---- display ----
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeMedium
        NeonText {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: page.phase === "heist" ? "RESPINS" : "HEIST"
            color: page.m.color; glow: 10
            font.pixelSize: Theme.fontSizeMedium
        }
        Row {
            visible: page.phase === "heist"
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            spacing: Theme.paddingSmall
            Repeater {
                model: page.m.respins
                Rectangle {
                    width: Theme.paddingLarge; height: width; radius: width / 2
                    color: index < page.respinsLeft ? page.m.color : Neon.alpha(page.m.color, 0.15)
                    border { width: 1; color: page.m.color }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: page.phase === "heist" ? Money.fmt(page.heistTotal * page.plan.stake) : "6+ CHIPS = HEIST"
            color: page.phase === "heist" ? Neon.green : Neon.alpha(page.m.color, 0.7)
            font { pixelSize: Theme.fontSizeSmall; bold: true; letterSpacing: 1; family: Neon.display }
        }
    }

    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: machine.height
        Lever {
            id: lever
            anchors { right: parent.right; top: machine.top; bottom: machine.bottom; topMargin: Theme.paddingSmall }
            color: page.m.color
            armed: !page.busy && Game.canBet(bet.bet)
            onPulled: { Haptics.tap(); page.spin() }
        }
        NeonPanel {
            id: machine
            width: parent.width - lever.width - Theme.paddingSmall
            height: width * 0.66
            glowColor: page.phase === "heist" ? Neon.green : page.m.color
            glowStrength: page.phase === "heist" ? 0.95 : 0.5
            Row {
                id: reelRow
                anchors { fill: parent; margins: Theme.paddingMedium }
                spacing: 3
                Repeater {
                    id: reelRep
                    model: page.m.reels
                    Item {
                        id: reel
                        readonly property int ri: index
                        width: (reelRow.width - 4 * 3) / 5
                        height: reelRow.height
                        clip: true
                        property real offset: 0
                        function drop(delay) { offset = -height; anim.delay = delay; anim.restart() }
                        SequentialAnimation {
                            id: anim
                            property int delay: 0
                            PauseAnimation { duration: anim.delay }
                            NumberAnimation { target: reel; property: "offset"; to: 0; duration: 380; easing.type: Easing.OutBack }
                            ScriptAction { script: page.reelStopped() }
                        }
                        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35); border { width: 1; color: Neon.alpha(page.m.color, 0.35) } }
                        Column {
                            y: reel.offset
                            Repeater {
                                model: 3
                                Item {
                                    id: cellItem
                                    width: reel.width; height: reel.height / 3
                                    readonly property string sym: page.grid[reel.ri][index]
                                    readonly property real val: page.values[reel.ri][index]
                                    readonly property bool isLocked: !!page.locked[reel.ri + "," + index]
                                    readonly property bool hot: !!page.lit[reel.ri + "," + index]
                                    opacity: page.phase === "heist" && !isLocked ? 0.15 : 1
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    Rectangle {
                                        anchors { fill: parent; margins: 2 }
                                        radius: 4
                                        visible: cellItem.hot || cellItem.isLocked
                                        color: Neon.alpha(cellItem.isLocked ? Neon.green : page.m.color, 0.2)
                                        border { width: 2; color: cellItem.isLocked ? Neon.green : Neon.yellow }
                                    }
                                    Image {
                                        id: symImg
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height) * 0.86; height: width
                                        source: cellItem.sym ? "../images/sym-heist-" + cellItem.sym + ".png" : ""
                                        opacity: cellItem.sym === "chip" ? 0.55 : 1
                                    }
                                    Column {
                                        visible: cellItem.sym === "chip"
                                        anchors.centerIn: parent
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Heist.tierName(page.m, cellItem.val)
                                            visible: text !== ""
                                            color: cellItem.val >= 150 ? Neon.red : cellItem.val >= 50 ? Neon.pink : Neon.cyan
                                            font { pixelSize: Theme.fontSizeTiny; bold: true; family: Neon.display }
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Money.fmt(cellItem.val * (page.plan ? page.plan.stake : bet.bet))
                                            color: "white"
                                            style: Text.Outline; styleColor: Neon.ink
                                            font { pixelSize: Theme.fontSizeExtraSmall; bold: true; family: Neon.display }
                                        }
                                    }
                                    // new chip pop
                                    onIsLockedChanged: if (isLocked && page.phase === "heist") pop.restart()
                                    SequentialAnimation {
                                        id: pop
                                        NumberAnimation { target: cellItem; property: "scale"; from: 0.3; to: 1.15; duration: 220; easing.type: Easing.OutBack }
                                        NumberAnimation { target: cellItem; property: "scale"; to: 1; duration: 120 }
                                    }
                                    SequentialAnimation on scale {
                                        running: cellItem.hot && page.phase === "idle"; loops: Animation.Infinite
                                        NumberAnimation { to: 1.08; duration: 320 } NumberAnimation { to: 1; duration: 320 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // respin flicker over the empty cells
            Rectangle {
                id: flickerRect
                anchors.fill: reelRow
                color: page.m.color
                opacity: 0
                SequentialAnimation {
                    id: flicker
                    NumberAnimation { target: flickerRect; property: "opacity"; from: 0.25; to: 0; duration: 500 }
                }
            }
            MouseArea {
                anchors.fill: reelRow
                preventStealing: true
                property real y0
                property bool fired
                onPressed: { y0 = mouse.y; fired = false }
                onPositionChanged: if (!fired && mouse.y - y0 > Theme.itemSizeSmall) { fired = true; page.spin() }
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
                            : "Buy a heist · " + (page.m.bonus ? page.m.bonus.buy : 80) + "× bet · " + Money.fmt(page.buyCost)
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
            text: page.phase === "heist" ? "Heist in progress…" : page.busy ? "Spinning…" : "Spin " + Money.fmt(bet.bet)
            color: page.m.color; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: !page.busy && Game.canBet(bet.bet)
            onClicked: page.spin()
        }
    }
}
