import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Mines.js" as Mines
import "../js/Money.js" as Money

// Mines: pick how many mines hide in 25 tiles, open tiles one by one, cash out whenever.
// Pays 97% of the fair odds at every step. The layout is fixed and saved at the start
// (Game.mines), so a round resumes exactly and quitting can't dodge a mine.
TablePage {
    id: page
    title: "Mines"
    accent: Neon.red
    scene: "circuit"
    musicTrack: "mines"
    code: "25 TILES · CASH OUT ANY TIME · 97% RTP"
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property var mineOptions: [1, 3, 5, 10, 20]
    property int mineIndex: 1
    readonly property var round: Game.mines
    readonly property bool playing: !!round && !round.done
    readonly property int picks: round ? round.picked.length : 0
    readonly property real mult: round ? Mines.multiplier(round.mines, picks) : 1
    readonly property real nextMult: round ? Mines.multiplier(round.mines, picks + 1) : Mines.multiplier(mineOptions[mineIndex], 1)
    property var shownBombs: []                // revealed when the round ends
    property int boomAt: -1
    busy: playing

    function start() {
        if (playing || !Game.canBet(bet.bet)) return
        var stake = bet.bet
        Game.stake(stake)
        shownBombs = []; boomAt = -1
        Game.mines = { mines: mineOptions[mineIndex], bombs: Mines.layout(mineOptions[mineIndex]), picked: [], stake: stake, done: false }
        Game.save()
        Sound.play("reel"); Haptics.tap()
    }
    function pick(i) {
        if (!playing || round.picked.indexOf(i) >= 0) return
        var r = JSON.parse(JSON.stringify(round))
        if (r.bombs.indexOf(i) >= 0) {
            r.done = true; r.lost = true
            Game.mines = null
            Game.save()
            boomAt = i; shownBombs = r.bombs; lastRound = r
            Sound.play("bust"); Haptics.rumble(4); boom.restart()
            Game.settle(r.stake, 0, "mines")
            return
        }
        r.picked.push(i)
        Game.mines = r
        Game.save()
        Sound.play("win"); Haptics.tap()
        if (r.picked.length >= Mines.size - r.mines) cashOut()     // board cleared
    }
    property var lastRound: null               // the finished board, kept on screen
    function cashOut() {
        if (!playing || picks === 0) return
        var r = JSON.parse(JSON.stringify(round))
        var returned = Math.round(r.stake * Mines.multiplier(r.mines, r.picked.length) * 100) / 100
        r.done = true
        lastRound = r; shownBombs = r.bombs; boomAt = -1
        Game.mines = null
        Game.save()
        Game.best("minesPicks", r.picked.length)
        page.burst.show(returned - r.stake, returned >= r.stake * 5)
        Game.settle(r.stake, returned, "mines")
    }
    readonly property var board: round || lastRound

    // ---- status ----
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeMedium
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: page.playing ? "NOW" : "FIRST TILE PAYS"; color: Neon.alpha(Neon.red, 0.8); font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 2 } }
            Text {
                text: page.playing ? page.mult.toFixed(2) + "×  " + Money.fmt(page.round.stake * page.mult) : page.nextMult.toFixed(2) + "×"
                color: Neon.yellow
                font { family: Neon.mono; pixelSize: Theme.fontSizeLarge }
            }
        }
        Column {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            Text { anchors.right: parent.right; text: "NEXT TILE"; color: Neon.alpha(Neon.red, 0.8); font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 2 } }
            Text { anchors.right: parent.right; text: page.nextMult.toFixed(2) + "×"; color: "white"; font { family: Neon.mono; pixelSize: Theme.fontSizeLarge } }
        }
    }

    // ---- the board ----
    NeonPanel {
        id: boardPanel
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width
        glowColor: page.boomAt >= 0 ? Neon.red : page.playing ? Neon.yellow : Neon.red
        glowStrength: page.playing ? 0.6 : 0.35
        Grid {
            id: grid
            anchors { fill: parent; margins: Theme.paddingLarge }
            columns: 5
            spacing: Theme.paddingSmall
            property real cell: (width - 4 * spacing) / 5
            Repeater {
                model: 25
                MouseArea {
                    id: tile
                    width: grid.cell; height: grid.cell
                    readonly property bool open: !!page.board && page.board.picked.indexOf(index) >= 0
                    readonly property bool bomb: page.shownBombs.indexOf(index) >= 0
                    onClicked: page.pick(index)
                    Rectangle {
                        anchors.fill: parent
                        color: tile.open ? Neon.alpha(Neon.green, 0.3) : tile.bomb ? Neon.alpha(Neon.red, index === page.boomAt ? 0.6 : 0.2)
                               : Neon.alpha("white", tile.pressed ? 0.18 : 0.06)
                        border { width: tile.open || tile.bomb ? 2 : 1; color: tile.open ? Neon.green : tile.bomb ? Neon.red : Neon.alpha(Neon.cyan, 0.35) }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Image {
                        anchors.centerIn: parent
                        width: parent.width * 0.7; height: width
                        visible: tile.open || tile.bomb
                        source: tile.bomb ? "../images/sym-mines.png" : "../images/gem-emerald.png"
                        scale: visible ? 1 : 0.3
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                    }
                }
            }
        }
        Rectangle {
            id: boomFlash
            anchors.fill: parent; color: Neon.red; opacity: 0
            NumberAnimation { id: boom; target: boomFlash; property: "opacity"; from: 0.55; to: 0; duration: 700 }
        }
    }
    SectionHeader { text: "Mines on the board" }
    Segmented {
        x: Theme.horizontalPageMargin; width: parent.width - 2 * x
        color: Neon.red
        labels: page.mineOptions.map(String)
        current: page.mineIndex
        enabled: !page.playing
        onPicked: page.mineIndex = index
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
            text: page.playing ? (page.picks ? "Cash out " + Money.fmt(page.round.stake * page.mult) : "Open a tile…") : "Start " + Money.fmt(bet.bet)
            color: page.playing ? Neon.green : Neon.red
            primary: true
            fontSize: Theme.fontSizeLarge
            enabled: page.playing ? page.picks > 0 : Game.canBet(bet.bet)
            onClicked: page.playing ? page.cashOut() : page.start()
        }
    }
}
