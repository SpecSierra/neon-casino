import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// OVERLOAD (a crash game). Hold the core to stake and ride a multiplier that climbs
// faster and faster; let go to cash out before the system overloads.
// Crash point C = 0.95 / U (U uniform in (0,1]); C < 1 overloads at once. P(C ≥ x) = 0.95 / x,
// so every cash-out strategy returns exactly 95%. C is decided and saved at launch: quitting
// mid-ride pays the auto cash-out if the ride would have reached it, otherwise nothing.
TablePage {
    id: page
    title: "Overload"
    accent: Neon.yellow
    musicTrack: "overload"
    scene: "circuit"
    code: "CRASH · HOLD TO RIDE · 95% RTP"
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property real growth: Math.LN2 / 3.2       // ×2 every 3.2 s, then faster and faster
    readonly property var autoOptions: [0, 1.5, 2, 3, 5, 10]
    property int autoIndex: 0
    readonly property real auto: autoOptions[autoIndex]

    property string phase: "idle"        // idle | riding | crashed | cashed
    property real mult: 1.0
    property real crashAt: 1.0
    property real stake: 0
    property real t0: 0
    property var history: []
    property var trail: []               // multiplier samples for the chart
    busy: phase === "riding"

    function launch() {
        if (phase === "riding" || !Game.canBet(bet.bet)) return
        stake = bet.bet
        Game.stake(stake)
        var u = 1 - Math.random()                               // (0, 1]
        crashAt = Math.min(1000, Math.max(1, Math.floor(0.95 / u * 100) / 100))
        if (0.95 / u < 1) crashAt = 1.0
        Game.pending = { game: "overload", staked: stake, crash: crashAt, auto: auto,
                         returned: auto > 0 && auto <= crashAt ? Math.round(stake * auto * 100) / 100 : 0 }
        Game.save()
        mult = 1.0; trail = [1.0]
        t0 = Date.now()
        phase = "riding"
        Sound.play("reel"); Haptics.tap()
        if (crashAt <= 1.0) overload()
        else tick.start()
    }
    Timer {
        id: tick
        interval: 16; repeat: true
        onTriggered: {
            var t = (Date.now() - page.t0) / 1000
            var m = Math.floor(Math.exp(page.growth * t * (1 + t / 25)) * 100) / 100
            if (m >= page.crashAt) { page.mult = page.crashAt; page.overload(); return }
            page.mult = m
            if (page.auto > 0 && m >= page.auto) { page.cashOut(page.auto); return }
            if (page.trail.length === 0 || t * 10 > page.trail.length) page.trail = page.trail.concat([m])
            if (Math.floor(m) > Math.floor(page.trail[page.trail.length - 2] || 1)) Haptics.tick()
        }
    }
    function cashOut(at) {
        if (phase !== "riding") return
        tick.stop()
        var m = at || mult
        phase = "cashed"
        var returned = Math.round(stake * m * 100) / 100
        history = [{ c: crashAt, won: true }].concat(history).slice(0, 10)
        page.burst.show(returned - stake, m >= 5)
        Game.best("bestCashout", m)
        Game.settle(stake, returned, "overload")
    }
    function overload() {
        tick.stop()
        phase = "crashed"
        history = [{ c: crashAt, won: false }].concat(history).slice(0, 10)
        Sound.play("bust"); Haptics.rumble(4)
        crashFlash.restart()
        Game.count("overloads")
        Game.settle(stake, 0, "overload")
    }

    // ---- display ----
    NeonPanel {
        id: screen
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 0.9
        glowColor: page.phase === "crashed" ? Neon.red : page.mult >= 5 ? Neon.pink : Neon.yellow
        glowStrength: page.phase === "riding" ? 0.6 + Math.min(0.4, (page.mult - 1) / 10) : 0.4

        Canvas {
            id: chart
            anchors { fill: parent; margins: Theme.paddingLarge }
            property var pts: page.trail
            property bool dead: page.phase === "crashed"
            onPtsChanged: requestPaint()
            onDeadChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d"); ctx.reset()
                var v = pts; if (!v || v.length < 2) return
                var top = Math.max(2, v[v.length - 1] * 1.15), n = Math.max(30, v.length)
                function X(i) { return width * i / (n - 1) }
                function Y(x) { return height * (1 - Math.log(x) / Math.log(top)) }
                ctx.strokeStyle = "rgba(255,255,255,0.12)"; ctx.lineWidth = 1
                for (var g = 2; g < top; g *= 2) { ctx.beginPath(); ctx.moveTo(0, Y(g)); ctx.lineTo(width, Y(g)); ctx.stroke() }
                var col = dead ? "255,51,85" : "248,255,58"
                for (var pass = 0; pass < 2; ++pass) {
                    ctx.beginPath(); ctx.moveTo(X(0), Y(v[0]))
                    for (var i = 1; i < v.length; ++i) ctx.lineTo(X(i), Y(v[i]))
                    ctx.strokeStyle = pass ? "rgba(" + col + ",1)" : "rgba(" + col + ",0.3)"
                    ctx.lineWidth = pass ? 3 : 12
                    ctx.stroke()
                }
            }
        }
        // pulsing core behind the number
        Rectangle {
            id: core
            anchors.centerIn: parent
            width: parent.width * (0.35 + Math.min(0.4, Math.log(page.mult) / 8)); height: width; radius: width / 2
            color: "transparent"
            border { width: 4; color: screen.glowColor }
            opacity: 0.5
            SequentialAnimation on scale {
                running: page.phase === "riding"; loops: Animation.Infinite
                NumberAnimation { to: 1.08; duration: Math.max(80, 400 / page.mult) }
                NumberAnimation { to: 1.0; duration: Math.max(80, 400 / page.mult) }
            }
        }
        NeonText {
            id: big
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: page.phase === "riding" && page.mult > 5 ? (Math.random() - 0.5) * page.mult : 0
            text: page.phase === "crashed" ? "OVERLOAD" : page.mult.toFixed(2) + "×"
            color: screen.glowColor
            font.pixelSize: page.phase === "crashed" ? Theme.fontSizeExtraLarge * 1.3 : Theme.fontSizeHuge * 1.5
            glow: 18
        }
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: big.bottom; topMargin: Theme.paddingSmall }
            text: page.phase === "riding" ? "CASH OUT " + Money.fmt(page.stake * page.mult)
                  : page.phase === "crashed" ? "CRASHED AT " + page.crashAt.toFixed(2) + "×"
                  : page.phase === "cashed" ? "CASHED OUT · it would have run to " + page.crashAt.toFixed(2) + "×"
                  : "HOLD THE CORE TO RIDE"
            color: Neon.alpha(screen.glowColor, 0.85)
            font { pixelSize: Theme.fontSizeExtraSmall; bold: true; letterSpacing: 2; family: Neon.display }
        }
        Rectangle {
            id: flash
            anchors.fill: parent
            color: Neon.red
            opacity: 0
            SequentialAnimation {
                id: crashFlash
                NumberAnimation { target: flash; property: "opacity"; from: 0.6; to: 0; duration: 700 }
            }
        }
    }
    // last results
    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall
        Repeater {
            model: page.history
            Text {
                text: modelData.c.toFixed(2) + "×"
                color: modelData.c >= 2 ? Neon.green : Neon.red
                opacity: modelData.won ? 1 : 0.6
                font { pixelSize: Theme.fontSizeExtraSmall; bold: true; family: Neon.display }
            }
        }
    }
    SectionHeader { text: "Auto cash-out" }
    Segmented {
        x: Theme.horizontalPageMargin; width: parent.width - 2 * x
        color: Neon.yellow
        labels: page.autoOptions.map(function (v) { return v ? v + "×" : "OFF" })
        current: page.autoIndex
        enabled: page.phase !== "riding"
        onPicked: page.autoIndex = index
    }
    Label {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        wrapMode: Text.Wrap
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.secondaryColor
        text: "Press and hold the core to stake and launch. The multiplier climbs faster the longer you ride; let go to cash out. "
              + "If it overloads first, the stake is gone. Pays back 95% on average however you play. "
              + "If you leave mid-ride, the auto cash-out still counts."
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        BetSelector { id: bet; width: parent.width; locked: page.busy; color: Neon.yellow }
        // the hold pad
        MouseArea {
            id: pad
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            height: Theme.itemSizeLarge
            preventStealing: true
            enabled: page.phase === "riding" || Game.canBet(bet.bet)
            onPressed: page.launch()
            onReleased: if (page.phase === "riding") page.cashOut()
            onCanceled: if (page.phase === "riding") page.cashOut()
            NeonPanel {
                anchors.fill: parent
                glowColor: page.phase === "riding" ? Neon.green : Neon.yellow
                glowStrength: pad.pressed ? 1 : 0.6
                strong: true
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 2 }
                    width: page.phase === "riding" ? (parent.width - 4) * Math.min(1, Math.log(page.mult) / Math.log(10)) : 0
                    color: Neon.alpha(Neon.green, 0.3)
                }
            }
            Text {
                anchors.centerIn: parent
                text: page.phase === "riding" ? "LET GO TO CASH OUT" : "HOLD TO RIDE · " + Money.fmt(bet.bet)
                color: page.phase === "riding" ? Neon.green : Neon.yellow
                font { pixelSize: Theme.fontSizeMedium; bold: true; letterSpacing: 2; family: Neon.display }
            }
            opacity: enabled ? 1 : 0.4
        }
    }
}
