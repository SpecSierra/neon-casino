import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Keno.js" as Keno
import "../js/KenoConfig.js" as Config
import "../js/Money.js" as Money

// Keno: pick 1-10 of 80 (tap, or drag across the board to paint), then 20 balls are drawn.
// The draw is decided and saved before the first ball shows.
TablePage {
    id: page
    readonly property var m: Config.machine
    title: "Keno"
    accent: Neon.pink
    scene: "keno"
    code: "80 NUMBERS · 20 DRAWN · PICK UP TO 10"
    musicTrack: "keno"
    footerHeight: footerCol.height + Theme.paddingLarge

    property var picks: []
    property var drawn: []                 // balls shown so far
    property var draw: []                  // the full draw (decided at the start)
    property int shown: 0
    property bool drawing: false
    property var lastPicks: []
    busy: drawing
    readonly property int hitCount: Keno.hits(picks, drawn)
    readonly property var payRow: m.pay[String(picks.length)] || ({})

    function toggle(n, mode) {      // mode: true add, false remove, undefined toggle
        if (drawing) return
        if (drawn.length) { drawn = []; shown = 0 }
        var i = picks.indexOf(n), p = picks.slice()
        if (i >= 0 && mode !== true) { p.splice(i, 1) }
        else if (i < 0 && mode !== false) {
            if (p.length >= m.maxPicks) { Game.note("UP TO " + m.maxPicks + " NUMBERS", Neon.pink); return }
            p.push(n)
        } else return
        picks = p.sort(function (a, b) { return a - b })
        Sound.play("tick"); Haptics.tick()
    }
    function quick() {
        if (drawing) return
        drawn = []; shown = 0
        picks = Keno.quickPick(m, picks.length || 6)
        Sound.play("click")
    }
    function play() {
        if (drawing || !picks.length || !Game.canBet(bet.bet)) return
        var stake = bet.bet
        Game.stake(stake)
        draw = Keno.draw(m)
        var h = Keno.hits(picks, draw), mult = Keno.pay(m, picks.length, h)
        Game.pending = { game: "keno", staked: stake, returned: Math.round(stake * mult * 100) / 100, hits: h, picks: picks.length }
        Game.save()                                      // decided before the first ball
        lastPicks = picks
        drawn = []; shown = 0
        drawing = true
        Sound.play("reel")
        ballTimer.start()
    }
    Timer {
        id: ballTimer
        interval: 230; repeat: true
        onTriggered: {
            var b = page.draw[page.shown]
            page.drawn = page.drawn.concat([b])
            page.shown++
            bigBall.show(b, page.picks.indexOf(b) >= 0)
            if (page.picks.indexOf(b) >= 0) { Sound.play("win"); Haptics.tap() } else Sound.play("tick")
            if (page.shown >= page.draw.length) { stop(); finishTimer.start() }
        }
    }
    Timer { id: finishTimer; interval: 500; onTriggered: page.finish() }
    function finish() {
        drawing = false
        var p = Game.pending
        Game.note(p.hits + " OF " + p.picks + " HIT", p.returned > 0 ? Neon.green : Neon.pink)
        if (p.returned > p.staked) page.burst.show(p.returned - p.staked, p.returned >= p.staked * 20)
        else if (p.returned < p.staked) Sound.play("lose")
        Game.best("kenoHits", p.hits)
        Game.settle(p.staked, p.returned, "keno")
    }

    // ---- big drawn ball + hit counter ----
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeLarge
        Rectangle {
            id: bigBall
            property int num: 0
            property bool hit: false
            width: parent.height; height: width; radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            gradient: Gradient {
                GradientStop { position: 0; color: bigBall.hit ? "#FFF8A0" : "#FFFFFF" }
                GradientStop { position: 1; color: bigBall.hit ? Neon.yellow : Neon.pink }
            }
            border { width: 3; color: bigBall.hit ? Neon.yellow : Neon.pink }
            opacity: num ? 1 : 0.25
            function show(n, h) { num = n; hit = h; pop.restart() }
            Text {
                anchors.centerIn: parent
                text: bigBall.num || "?"
                color: Neon.ink
                font { pixelSize: Theme.fontSizeLarge; bold: true; family: Neon.display }
            }
            SequentialAnimation {
                id: pop
                NumberAnimation { target: bigBall; property: "scale"; from: 0.5; to: 1.15; duration: 120; easing.type: Easing.OutBack }
                NumberAnimation { target: bigBall; property: "scale"; to: 1; duration: 90 }
            }
        }
        Column {
            anchors { left: bigBall.right; leftMargin: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
            NeonText {
                text: page.picks.length ? page.hitCount + " / " + page.picks.length + " HITS" : "PICK 1-10 NUMBERS"
                color: page.hitCount ? Neon.yellow : Neon.pink
                font.pixelSize: Theme.fontSizeMedium
                glow: 8
            }
            Text {
                text: page.drawing || page.drawn.length ? "BALL " + page.shown + " OF " + page.m.drawn : "TAP OR DRAG ACROSS THE BOARD"
                color: Neon.alpha(Neon.pink, 0.8)
                font { pixelSize: Theme.fontSizeTiny; letterSpacing: 2; family: Neon.display }
            }
        }
    }

    // ---- the board: 8 × 10 ----
    NeonPanel {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: board.height + 2 * Theme.paddingMedium
        glowColor: Neon.pink
        Grid {
            id: board
            x: Theme.paddingMedium; y: Theme.paddingMedium
            columns: 8
            spacing: 2
            property real cell: (parent.width - 2 * Theme.paddingMedium - 7 * spacing) / 8
            Repeater {
                model: 80
                Rectangle {
                    readonly property int n: index + 1
                    readonly property bool picked: page.picks.indexOf(n) >= 0
                    readonly property bool out: page.drawn.indexOf(n) >= 0
                    width: board.cell; height: board.cell * 0.8; radius: 4
                    color: picked && out ? Neon.alpha(Neon.yellow, 0.6) : picked ? Neon.alpha(Neon.pink, 0.45) : out ? Neon.alpha(Neon.cyan, 0.25) : Qt.rgba(0, 0, 0, 0.3)
                    border { width: picked ? 2 : 1; color: picked && out ? Neon.yellow : picked ? Neon.pink : Neon.alpha(Neon.cyan, out ? 0.8 : 0.25) }
                    scale: picked && out ? 1.08 : 1
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: parent.n
                        color: parent.picked || parent.out ? "white" : Neon.alpha("white", 0.6)
                        font { pixelSize: Theme.fontSizeExtraSmall; bold: parent.picked; family: Neon.display }
                    }
                }
            }
        }
        // tap or paint: the first cell decides whether the drag adds or removes
        MouseArea {
            anchors.fill: board
            preventStealing: true
            property var mode
            property int lastN: -1
            function cellAt(x, y) {
                var c = Math.floor(x / (board.cell + board.spacing)), r = Math.floor(y / (board.cell * 0.8 + board.spacing))
                if (c < 0 || c > 7 || r < 0 || r > 9) return -1
                return r * 8 + c + 1
            }
            onPressed: {
                var n = cellAt(mouse.x, mouse.y); lastN = n
                if (n < 0) return
                mode = page.picks.indexOf(n) < 0
                page.toggle(n, mode)
            }
            onPositionChanged: {
                var n = cellAt(mouse.x, mouse.y)
                if (n > 0 && n !== lastN) { lastN = n; page.toggle(n, mode) }
            }
        }
    }
    // paytable for the current number of picks
    SectionHeader { text: page.picks.length ? "Pays × bet with " + page.picks.length + " picks" : "Pick numbers to see the pays" }
    Flow {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        spacing: Theme.paddingMedium
        Repeater {
            model: Object.keys(page.payRow).sort(function (a, b) { return a - b })
            Text {
                text: modelData + " hit" + (modelData === "1" ? "" : "s") + ": " + page.payRow[modelData] + "×"
                color: page.hitCount === parseInt(modelData, 10) && page.drawn.length === page.m.drawn ? Neon.yellow : Neon.alpha(Neon.cyan, 0.9)
                font { pixelSize: Theme.fontSizeExtraSmall; bold: true; family: Neon.display }
            }
        }
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        BetSelector { id: bet; width: parent.width; locked: page.busy; color: Neon.yellow }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            height: Theme.itemSizeMedium
            property real w: (page.width - 2 * Theme.horizontalPageMargin - 2 * spacing) / 4
            NeonButton { width: parent.w; height: parent.height; text: "Clear"; color: Neon.violet; fontSize: Theme.fontSizeSmall; enabled: !page.drawing && page.picks.length; onClicked: { page.picks = []; page.drawn = [] } }
            NeonButton { width: parent.w; height: parent.height; text: "Quick"; color: Neon.cyan; fontSize: Theme.fontSizeSmall; enabled: !page.drawing; onClicked: page.quick() }
            NeonButton {
                width: parent.w * 2; height: parent.height
                text: page.drawing ? "Drawing…" : "Draw " + Money.fmt(bet.bet)
                color: Neon.pink; primary: true
                enabled: !page.drawing && page.picks.length > 0 && Game.canBet(bet.bet)
                onClicked: page.play()
            }
        }
    }
}
