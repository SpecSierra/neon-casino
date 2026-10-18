import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/HiLo.js" as HiLo
import "../js/Money.js" as Money

// Hi-Lo: swipe the card up for HIGHER or down for LOWER. Each right guess multiplies the stake
// (97% of fair odds); a tie or a wrong guess loses it all; cash out whenever. The next card is
// drawn before you guess and saved with the round (Game.hilo), so quitting changes nothing.
TablePage {
    id: page
    title: "Hi-Lo"
    accent: Neon.green
    scene: "felt"
    musicTrack: "hilo"
    code: "SWIPE UP = HIGHER · DOWN = LOWER · 97% RTP"
    info: "A card is shown. Guess whether the next card is strictly higher or lower (2 is lowest, ace highest). "
          + "A right guess multiplies what's on the line by 0.97 ÷ the chance of being right, so long shots pay big. "
          + "A tie or a wrong guess loses it. Cash out any time. Skip swaps the card for free."
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property var round: Game.hilo
    readonly property bool playing: !!round
    property var shownCard: HiLo.card()
    property string flash: ""
    property var trail: []                   // the cards so far this round
    busy: playing

    function start() {
        if (playing || !Game.canBet(bet.bet)) return
        var stake = bet.bet
        Game.stake(stake)
        var c = HiLo.card()
        Game.hilo = { stake: stake, mult: 1, card: c, next: HiLo.card(), steps: 0 }
        Game.save()
        shownCard = c; trail = [c]; flash = ""
        Sound.play("card"); Haptics.tap()
    }
    function guess(higher) {
        if (!playing) return
        var r = JSON.parse(JSON.stringify(round))
        var p = higher ? HiLo.pHigher(r.card) : HiLo.pLower(r.card)
        if (p <= 0) { Game.note(higher ? "NOTHING IS HIGHER THAN AN ACE" : "NOTHING IS LOWER THAN A 2", Neon.red); return }
        var ok = HiLo.wins(r.card, r.next, higher)
        shownCard = r.next
        trail = trail.concat([r.next]).slice(-8)
        Sound.play("card")
        if (!ok) {
            flash = "lose"
            Game.hilo = null
            Game.save()
            Sound.play("lose"); Haptics.rumble(2)
            Game.settle(r.stake, 0, "hilo")
            return
        }
        r.mult = Math.floor(r.mult * HiLo.step(r.card, higher) * 100) / 100
        r.card = r.next; r.next = HiLo.card(); r.steps += 1
        Game.hilo = r
        Game.save()
        flash = "win"
        Sound.play("win"); Haptics.tap()
        Game.best("hiloStreak", r.steps)
    }
    function skip() {
        if (!playing) return
        var r = JSON.parse(JSON.stringify(round))
        r.card = r.next; r.next = HiLo.card()
        Game.hilo = r; Game.save()
        shownCard = r.card; trail = trail.concat([r.card]).slice(-8)
        Sound.play("card"); Haptics.tick()
    }
    function cashOut() {
        if (!playing || round.steps === 0) return
        var r = round, ret = Math.round(r.stake * r.mult * 100) / 100
        Game.hilo = null
        Game.save()
        page.burst.show(ret - r.stake, r.mult >= 5)
        Game.settle(r.stake, ret, "hilo")
        flash = ""
    }
    Component.onCompleted: if (playing) { shownCard = round.card; trail = [round.card] }

    // ---- odds strip ----
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeMedium
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: "HIGHER"; color: Neon.alpha(Neon.green, 0.8); font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 2 } }
            Text {
                text: HiLo.pHigher(page.shownCard) > 0 ? "×" + HiLo.step(page.shownCard, true).toFixed(2) + "  " + Math.round(HiLo.pHigher(page.shownCard) * 100) + "%" : "—"
                color: Neon.green; font { family: Neon.mono; pixelSize: Theme.fontSizeMedium }
            }
        }
        Column {
            anchors.centerIn: parent
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "ON THE LINE"; color: Neon.alpha(Neon.yellow, 0.8); font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 2 } }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.playing ? Money.fmt(page.round.stake * page.round.mult) : "—"
                color: Neon.yellow; font { family: Neon.mono; pixelSize: Theme.fontSizeLarge }
            }
        }
        Column {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            Text { anchors.right: parent.right; text: "LOWER"; color: Neon.alpha(Neon.red, 0.8); font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 2 } }
            Text {
                anchors.right: parent.right
                text: HiLo.pLower(page.shownCard) > 0 ? Math.round(HiLo.pLower(page.shownCard) * 100) + "%  ×" + HiLo.step(page.shownCard, false).toFixed(2) : "—"
                color: Neon.red; font { family: Neon.mono; pixelSize: Theme.fontSizeMedium }
            }
        }
    }

    // ---- the card: swipe it ----
    NeonPanel {
        id: table
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 0.95
        glowColor: page.flash === "lose" ? Neon.red : page.flash === "win" ? Neon.green : Neon.cyan
        glowStrength: page.playing ? 0.6 : 0.35
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.paddingLarge }
            text: "▲ HIGHER"
            color: Neon.alpha(Neon.green, page.playing ? 0.9 : 0.3)
            font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeMedium; letterSpacing: 2 }
        }
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.paddingLarge }
            text: "LOWER ▼"
            color: Neon.alpha(Neon.red, page.playing ? 0.9 : 0.3)
            font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeMedium; letterSpacing: 2 }
        }
        CardItem {
            id: bigCard
            anchors.centerIn: parent
            anchors.verticalCenterOffset: drag.dy
            width: table.width * 0.38
            rank: page.shownCard.rank; suit: page.shownCard.suit
            animateIn: false
            Behavior on anchors.verticalCenterOffset { enabled: !drag.pressed; NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        }
        NeonText {
            anchors { right: parent.right; rightMargin: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
            visible: page.playing
            text: page.playing ? "×" + page.round.mult.toFixed(2) : ""
            color: Neon.yellow; font.pixelSize: Theme.fontSizeExtraLarge
        }
        Row {      // the cards so far
            anchors { left: parent.left; leftMargin: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
            spacing: -Theme.paddingLarge
            Repeater {
                model: page.trail.slice(0, -1).slice(-4)
                CardItem { width: table.width * 0.12; rank: modelData.rank; suit: modelData.suit; animateIn: false; opacity: 0.6 }
            }
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            preventStealing: true
            property real y0: 0
            property real dy: 0
            onPressed: { y0 = mouse.y; dy = 0 }
            onPositionChanged: dy = Math.max(-Theme.itemSizeLarge, Math.min(Theme.itemSizeLarge, mouse.y - y0))
            onReleased: {
                var d = mouse.y - y0
                dy = 0
                if (!page.playing) return
                if (d < -Theme.itemSizeSmall) page.guess(true)
                else if (d > Theme.itemSizeSmall) page.guess(false)
            }
        }
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
            property real w: (page.width - 2 * Theme.horizontalPageMargin - 3 * spacing) / 4
            NeonButton { width: parent.w; height: Theme.itemSizeSmall; text: "Higher"; color: Neon.green; fontSize: Theme.fontSizeExtraSmall; onClicked: page.guess(true) }
            NeonButton { width: parent.w; height: Theme.itemSizeSmall; text: "Lower"; color: Neon.red; fontSize: Theme.fontSizeExtraSmall; onClicked: page.guess(false) }
            NeonButton { width: parent.w; height: Theme.itemSizeSmall; text: "Skip"; color: Neon.violet; fontSize: Theme.fontSizeExtraSmall; onClicked: page.skip() }
            NeonButton { width: parent.w; height: Theme.itemSizeSmall; text: "Cash"; color: Neon.yellow; primary: true; fontSize: Theme.fontSizeExtraSmall; enabled: page.round && page.round.steps > 0; onClicked: page.cashOut() }
        }
        NeonButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            height: Theme.itemSizeMedium
            visible: !page.playing
            text: "Deal " + Money.fmt(bet.bet)
            color: Neon.green; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: Game.canBet(bet.bet)
            onClicked: page.start()
        }
    }
}
