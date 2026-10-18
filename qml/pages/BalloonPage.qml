import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// Balloon: tap the balloon to pump it. Every pump multiplies what's on the line by 1/0.9 (97% of
// fair: each pump has a 1 in 10 chance to pop it). Cash out whenever. How many pumps it takes
// is decided and saved (Game.balloon) when you buy it, so quitting changes nothing.
TablePage {
    id: page
    title: "Balloon"
    accent: Neon.pink
    scene: "lobby"
    musicTrack: "balloon"
    code: "TAP TO PUMP · CASH OUT BEFORE IT POPS · 97% RTP"
    info: "Buy a balloon at your bet, then tap it (or hold Pump) to blow it up. Each pump has a one-in-ten chance to pop it "
          + "and grows the payout by about 11%. Cash out any time after the first pump. If it pops, the bet is lost. "
          + "The balloon tops out at " + page.maxPumps + " pumps and then pays out by itself."
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property int maxPumps: 40
    readonly property var round: Game.balloon
    readonly property bool playing: !!round
    property bool popped: false
    property int lastPumps: 0
    busy: playing

    function mult(k) { return k <= 0 ? 1 : Math.floor(0.97 / Math.pow(0.9, k) * 100) / 100 }
    function buy() {
        if (playing || !Game.canBet(bet.bet)) return
        var stake = bet.bet, safe = 0
        while (safe < maxPumps && Math.random() >= 0.1) safe++
        Game.stake(stake)
        Game.balloon = { stake: stake, pops: safe, pumps: 0 }
        Game.save()
        popped = false; lastPumps = 0
        Sound.play("perk"); Haptics.tap()
    }
    function pump() {
        if (!playing) return false
        var r = JSON.parse(JSON.stringify(round))
        if (r.pumps >= r.pops) {                      // this pump bursts it
            lastPumps = r.pumps
            Game.balloon = null; Game.save()
            popped = true
            Sound.play("bust"); Haptics.rumble(4)
            popAnim.restart()
            Game.settle(r.stake, 0, "balloon")
            return false
        }
        r.pumps += 1
        Game.balloon = r; Game.save()
        Sound.play("tick"); Haptics.tick()
        squish.restart()
        if (r.pumps >= maxPumps) { cashOut(); return false }
        return true
    }
    function cashOut() {
        if (!playing || round.pumps === 0) return
        var r = round, ret = Math.round(r.stake * mult(r.pumps) * 100) / 100
        lastPumps = r.pumps
        Game.balloon = null; Game.save()
        page.burst.show(ret - r.stake, r.pumps >= 15)
        Game.best("balloonPumps", r.pumps)
        Game.settle(r.stake, ret, "balloon")
    }

    Item {
        id: stage
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 1.1
        readonly property int pumps: page.playing ? page.round.pumps : page.lastPumps
        Image {
            id: balloon
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.paddingLarge }
            source: "../images/sym-balloon.png"
            width: stage.width * (0.25 + 0.65 * Math.min(1, stage.pumps / 25)); height: width
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
            opacity: page.popped ? 0 : (page.playing || page.lastPumps ? 1 : 0.35)
            SequentialAnimation { id: squish; NumberAnimation { target: balloon; property: "scale"; to: 1.08; duration: 70 } NumberAnimation { target: balloon; property: "scale"; to: 1; duration: 140 } }
        }
        NeonText {
            id: boom
            anchors.centerIn: parent
            text: "POP!"
            color: Neon.red; font.pixelSize: Theme.fontSizeHuge * 1.4
            opacity: 0
            SequentialAnimation { id: popAnim; NumberAnimation { target: boom; property: "opacity"; to: 1; duration: 60 } NumberAnimation { target: boom; property: "scale"; from: 0.6; to: 1.3; duration: 350 } PauseAnimation { duration: 600 } NumberAnimation { target: boom; property: "opacity"; to: 0; duration: 400 } }
        }
        Column {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "×" + page.mult(stage.pumps).toFixed(2)
                color: page.popped ? Neon.red : Neon.yellow
                font { family: Neon.mono; bold: true; pixelSize: Theme.fontSizeHuge }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.playing ? stage.pumps + " PUMPS · ON THE LINE " + Money.fmt(page.round.stake * page.mult(stage.pumps)) + " · NEXT ×" + page.mult(stage.pumps + 1).toFixed(2)
                      : page.popped ? "POPPED AFTER " + page.lastPumps + " PUMPS" : page.lastPumps ? "CASHED OUT AT " + page.lastPumps + " PUMPS" : "BUY A BALLOON TO PLAY"
                color: Theme.secondaryColor
                font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall }
            }
        }
        MouseArea { anchors.fill: parent; enabled: page.playing; onClicked: page.pump() }
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        BetSelector { id: bet; width: parent.width; locked: page.busy; color: Neon.yellow; visible: !page.playing }
        Row {
            visible: page.playing
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            NeonButton {
                width: (page.width - 2 * Theme.horizontalPageMargin - Theme.paddingSmall) / 2; height: Theme.itemSizeMedium
                text: "Pump · hold"
                color: Neon.pink; primary: true
                onClicked: page.pump()
                onPressAndHold: auto.start()
                onReleased: auto.stop()
                onCanceled: auto.stop()
                Timer { id: auto; interval: 260; repeat: true; onTriggered: if (!page.pump()) stop() }
            }
            NeonButton {
                width: (page.width - 2 * Theme.horizontalPageMargin - Theme.paddingSmall) / 2; height: Theme.itemSizeMedium
                text: page.playing ? "Cash " + Money.fmt(page.round.stake * page.mult(page.round.pumps)) : "Cash"
                color: Neon.yellow; primary: true
                enabled: page.playing && page.round.pumps > 0
                onClicked: page.cashOut()
            }
        }
        NeonButton {
            visible: !page.playing
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            height: Theme.itemSizeMedium
            text: "Buy balloon · " + Money.fmt(bet.bet)
            color: Neon.pink; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: Game.canBet(bet.bet)
            onClicked: page.buy()
        }
    }
}
