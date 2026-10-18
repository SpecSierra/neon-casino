import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// Tower: climb 8 floors, picking one of three doors per floor. EASY hides 1 trap per floor,
// HARD hides 2. Each floor cleared multiplies the stake (97% of fair); cash out any time.
// The traps are laid and saved (Game.tower) when you start, so quitting changes nothing.
TablePage {
    id: page
    title: "Tower"
    accent: Neon.violet
    scene: "circuit"
    musicTrack: "tower"
    code: "8 FLOORS · PICK A DOOR · CASH OUT ANY TIME · 97% RTP"
    info: "Each floor has three doors. On EASY one hides a trap, on HARD two do. Pick a safe door to climb; "
          + "every floor multiplies what's on the line (EASY ×1.5, HARD ×3 per floor, 97% of fair odds). "
          + "Hit a trap and you lose the stake. Cash out whenever you like; the top floor pays out by itself."
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property int floors: 8
    property int riskIndex: 0                  // 0 easy, 1 hard
    readonly property var round: Game.tower
    readonly property bool playing: !!round
    property var lastRound: null               // the finished climb, shown until the next one
    readonly property var view: playing ? round : lastRound
    busy: playing

    function step(risk) { return risk === 1 ? 3 : 1.5 }
    function mult(risk, k) { return k <= 0 ? 1 : Math.floor(0.97 * Math.pow(step(risk), k) * 100) / 100 }

    function start() {
        if (playing || !Game.canBet(bet.bet)) return
        var stake = bet.bet, traps = []
        for (var f = 0; f < floors; ++f) {
            var cols = [0, 1, 2]
            for (var k = 2; k > 0; --k) { var j = Math.floor(Math.random() * (k + 1)), t = cols[k]; cols[k] = cols[j]; cols[j] = t }
            traps.push(cols.slice(0, riskIndex === 1 ? 2 : 1))
        }
        Game.stake(stake)
        Game.tower = { stake: stake, risk: riskIndex, traps: traps, floor: 0, picks: [], dead: false }
        Game.save()
        lastRound = null
        Sound.play("card"); Haptics.tap()
    }
    function pick(floor, col) {
        if (!playing || floor !== round.floor) return
        var r = JSON.parse(JSON.stringify(round))
        r.picks.push(col)
        if (r.traps[floor].indexOf(col) >= 0) {
            r.dead = true
            Game.tower = null; Game.save()
            lastRound = r
            Sound.play("bust"); Haptics.rumble(3)
            Game.settle(r.stake, 0, "tower")
            return
        }
        r.floor += 1
        Sound.play("win"); Haptics.tap()
        if (r.floor >= floors) { finish(r); return }
        Game.tower = r; Game.save()
    }
    function cashOut() { if (playing && round.floor > 0) finish(JSON.parse(JSON.stringify(round))) }
    function finish(r) {
        var ret = Math.round(r.stake * mult(r.risk, r.floor) * 100) / 100
        Game.tower = null; Game.save()
        lastRound = r
        page.burst.show(ret - r.stake, r.floor >= 5)
        Game.best("towerFloor", r.floor)
        Game.settle(r.stake, ret, "tower")
    }

    // ---- the tower: top floor first ----
    Column {
        id: towerCol
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        spacing: Theme.paddingSmall / 2
        Repeater {
            model: page.floors
            Item {
                id: floorItem
                readonly property int f: page.floors - 1 - index
                readonly property bool current: page.playing && page.round.floor === f
                readonly property bool cleared: page.view && page.view.floor > f
                width: towerCol.width
                height: Theme.itemSizeExtraSmall * 0.92
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: parent.width * 0.22
                    text: "×" + page.mult(page.view ? page.view.risk : page.riskIndex, floorItem.f + 1).toFixed(2)
                    color: floorItem.cleared ? Neon.green : floorItem.current ? Neon.yellow : Theme.secondaryColor
                    font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall }
                    fontSizeMode: Text.HorizontalFit; minimumPixelSize: Theme.fontSizeTiny
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.paddingSmall
                    Repeater {
                        model: 3
                        MouseArea {
                            id: door
                            readonly property var v: page.view
                            readonly property bool picked: v && v.picks.length > floorItem.f && v.picks[floorItem.f] === index
                            readonly property bool trap: v && v.traps[floorItem.f].indexOf(index) >= 0
                            // after the climb ends, every door shows what it was
                            readonly property bool open: v && (picked || (!page.playing && (v.dead || v.floor > 0)))
                            width: (towerCol.width * 0.78 - 2 * Theme.paddingSmall) / 3
                            height: floorItem.height
                            enabled: floorItem.current
                            onClicked: page.pick(floorItem.f, index)
                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: door.open ? (door.trap ? Neon.alpha(Neon.red, door.picked ? 0.7 : 0.25) : Neon.alpha(Neon.green, door.picked ? 0.6 : 0.18))
                                                 : floorItem.current ? Neon.alpha(Neon.violet, door.pressed ? 0.6 : 0.35) : Neon.alpha("#0A0418", 0.7)
                                border { width: floorItem.current ? 2 : 1; color: floorItem.current ? Neon.violet : Neon.alpha(Neon.violet, 0.35) }
                                Text {
                                    anchors.centerIn: parent
                                    visible: door.open
                                    text: door.trap ? "☠" : "◆"
                                    color: door.trap ? Neon.red : Neon.green
                                    font.pixelSize: parent.height * 0.55
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Segmented {
        x: Theme.horizontalPageMargin; width: parent.width - 2 * x
        color: Neon.violet
        labels: ["EASY · 1 TRAP", "HARD · 2 TRAPS"]
        current: page.riskIndex
        enabled: !page.playing
        onPicked: page.riskIndex = index
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        BetSelector { id: bet; width: parent.width; locked: page.busy; color: Neon.yellow; visible: !page.playing }
        NeonButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            height: Theme.itemSizeMedium
            visible: page.playing
            text: page.playing && page.round.floor > 0
                  ? "Cash out " + Money.fmt(page.round.stake * page.mult(page.round.risk, page.round.floor))
                  : "Pick a door on the bottom floor"
            color: Neon.yellow; primary: true
            fontSize: Theme.fontSizeMedium
            enabled: page.playing && page.round.floor > 0
            onClicked: page.cashOut()
        }
        NeonButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            height: Theme.itemSizeMedium
            visible: !page.playing
            text: "Climb " + Money.fmt(bet.bet)
            color: Neon.violet; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: Game.canBet(bet.bet)
            onClicked: page.start()
        }
    }
}
