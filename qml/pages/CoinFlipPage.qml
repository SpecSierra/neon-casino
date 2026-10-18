import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// Coin flip: call heads or tails, flick the coin up (or tap Flip). A right call pays 1.94×
// (97% RTP). The side is decided and saved before the coin leaves your hand.
TablePage {
    id: page
    title: "Coin flip"
    accent: Neon.yellow
    scene: "velvet"
    musicTrack: "coinflip"
    code: "CALL IT · FLICK UP · PAYS 1.94× · 97% RTP"
    info: "Pick HEADS (the credit chip) or TAILS (the skull), then flick the coin upwards or tap Flip. "
          + "A right call returns 1.94× your bet. Hold Flip to keep flipping with the same call."
    footerHeight: footerCol.height + Theme.paddingLarge

    property bool callHeads: true
    property bool flipping: false
    property bool showHeads: true          // the face currently up
    property var history: []
    property int streak: 0
    busy: flipping

    function flip(power) {
        if (flipping || !Game.canBet(bet.bet)) return false
        var stake = bet.bet
        Game.stake(stake)
        var heads = Math.random() < 0.5, win = heads === callHeads
        Game.pending = { game: "coinflip", staked: stake, returned: win ? Math.round(stake * 194) / 100 : 0, heads: heads }
        Game.save()
        flipping = true
        // whole half-turns: an even count keeps the face, an odd count turns it over
        var p = power === undefined ? 0.5 : power
        var halves = 2 * Math.round(5 + 4 * p) + (heads === showHeads ? 0 : 1)
        spinAnim.to = coinRot.angle + 180 * halves
        spinAnim.duration = 1100 + 500 * p
        hop.duration = spinAnim.duration / 2
        throwAnim.restart()
        Sound.play("card"); Haptics.tap()
        return true
    }
    function landed() {
        var p = Game.pending
        flipping = false
        showHeads = p.heads
        var win = p.returned > 0
        streak = win ? streak + 1 : 0
        history = [p.heads ? "H" : "T"].concat(history).slice(0, 16)
        Game.best("coinStreak", streak)
        if (win) page.burst.show(p.returned - p.staked, streak >= 5)
        else Sound.play("lose")
        Haptics.tap()
        Game.settle(p.staked, p.returned, "coinflip")
    }

    // ---- the coin ----
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 0.9
        Rectangle {           // the shadow on the table
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.paddingLarge }
            width: coin.width * (1 - 0.5 * coin.lift); height: width * 0.16; radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.45)
        }
        Item {
            id: coin
            property real lift: 0                   // 0 on the table, 1 at the top of the throw
            width: parent.width * 0.52; height: width
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - Theme.paddingLarge * 2 - lift * parent.height * 0.32
            transform: Rotation { id: coinRot; origin.x: coin.width / 2; origin.y: coin.height / 2; axis { x: 1; y: 0; z: 0 } angle: 0 }
            Rectangle {
                anchors.fill: parent; radius: width / 2
                color: Qt.rgba(0.12, 0.08, 0.02, 0.95)
                border { width: Theme.paddingSmall; color: Neon.yellow }
                Rectangle {
                    anchors { fill: parent; margins: parent.width * 0.09 }
                    radius: width / 2; color: "transparent"
                    border { width: 2; color: Neon.alpha(Neon.yellow, 0.6) }
                }
                Image {
                    id: face
                    anchors.centerIn: parent
                    width: parent.width * 0.62; height: width
                    // which face is up follows the turn: past a quarter turn you see the other side
                    readonly property bool front: { var a = ((coinRot.angle % 360) + 360) % 360; return a < 90 || a > 270 }
                    readonly property bool heads: page.flipping ? (front ? page.showHeads : !page.showHeads) : page.showHeads
                    source: heads ? "../images/coin-heads.png" : "../images/coin-tails.png"
                    // the back face is seen through the coin: flip it upright again (about its own centre)
                    transform: Scale { origin.y: face.height / 2; yScale: face.front ? 1 : -1 }
                }
            }
        }
        SequentialAnimation {
            id: throwAnim
            ParallelAnimation {
                NumberAnimation { id: spinAnim; target: coinRot; property: "angle"; easing.type: Easing.OutQuad }
                SequentialAnimation {
                    NumberAnimation { id: hop; target: coin; property: "lift"; from: 0; to: 1; easing.type: Easing.OutQuad }
                    NumberAnimation { target: coin; property: "lift"; to: 0; duration: hop.duration; easing.type: Easing.OutBounce }
                }
            }
            ScriptAction { script: { coinRot.angle = 0; page.landed() } }
        }
        MouseArea {           // flick the coin up
            anchors.fill: parent
            property real y0; property real t0
            onPressed: { y0 = mouse.y; t0 = Date.now() }
            onReleased: {
                var dy = y0 - mouse.y
                if (dy > Theme.itemSizeSmall * 0.6) page.flip(Math.min(1, dy / Math.max(1, Date.now() - t0) / 3))
            }
        }
    }
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeSmall
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "STREAK " + page.streak
            color: page.streak >= 3 ? Neon.yellow : Theme.secondaryColor
            font { family: Neon.mono; pixelSize: Theme.fontSizeMedium }
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Theme.paddingSmall / 2
            Repeater {
                model: page.history.slice(0, 12)
                Text { text: modelData; color: modelData === "H" ? Neon.yellow : Neon.pink; font { family: Neon.mono; pixelSize: Theme.fontSizeSmall } }
            }
        }
    }
    Segmented {
        x: Theme.horizontalPageMargin; width: parent.width - 2 * x
        color: Neon.yellow
        labels: ["HEADS ¤", "TAILS ☠"]
        current: page.callHeads ? 0 : 1
        enabled: !page.flipping
        onPicked: page.callHeads = index === 0
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
            text: page.flipping ? "Flipping…" : "Flip " + Money.fmt(bet.bet) + " on " + (page.callHeads ? "heads" : "tails")
            color: Neon.yellow; primary: true
            fontSize: Theme.fontSizeMedium
            enabled: page.flipping || Game.canBet(bet.bet)     // stays pressable mid-flip so hold-to-repeat keeps going
            onClicked: page.flip(0.5)
            onPressAndHold: auto.start()
            onReleased: auto.stop()
            onCanceled: auto.stop()
            Timer { id: auto; interval: 300; repeat: true; onTriggered: if (!page.flipping && !page.flip(0.2) && !page.flipping) stop() }
        }
    }
}
