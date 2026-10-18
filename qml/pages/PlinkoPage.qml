import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Plinko.js" as Plinko
import "../js/PlinkoConfig.js" as Config
import "../js/Money.js" as Money

// Plinko: the ball bounces left or right off 12 rows of pegs into a pay slot. Three risk
// tables, each tuned exactly to 97% (tools/plinkosim.py). The path is decided and saved at the drop.
TablePage {
    id: page
    title: "Plinko"
    accent: Neon.cyan
    scene: "ways"
    musicTrack: "plinko"
    code: "12 ROWS · LOW / MEDIUM / HIGH RISK · 97% RTP"
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property var risks: ["low", "medium", "high"]
    property int riskIndex: 1
    readonly property var table: Config.tables[risks[riskIndex]]
    readonly property int rows: Config.rows
    property var history: []
    property int landed: -1               // the slot that last caught a ball (flashes)
    property int seq: 0
    readonly property int inFlight: balls.count
    busy: false                           // balls can keep falling while you leave or bet on

    ListModel { id: balls }               // { bid, path (array as JSON), step, slot, staked, returned, mult }

    // Each ball is decided and saved (Game.pendingList) the moment it's dropped.
    function drop() {
        if (!Game.canBetMulti(bet.bet)) return false
        var stake = bet.bet
        Game.stake(stake)
        var path = Plinko.path(rows), s = Plinko.slot(path), mult = table[s]
        var id = "plinko-" + Date.now() + "-" + (++seq)
        var ret = Math.round(stake * mult * 100) / 100
        Game.addPending({ id: id, game: "plinko", staked: stake, returned: ret })
        balls.append({ bid: id, path: JSON.stringify(path), slot: s, staked: stake, returned: ret, mult: mult })
        Sound.play("tick")
        return true
    }
    // a ball's animation ends -> it lands here; removal waits a tick so the delegate isn't
    // destroyed inside its own signal handler
    property var arrived: []
    function arrive(bid) { arrived = arrived.concat([bid]); flush.restart() }
    Timer {
        id: flush; interval: 1
        onTriggered: {
            var a = page.arrived; page.arrived = []
            for (var k = 0; k < a.length; ++k)
                for (var i = balls.count - 1; i >= 0; --i)
                    if (balls.get(i).bid === a[k]) { page.land(balls.get(i)); balls.remove(i); break }
        }
    }
    property double lastTick: 0
    function peg() { var now = Date.now(); if (now - lastTick > 45) { lastTick = now; Sound.play("tick") } }
    function land(b) {
        landed = b.slot
        landFlash.restart()
        history = [b.mult].concat(history).slice(0, 14)
        var r = Game.takePending(b.bid)
        if (!r) return
        if (b.returned > b.staked) { if (b.mult >= 5) page.burst.show(b.returned - b.staked, true); else Sound.play("win") }
        if (b.mult >= 2) Haptics.tap(); else Haptics.tick()
        Game.settle(r.staked, r.returned, "plinko")
    }
    Timer { id: landFlash; interval: 400; onTriggered: page.landed = -1 }
    // leaving with balls still falling: they land at once
    Component.onDestruction: {
        while (balls.count) { var b = balls.get(0); var r = Game.takePending(b.bid); if (r) Game.settle(r.staked, r.returned, "plinko"); balls.remove(0) }
    }
    // horizontal offset (in peg gaps) after each bounce: offsets[0] is the drop point
    function offsets(pathJson) {
        var p = JSON.parse(pathJson), r = 0, out = [0]
        for (var i = 0; i < rows; ++i) { r += p[i] ? 0.5 : -0.5; out.push(r) }
        return out
    }

    NeonPanel {
        id: boardPanel
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 1.0
        glowColor: Neon.cyan
        Item {
            id: board
            anchors { fill: parent; margins: Theme.paddingLarge }
            readonly property real gap: width / (page.rows + 2)
            readonly property real rowH: (height - slotRow.height - Theme.paddingSmall) / (page.rows + 1)
            // pegs
            Repeater {
                model: page.rows
                Item {
                    readonly property int r: index
                    Repeater {
                        model: r + 3
                        Rectangle {
                            width: board.gap * 0.18; height: width; radius: width / 2
                            x: board.width / 2 + (index - (r + 2) / 2) * board.gap - width / 2
                            y: (r + 1) * board.rowH - height / 2
                            color: Neon.alpha("white", 0.75)
                        }
                    }
                }
            }
            // the balls
            // each ball runs its own animation at frame rate: t goes 0 -> rows, one unit per
            // peg row; between rows it hops in a small arc and drifts half a gap sideways
            Repeater {
                model: balls
                Rectangle {
                    id: ball
                    readonly property string bid: model.bid
                    readonly property var off: page.offsets(model.path)
                    property real t: 0
                    readonly property int s: Math.min(page.rows - 1, Math.floor(t))
                    readonly property real f: t - s
                    width: board.gap * 0.42; height: width; radius: width / 2
                    x: board.width / 2 + (off[s] + (off[s + 1] - off[s]) * f) * board.gap - width / 2
                    // fall one row under gravity (f²) with a little bounce up off the peg (sin)
                    y: (s + f * f) * board.rowH + board.rowH - height - 2 - Math.sin(Math.PI * f) * board.rowH * 0.35
                    color: model.index % 3 === 0 ? Neon.yellow : model.index % 3 === 1 ? Neon.pink : Neon.cyan
                    border { width: 2; color: "white" }
                    onSChanged: page.peg()
                    NumberAnimation on t {
                        from: 0; to: page.rows; duration: page.rows * 120
                        running: true
                        onStopped: page.arrive(ball.bid)
                    }
                }
            }
            // pay slots
            Row {
                id: slotRow
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                spacing: 2
                Repeater {
                    model: page.table
                    Rectangle {
                        readonly property real v: modelData
                        width: (board.width - 12 * 2) / 13; height: Theme.itemSizeExtraSmall * 0.7
                        color: Neon.alpha(v >= 5 ? Neon.red : v >= 1.5 ? Neon.yellow : v >= 1 ? Neon.green : Neon.violet, index === page.landed ? 0.85 : 0.25)
                        border { width: index === page.landed ? 2 : 1; color: v >= 5 ? Neon.red : v >= 1.5 ? Neon.yellow : v >= 1 ? Neon.green : Neon.violet }
                        scale: index === page.landed ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Text {
                            anchors.centerIn: parent
                            text: v >= 10 ? Math.round(v) : v
                            color: "white"
                            font { family: Neon.mono; pixelSize: Theme.fontSizeTiny * 0.85 }
                        }
                    }
                }
            }
            MouseArea {        // tap or swipe down on the board to drop
                anchors.fill: parent
                property real y0
                onPressed: y0 = mouse.y
                onClicked: page.drop()
            }
        }
    }
    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall
        Repeater {
            model: page.history
            Text {
                text: modelData + "×"
                color: modelData >= 1 ? Neon.green : Neon.red
                font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall }
            }
        }
    }
    SectionHeader { text: "Risk" }
    Segmented {
        x: Theme.horizontalPageMargin; width: parent.width - 2 * x
        color: Neon.cyan
        labels: ["LOW", "MEDIUM", "HIGH"]
        current: page.riskIndex
        enabled: page.inFlight === 0
        onPicked: page.riskIndex = index
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        BetSelector { id: bet; width: parent.width; locked: page.busy; color: Neon.yellow }
        NeonButton {
            id: dropKey
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            height: Theme.itemSizeMedium
            text: page.inFlight ? "Drop · " + page.inFlight + " falling · hold to spam" : "Drop " + Money.fmt(bet.bet) + " · hold to spam"
            color: Neon.cyan; primary: true
            fontSize: Theme.fontSizeSmall
            enabled: Game.canBetMulti(bet.bet)
            onClicked: page.drop()
            onPressAndHold: spam.start()
            onReleased: spam.stop()
            onCanceled: spam.stop()
            Timer { id: spam; interval: 180; repeat: true; triggeredOnStart: true; onTriggered: if (!page.drop()) stop() }
        }
    }
}
