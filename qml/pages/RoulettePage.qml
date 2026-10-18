import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Roulette.js" as R
import "../js/Money.js" as Money

TablePage {
    id: page
    title: "Roulette"
    accent: Neon.red
    scene: "velvet"
    musicTrack: "roulette"
    footerHeight: footerCol.height + Theme.paddingLarge

    property var bets: ({})
    property var lastBets: ({})
    property var history: []
    // Chips follow your balance live: about 1%, 5%, 20% and 50% of it, on a 1-2-2.5-5 ladder.
    property int chipIndex: 0
    readonly property var chipValues: {
        var b = Game.balance, out = []
        var fr = [0.01, 0.05, 0.2, 0.5]
        for (var i = 0; i < fr.length; ++i) {
            var v = Math.max(Game.minBet, niceFloor(b * fr[i]))
            if (out.indexOf(v) < 0) out.push(v)
        }
        return out
    }
    readonly property real chip: chipValues[Math.min(chipIndex, chipValues.length - 1)]
    function niceFloor(v) {
        if (v < 1) return 1
        var p = Math.pow(10, Math.floor(Math.log(v) / Math.LN10 + 1e-9))
        var steps = p >= 10 ? [5, 2.5, 2, 1] : [5, 2, 1]
        for (var i = 0; i < steps.length; ++i) if (steps[i] * p <= v + 1e-9) return steps[i] * p
        return p
    }
    property int lastResult: -1
    property int flashN: -1             // winning number lit on the board until the next bet
    readonly property real total: sum(bets)
    showHeader: false
    // Everything fits on one screen: wheel + 16 board rows share the height left over
    // after the HUD and the footer.
    readonly property real wheelSize: Math.min(width * 0.46, height * 0.19)
    readonly property real cellH: Math.max(Theme.paddingMedium * 2,
        (height - footerHeight - Theme.paddingSmall - Theme.itemSizeMedium - (wheelSize + 2 * Theme.paddingMedium)
         - 4 * Theme.paddingMedium - Theme.paddingLarge - 15 * 2 - 2) / 16)

    function sum(b) { var t = 0; for (var k in b) t += b[k]; return t }
    function place(key) {
        if (busy) return
        if (total + chip > Game.balance + 1e-9) { Game.note("NOT ENOUGH CREDITS", Neon.red); return }
        flashN = -1
        var b = {}; for (var k in bets) b[k] = bets[k]
        b[key] = (b[key] || 0) + chip
        bets = b
        Sound.play("tick")
    }
    function removeBet(key) {
        if (busy || !bets[key]) return
        var b = {}; for (var k in bets) if (k !== key) b[k] = bets[k]
        bets = b
    }
    function spin() {
        if (busy || total < Game.minBet || total > Game.balance + 1e-9) return
        busy = true
        lastBets = bets
        Game.stake(total)
        var n = Math.floor(Math.random() * 37), returned = 0
        for (var k in bets) returned += R.payout(k, bets[k], n, Game.perks)
        Game.pending = { game: "roulette", staked: total, returned: Math.round(returned * 100) / 100, n: n }
        Game.save()                       // decided before the wheel turns
        wheel.resetBall()
        wheel.spinTo(n)
        Sound.play("reel")
    }
    function landed(n) {
        lastResult = n
        flashN = n
        Haptics.tap()
        resultPop.restart()
        history = [n].concat(history).slice(0, 12)
        var returned = Game.pending.returned, staked = Game.pending.staked
        for (var k in bets) if (k.indexOf("n:") === 0 && R.covers(k, n)) Game.count("straightHits")
        if (n === 0) Game.count("zeros")
        if (returned > staked) page.burst.show(returned - staked, returned - staked >= staked * 5)
        else if (returned < staked) Sound.play("lose")
        bets = ({})
        busy = false
        Game.settle(staked, returned, "roulette")
    }
    function chipLabel(v) {
        if (v >= 1e9) return +(v / 1e9).toFixed(1) + "B"
        if (v >= 1e6) return +(v / 1e6).toFixed(1) + "M"
        if (v >= 1e3) return +(v / 1e3).toFixed(1) + "K"
        return String(v)
    }
    function cellColor(n) {
        var c = R.colorOf(n)
        return c === "red" ? Neon.red : c === "green" ? Neon.green : Neon.violet
    }

    // wheel + result
    NeonPanel {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: wheel.height + 2 * Theme.paddingMedium
        glowColor: Neon.red
        Wheel {
            id: wheel
            x: Theme.paddingLarge; y: Theme.paddingMedium
            width: page.wheelSize; height: width
            onLanded: page.landed(n)
        }
        Column {
            anchors { left: wheel.right; right: parent.right; margins: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
            spacing: Theme.paddingSmall
            Text {
                text: "RESULT"; color: Neon.alpha(Neon.cyan, 0.7)
                font { pixelSize: Theme.fontSizeTiny; letterSpacing: 3; family: Neon.display }
            }
            NeonText {
                id: resultText
                text: page.busy ? "···" : (page.lastResult < 0 ? "--" : String(page.lastResult))
                color: page.busy || page.lastResult < 0 ? Neon.cyan : page.cellColor(page.lastResult)
                font.pixelSize: Theme.fontSizeHuge * 1.2
                glow: 14
            }
            Text {
                text: "TAP A NUMBER, OR A LINE BETWEEN NUMBERS · HOLD TO CLEAR"
                width: parent.width; wrapMode: Text.Wrap
                color: Neon.alpha(Neon.cyan, 0.6)
                font { pixelSize: Theme.fontSizeTiny; family: Neon.display }
            }
            Flow {
                width: parent.width
                spacing: 4
                Repeater {
                    model: page.history
                    Rectangle {
                        width: Theme.iconSizeSmall; height: width; radius: width / 2
                        color: Neon.alpha(page.cellColor(modelData), 0.35)
                        border { width: 1; color: page.cellColor(modelData) }
                        Text {
                            anchors.centerIn: parent; text: modelData; color: "white"
                            font { pixelSize: Theme.fontSizeTiny; bold: true }
                        }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: resultPop
        NumberAnimation { target: resultText; property: "scale"; from: 0.2; to: 1.35; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        NumberAnimation { target: resultText; property: "scale"; to: 1; duration: 250 }
    }
    // betting board
    Column {
        id: board
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        spacing: 2
        property real cw: (width - 4) / 3

        BetCell { table: page; width: parent.width; height: page.cellH; key: "n:0"; label: "0"; tint: Neon.green }
        Item {
            width: numbers.width; height: numbers.height
            Grid {
                id: numbers
                columns: 3; spacing: 2
                Repeater {
                    model: 36
                    BetCell { table: page;
                        width: board.cw; height: page.cellH
                        key: "n:" + (index + 1); label: String(index + 1)
                        tint: page.cellColor(index + 1)
                    }
                }
            }
            // inside bets on the lines: row r (0..11) holds 3r+1 .. 3r+3, left to right
            Item {
                id: lines
                anchors.fill: numbers
                readonly property real pw: board.cw + 2       // cell pitch
                readonly property real ph: page.cellH + 2
                readonly property real d: Math.min(page.cellH * 0.85, Theme.paddingLarge * 1.6)
                function n(r, c) { return 3 * r + c + 1 }
                // splits across a vertical line: n | n+1
                Repeater {
                    model: 24
                    BetSpot {
                        readonly property int r: Math.floor(index / 2)
                        readonly property int c: index % 2
                        table: page; size: lines.d
                        key: "m:" + lines.n(r, c) + "," + (lines.n(r, c) + 1)
                        x: (c + 1) * lines.pw - 1 - width / 2; y: r * lines.ph + page.cellH / 2 - height / 2
                    }
                }
                // splits across a horizontal line: n over n+3
                Repeater {
                    model: 33
                    BetSpot {
                        readonly property int r: Math.floor(index / 3)
                        readonly property int c: index % 3
                        table: page; size: lines.d
                        key: "m:" + lines.n(r, c) + "," + (lines.n(r, c) + 3)
                        x: c * lines.pw + board.cw * 0.5 - width / 2; y: (r + 1) * lines.ph - 1 - height / 2
                    }
                }
                // corners where four numbers meet
                Repeater {
                    model: 22
                    BetSpot {
                        readonly property int r: Math.floor(index / 2)
                        readonly property int c: index % 2
                        readonly property int a: lines.n(r, c)
                        table: page; size: lines.d
                        key: "m:" + a + "," + (a + 1) + "," + (a + 3) + "," + (a + 4)
                        x: (c + 1) * lines.pw - 1 - width / 2; y: (r + 1) * lines.ph - 1 - height / 2
                    }
                }
                // streets (a row of three) and six lines (two rows) on the left edge
                Repeater {
                    model: 12
                    BetSpot {
                        readonly property int a: 3 * index + 1
                        table: page; size: lines.d
                        key: "m:" + a + "," + (a + 1) + "," + (a + 2)
                        x: -width * 0.35; y: index * lines.ph + page.cellH / 2 - height / 2
                    }
                }
                Repeater {
                    model: 11
                    BetSpot {
                        readonly property int a: 3 * index + 1
                        table: page; size: lines.d
                        key: "m:" + [a, a + 1, a + 2, a + 3, a + 4, a + 5].join(",")
                        x: -width * 0.35; y: (index + 1) * lines.ph - 1 - height / 2
                    }
                }
            }
        }
        Row {
            spacing: 2
            Repeater {
                model: 3
                BetCell { table: page; width: board.cw; height: page.cellH; key: "col:" + (index + 1); label: "2:1 COL"; tint: Neon.cyan; small: true }
            }
        }
        Row {
            spacing: 2
            Repeater {
                model: ["1st 12", "2nd 12", "3rd 12"]
                BetCell { table: page; width: board.cw; height: page.cellH; key: "doz:" + (index + 1); label: modelData; tint: Neon.yellow; small: true }
            }
        }
        Row {
            spacing: 2
            property real w6: (board.width - 10) / 6
            Repeater {
                model: [["low", "1-18"], ["even", "EVEN"], ["red", "RED"], ["black", "BLK"], ["odd", "ODD"], ["high", "19-36"]]
                BetCell { table: page;
                    width: parent.w6; height: page.cellH; key: modelData[0]; label: modelData[1]; small: true
                    tint: modelData[0] === "red" ? Neon.red : modelData[0] === "black" ? Neon.violet : Neon.pink
                }
            }
        }
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
                    property real value: modelData
                    width: Theme.itemSizeSmall; height: width
                    onClicked: { page.chipIndex = index; Sound.play("click"); Haptics.tick() }
                    Image {
                        anchors.fill: parent
                        source: "../images/sym-chip.png"
                        opacity: page.chip === parent.value ? 1 : 0.45
                        scale: page.chip === parent.value ? 1.1 : 0.9
                        Behavior on scale { NumberAnimation { duration: 120 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: page.chipLabel(parent.value)
                        color: "white"
                        font { pixelSize: Theme.fontSizeExtraSmall; bold: true; family: Neon.display }
                    }
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            height: Theme.itemSizeMedium
            property real w: (page.width - 2 * Theme.horizontalPageMargin - 2 * spacing) / 4
            NeonButton {
                width: parent.w; height: parent.height; text: "Clear"; color: Neon.violet; fontSize: Theme.fontSizeSmall
                enabled: !page.busy && page.total > 0
                onClicked: page.bets = ({})
            }
            NeonButton {
                width: parent.w; height: parent.height; text: "Rebet"; color: Neon.cyan; fontSize: Theme.fontSizeSmall
                enabled: !page.busy && page.sum(page.lastBets) > 0 && page.sum(page.lastBets) <= Game.balance
                onClicked: page.bets = page.lastBets
            }
            NeonButton {
                width: parent.w * 2; height: parent.height
                text: page.busy ? "Rolling…" : "Spin " + Money.fmt(page.total)
                color: Neon.red; primary: true
                enabled: !page.busy && page.total >= Game.minBet && page.total <= Game.balance + 1e-9
                onClicked: page.spin()
            }
        }
    }
}
