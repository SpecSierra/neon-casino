import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// Darts: flick a dart up at the board (or tap Throw). Where it lands is drawn and saved before
// it leaves your hand; each ring pays its multiplier (96.9% RTP over all throws).
TablePage {
    id: page
    title: "Darts"
    accent: Neon.cyan
    scene: "circuit"
    musicTrack: "darts"
    code: "FLICK UP TO THROW · BULLSEYE 8.3× · 97% RTP"
    info: "Flick upward from the bottom of the board area (or tap Throw). Payouts: off the board 0×, outer ring 0.5×, "
          + "inner ring 1×, the triple ring 2.1×, the bull ring 3.3×, the bullseye 8.3×. "
          + "Odds per throw: 25% miss, 35% outer, 22% inner, 10% triple, 6% bull ring, 2% bullseye."
    footerHeight: footerCol.height + Theme.paddingLarge

    // zones from the centre out: [inner radius, outer radius] in board radii, pay, chance
    readonly property var zones: [
        { id: "bull", r0: 0, r1: 0.07, pay: 8.3, p: 0.02, name: "BULLSEYE" },
        { id: "bullring", r0: 0.07, r1: 0.16, pay: 3.3, p: 0.06, name: "BULL RING" },
        { id: "inner", r0: 0.16, r1: 0.52, pay: 1, p: 0.22, name: "INNER" },
        { id: "triple", r0: 0.52, r1: 0.62, pay: 2.1, p: 0.10, name: "TRIPLE" },
        { id: "outer", r0: 0.62, r1: 1.0, pay: 0.5, p: 0.35, name: "OUTER" },
        { id: "miss", r0: 1.05, r1: 1.25, pay: 0, p: 0.25, name: "MISS" }
    ]
    property bool throwing: false
    property real hitX: 0
    property real hitY: 0
    property int hitZone: -1
    property var marks: []
    property var history: []
    busy: throwing

    function toss() {
        if (throwing || !Game.canBet(bet.bet)) return false
        var stake = bet.bet
        Game.stake(stake)
        var x = Math.random(), z = zones.length - 1
        for (var i = 0; i < zones.length; ++i) { x -= zones[i].p; if (x < 0) { z = i; break } }
        var r = zones[z].r0 + Math.random() * (zones[z].r1 - zones[z].r0), a = Math.random() * 2 * Math.PI
        Game.pending = { game: "darts", staked: stake, returned: Math.round(stake * zones[z].pay * 100) / 100 }
        Game.save()
        hitZone = z; hitX = r * Math.cos(a); hitY = r * Math.sin(a)
        throwing = true
        flight.restart()
        Sound.play("card"); Haptics.tick()
        return true
    }
    function landed() {
        var p = Game.pending
        throwing = false
        marks = marks.concat([{ x: hitX, y: hitY }]).slice(-6)
        history = [zones[hitZone].pay].concat(history).slice(0, 12)
        Game.note(zones[hitZone].name + (zones[hitZone].pay ? " · " + zones[hitZone].pay + "×" : ""), zones[hitZone].pay >= 2 ? Neon.yellow : Neon.cyan)
        if (p.returned > p.staked) page.burst.show(p.returned - p.staked, zones[hitZone].pay >= 8)
        else if (p.returned === 0) Sound.play("lose")
        Sound.play("tick"); Haptics.tap()
        Game.settle(p.staked, p.returned, "darts")
    }

    Item {
        id: range
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 1.05
        readonly property real rad: width * 0.36
        readonly property real cx: width / 2
        readonly property real cy: rad * 1.3
        // board
        Repeater {
            model: [[1.0, "#2A1A40", Neon.cyan], [0.62, Neon.yellow, Neon.yellow], [0.52, "#1A2A40", Neon.cyan], [0.16, Neon.green, Neon.green], [0.07, Neon.red, Neon.red]]
            Rectangle {
                width: range.rad * 2 * modelData[0]; height: width; radius: width / 2
                x: range.cx - width / 2; y: range.cy - height / 2
                color: Neon.alpha(modelData[1], index === 1 ? 0.55 : index === 0 ? 0.85 : 0.75)
                border { width: 2; color: modelData[2] }
            }
        }
        Repeater {        // old darts stay in the board
            model: page.marks
            Rectangle {
                width: 8; height: 8; radius: 4
                x: range.cx + modelData.x * range.rad - 4; y: range.cy + modelData.y * range.rad - 4
                color: "white"; opacity: 0.5
            }
        }
        // the dart in flight
        Rectangle {
            id: dart
            width: Theme.paddingLarge * (1.6 - 0.8 * fly.v); height: width; radius: width / 2
            color: "white"; border { width: 3; color: Neon.pink }
            visible: page.throwing || fly.v > 0
            x: range.cx + (page.hitX * range.rad - 0) * fly.v - width / 2
            y: range.height * 0.92 + (range.cy + page.hitY * range.rad - range.height * 0.92) * fly.v - fly.v * (1 - fly.v) * range.height * 0.3 - height / 2
        }
        QtObject { id: fly; property real v: 0 }
        SequentialAnimation {
            id: flight
            NumberAnimation { target: fly; property: "v"; from: 0; to: 1; duration: 520; easing.type: Easing.OutQuad }
            ScriptAction { script: page.landed() }
            PauseAnimation { duration: 500 }
            NumberAnimation { target: fly; property: "v"; to: 0; duration: 1 }
        }
        MouseArea {
            anchors.fill: parent
            enabled: !page.throwing
            property real y0
            onPressed: y0 = mouse.y
            onReleased: if (y0 - mouse.y > Theme.itemSizeSmall * 0.6) page.toss()
        }
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            text: "FLICK UP TO THROW"
            color: Theme.secondaryColor
            font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 2 }
        }
    }
    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall
        Repeater {
            model: page.history
            Text { text: modelData + "×"; color: modelData >= 2 ? Neon.yellow : modelData >= 1 ? Neon.green : Neon.red; font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall } }
        }
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
            text: "Throw " + Money.fmt(bet.bet) + " · hold to repeat"
            color: Neon.cyan; primary: true
            fontSize: Theme.fontSizeMedium
            enabled: page.throwing || Game.canBet(bet.bet)
            onClicked: page.toss()
            onPressAndHold: auto.start()
            onReleased: auto.stop()
            onCanceled: auto.stop()
            Timer { id: auto; interval: 250; repeat: true; onTriggered: if (!page.throwing && !page.toss()) stop() }
        }
    }
}
