import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/MoneyWheel.js" as MW
import "../js/Money.js" as Money

// Money wheel: chip up the numbers, then flick the wheel (or tap Spin). The stop is decided and
// saved before the wheel moves. Each number pays its value × the chip, stake included.
TablePage {
    id: page
    title: "Money wheel"
    accent: Neon.yellow
    scene: "velvet"
    musicTrack: "wheel"
    code: "51 SEGMENTS · FLICK TO SPIN · 94-98% RTP"
    info: "Put chips on one or more numbers, then flick the wheel. If it stops on a number you backed, that bet "
          + "returns the number × your chip (a ¤10 chip on 12 returns ¤120). The rarer the number, the bigger the pay. "
          + "Long-press a number to take its chips back."
    footerHeight: footerCol.height + Theme.paddingLarge

    property var bets: ({})
    property var lastBets: ({})
    property bool spinning: false
    property int result: -1
    property var history: []
    property int chipIndex: 0
    readonly property real total: sum(bets)
    readonly property real seg: 360 / MW.segments.length
    busy: spinning

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
    function chipLabel(v) {
        if (v >= 1e9) return +(v / 1e9).toFixed(1) + "B"
        if (v >= 1e6) return +(v / 1e6).toFixed(1) + "M"
        if (v >= 1e3) return +(v / 1e3).toFixed(1) + "K"
        return String(v)
    }
    function place(key) {
        if (spinning) return
        if (total + chip > Game.balance + 1e-9) { Game.note("NOT ENOUGH CREDITS", Neon.red); return }
        var b = {}; for (var k in bets) b[k] = bets[k]
        b[key] = (b[key] || 0) + chip
        bets = b
        Sound.play("tick"); Haptics.tick()
    }
    function clearSpot(key) { if (spinning || !bets[key]) return; var b = {}; for (var k in bets) if (k !== key) b[k] = bets[k]; bets = b }

    function spin(power) {
        if (spinning || total < Game.minBet || !Game.canBet(Game.minBet) || total > Game.balance + 1e-9) return
        lastBets = bets
        Game.stake(total)
        var i = MW.spin(), v = MW.segments[i], returned = 0
        if (bets[String(v)]) returned = bets[String(v)] * v
        Game.pending = { game: "wheel", staked: total, returned: Math.round(returned * 100) / 100, stop: i }
        Game.save()
        result = -1
        spinning = true
        // land segment i under the pointer, after 3-6 full turns depending on the flick
        var p = power === undefined ? 0.5 : power
        var cur = wheel.rotation, want = 360 - (i + 0.5) * seg + (Math.random() - 0.5) * seg * 0.7
        var delta = ((want - cur) % 360 + 360) % 360
        turn.to = cur + 360 * Math.round(3 + 3 * p) + delta
        turn.duration = 3600 + 1800 * p
        turn.restart()
        Sound.play("card"); Haptics.tap()
    }
    function landed() {
        spinning = false
        var p = Game.pending
        result = p.stop
        var v = MW.segments[p.stop]
        history = [v].concat(history).slice(0, 12)
        Game.note(v + "× · " + (p.returned > 0 ? "WIN" : "NO LUCK"), MW.colors[v])
        if (p.returned > p.staked) page.burst.show(p.returned - p.staked, v >= 25)
        else if (p.returned < p.staked) Sound.play("lose")
        Haptics.tap()
        bets = ({})
        Game.settle(p.staked, p.returned, "wheel")
    }

    // ---- the wheel ----
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Math.min(width * 0.86, page.height * 0.42)
        Item {
            id: rim
            width: parent.height; height: width
            anchors.centerIn: parent
            Rectangle {
                anchors.fill: parent; radius: width / 2
                color: "transparent"
                border { width: Theme.paddingSmall; color: Neon.alpha(Neon.yellow, 0.8) }
            }
            Item {
                id: wheel
                anchors { fill: parent; margins: Theme.paddingSmall * 1.5 }
                property int lastSeg: 0
                onRotationChanged: {
                    var s = Math.floor(rotation / page.seg)
                    if (s !== lastSeg && page.spinning) { lastSeg = s; Sound.play("tick") }
                }
                NumberAnimation { id: turn; target: wheel; property: "rotation"; easing.type: Easing.OutQuart; onStopped: page.landed() }
                Canvas {
                    id: face
                    anchors.fill: parent
                    renderStrategy: Canvas.Cooperative
                    onWidthChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"), r = width / 2, n = MW.segments.length, a = 2 * Math.PI / n
                        ctx.reset()
                        ctx.translate(r, r)
                        for (var i = 0; i < n; ++i) {
                            var v = MW.segments[i], c = MW.colors[v]
                            var a0 = -Math.PI / 2 + i * a, a1 = a0 + a
                            ctx.beginPath(); ctx.moveTo(0, 0); ctx.arc(0, 0, r, a0, a1, false); ctx.closePath()
                            ctx.fillStyle = Qt.rgba(0.04, 0.02, 0.1, 0.92); ctx.fill()
                            ctx.lineWidth = 1; ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.25); ctx.stroke()
                            ctx.beginPath(); ctx.arc(0, 0, r * 0.97, a0 + 0.01, a1 - 0.01, false)
                            ctx.lineWidth = r * 0.05; ctx.strokeStyle = c; ctx.stroke()
                            ctx.save()
                            ctx.rotate(a0 + a / 2 + Math.PI / 2)
                            ctx.fillStyle = c
                            ctx.font = "bold " + Math.round(r * (v >= 10 ? 0.085 : 0.1)) + "px \"" + Neon.mono + "\""
                            ctx.textAlign = "center"
                            ctx.fillText(String(v), 0, -r * 0.78)
                            ctx.restore()
                        }
                        ctx.beginPath(); ctx.arc(0, 0, r * 0.3, 0, 2 * Math.PI, false)
                        ctx.fillStyle = Qt.rgba(0.06, 0.02, 0.14, 1); ctx.fill()
                        ctx.lineWidth = 3; ctx.strokeStyle = Neon.yellow; ctx.stroke()
                    }
                }
            }
            NeonText {
                anchors.centerIn: parent
                text: page.result >= 0 ? MW.segments[page.result] + "×" : "¤"
                color: page.result >= 0 ? MW.colors[MW.segments[page.result]] : Neon.yellow
                font.pixelSize: Theme.fontSizeExtraLarge
            }
            // the pointer
            Canvas {
                width: Theme.paddingLarge * 2; height: Theme.paddingLarge * 2.2
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: -Theme.paddingSmall }
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(width, 0); ctx.lineTo(width / 2, height); ctx.closePath()
                    ctx.fillStyle = "white"; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = Neon.pink; ctx.stroke()
                }
            }
            MouseArea {           // flick to spin
                anchors.fill: parent
                property real x0; property real y0; property real t0
                onPressed: { x0 = mouse.x; y0 = mouse.y; t0 = Date.now() }
                onReleased: {
                    var dx = mouse.x - x0, dy = mouse.y - y0, dist = Math.sqrt(dx * dx + dy * dy)
                    if (dist > Theme.itemSizeSmall * 0.6) page.spin(Math.min(1, dist / Math.max(1, Date.now() - t0) / 3))
                }
            }
        }
    }

    // ---- the board ----
    Grid {
        id: boardGrid
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        columns: 3; spacing: 3
        Repeater {
            model: MW.labels
            SpotCell {
                width: (boardGrid.width - 6) / 3; height: Theme.itemSizeSmall * 1.05
                key: String(modelData); label: modelData + "×"
                sub: MW.counts[modelData] + " OF 51"
                tint: MW.colors[modelData]
            }
        }
    }
    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall
        Text { text: "STOPS"; color: Neon.alpha(Neon.yellow, 0.7); font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 2 } }
        Repeater {
            model: page.history
            Text { text: modelData; color: MW.colors[modelData]; font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall } }
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
                    width: Theme.itemSizeSmall; height: width
                    onClicked: { page.chipIndex = index; Sound.play("click"); Haptics.tick() }
                    Image { anchors.fill: parent; source: "../images/sym-chip.png"; opacity: index === page.chipIndex ? 1 : 0.45; scale: index === page.chipIndex ? 1.1 : 0.9 }
                    Text { anchors.centerIn: parent; text: page.chipLabel(modelData); color: "white"; font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall; bold: true } }
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            height: Theme.itemSizeMedium
            property real w: (page.width - 2 * Theme.horizontalPageMargin - 2 * spacing) / 4
            NeonButton { width: parent.w; height: parent.height; text: "Clear"; color: Neon.violet; fontSize: Theme.fontSizeSmall; enabled: !page.spinning && page.total > 0; onClicked: page.bets = ({}) }
            NeonButton {
                width: parent.w; height: parent.height; text: "Rebet"; color: Neon.cyan; fontSize: Theme.fontSizeSmall
                enabled: !page.spinning && page.sum(page.lastBets) > 0 && page.sum(page.lastBets) <= Game.balance
                onClicked: page.bets = page.lastBets
            }
            NeonButton {
                width: parent.w * 2; height: parent.height
                text: page.spinning ? "Spinning…" : "Spin " + Money.fmt(page.total)
                color: Neon.yellow; primary: true
                enabled: !page.spinning && page.total >= Game.minBet && page.total <= Game.balance + 1e-9
                onClicked: page.spin(0.5)
            }
        }
    }
}
