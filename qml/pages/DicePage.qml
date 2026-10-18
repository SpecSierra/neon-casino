import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// Dice: drag the target, then roll 0.00-99.99. Win when the roll lands on your side.
// Payout = 97 / chance, so every target returns 97%. Decided and saved before the needle moves.
TablePage {
    id: page
    title: "Dice"
    accent: Neon.cyan
    scene: "circuit"
    musicTrack: "dice"
    code: "DRAG THE TARGET · ROLL UNDER OR OVER · 97% RTP"
    info: "Drag the slider to set a target, choose UNDER or OVER, then roll a number from 0.00 to 99.99. "
          + "If it lands on your side you win 97 ÷ your chance: a 50% shot pays 1.94×, a 5% shot pays 19.4×. "
          + "Hold Roll to keep rolling."
    footerHeight: footerCol.height + Theme.paddingLarge

    property real target: 50                // 2 .. 98
    property bool under: true
    property bool rolling: false
    property real shown: 50                 // where the needle is
    property real last: -1
    property var history: []
    readonly property real chance: under ? target : 100 - target
    readonly property real payout: Math.floor(97 / chance * 100) / 100
    busy: rolling

    function roll() {
        if (rolling || !Game.canBet(bet.bet)) return false
        var stake = bet.bet
        Game.stake(stake)
        var v = Math.floor(Math.random() * 10000) / 100
        var win = under ? v < target : v > target
        Game.pending = { game: "dice", staked: stake, returned: win ? Math.round(stake * payout * 100) / 100 : 0, roll: v }
        Game.save()
        rolling = true
        needle.from = shown; needle.to = v
        needle.restart()
        Sound.play("reel"); Haptics.tick()
        return true
    }
    function done() {
        var p = Game.pending
        rolling = false
        last = p.roll
        history = [{ v: p.roll, w: p.returned > 0 }].concat(history).slice(0, 10)
        if (p.returned > 0) { if (p.returned >= p.staked * 5) page.burst.show(p.returned - p.staked, true); else Sound.play("win") }
        else Sound.play("lose")
        Haptics.tap()
        Game.settle(p.staked, p.returned, "dice")
    }
    NumberAnimation { id: needle; target: page; property: "shown"; duration: 650; easing.type: Easing.OutCubic; onStopped: page.done() }

    // ---- the roll readout ----
    NeonPanel {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeExtraLarge * 1.5
        glowColor: page.last < 0 || page.rolling ? Neon.cyan : (page.history.length && page.history[0].w ? Neon.green : Neon.red)
        NeonText {
            anchors.centerIn: parent
            text: page.shown.toFixed(2)
            color: page.rolling || page.last < 0 ? "white" : (page.history[0].w ? Neon.green : Neon.red)
            font.pixelSize: Theme.fontSizeHuge * 1.3
        }
    }
    // ---- the track: your side lit, needle on the roll ----
    Item {
        id: track
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeLarge
        readonly property real px: width / 100
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: Theme.paddingLarge; radius: height / 2
            color: Neon.alpha(Neon.red, 0.35)
        }
        Rectangle {       // the winning side
            anchors.verticalCenter: parent.verticalCenter
            x: page.under ? 0 : page.target * track.px
            width: (page.under ? page.target : 100 - page.target) * track.px
            height: Theme.paddingLarge; radius: height / 2
            color: Neon.alpha(Neon.green, 0.75)
        }
        Rectangle {       // the target handle
            x: page.target * track.px - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.paddingLarge * 1.6; height: Theme.itemSizeSmall
            radius: 4; color: "white"
            border { width: 2; color: Neon.cyan }
        }
        Rectangle {       // the needle
            x: page.shown * track.px - 1.5
            width: 3; height: parent.height
            color: Neon.yellow
            visible: page.rolling || page.last >= 0
        }
        MouseArea {
            anchors.fill: parent
            enabled: !page.rolling
            preventStealing: true
            function set(mx) { var t = Math.round(Math.max(2, Math.min(98, mx / track.px))); if (t !== page.target) { page.target = t; Haptics.tick() } }
            onPressed: set(mouse.x)
            onPositionChanged: set(mouse.x)
        }
    }
    Row {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        Repeater {
            model: [["TARGET", (page.under ? "< " : "> ") + page.target], ["CHANCE", page.chance + "%"], ["PAYS", page.payout.toFixed(2) + "×"]]
            Column {
                width: parent.width / 3
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[0]; color: Neon.alpha(Neon.cyan, 0.8); font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 2 } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[1]; color: "white"; font { family: Neon.mono; pixelSize: Theme.fontSizeLarge } }
            }
        }
    }
    Segmented {
        x: Theme.horizontalPageMargin; width: parent.width - 2 * x
        color: Neon.cyan
        labels: ["ROLL UNDER", "ROLL OVER"]
        current: page.under ? 0 : 1
        enabled: !page.rolling
        onPicked: page.under = index === 0
    }
    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingMedium
        Repeater {
            model: page.history
            Text { text: modelData.v.toFixed(1); color: modelData.w ? Neon.green : Neon.red; font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall } }
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
            text: "Roll " + Money.fmt(bet.bet) + " · win " + Money.fmt(bet.bet * page.payout)
            color: Neon.cyan; primary: true
            fontSize: Theme.fontSizeMedium
            enabled: page.rolling || Game.canBet(bet.bet)
            onClicked: page.roll()
            onPressAndHold: auto.start()
            onReleased: auto.stop()
            onCanceled: auto.stop()
            Timer { id: auto; interval: 200; repeat: true; onTriggered: if (!page.rolling && !page.roll()) stop() }
        }
    }
}
