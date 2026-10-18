import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/ArcadeConfig.js" as Config
import "../js/Arcade.js" as Arcade
import "../js/Money.js" as Money

// PIXEL ARCADE: slots meets bingo. Buy a 5×5 card, then play its 10 spins of a 5-reel row.
// Numbers mark themselves; jokers are yours to place (the glowing cell is the best spot).
// Finished lines pay up the ladder at the end. The card and all 10 spins are decided and saved
// (Game.arcade) when you buy; the round survives quitting and picks up where you left it.
TablePage {
    id: page
    title: "Pixel arcade"
    accent: m.color
    scene: "arcade"
    musicTrack: "arcade"
    code: "BUY A CARD · 10 SPINS · PLACE JOKERS · FINISH LINES"
    info: "Buy a card for your bet. Each of the 10 spins rolls one symbol per column:<br>"
          + "• a NUMBER on your card in that column marks itself<br>"
          + "• 1UP (joker): tap any open cell in its column<br>"
          + "• CROWN (super joker): tap any open cell on the card<br>"
          + "• COIN: " + m.coin + "× your bet at once<br>"
          + "• GHOST: nothing<br><br>"
          + "When the spins are done, complete lines (rows, columns, diagonals) pay:<br>"
          + m.ladder.map(function (v, i) { return i ? i + " line" + (i > 1 ? "s" : "") + ": " + v + "×" : "" }).filter(function (s) { return s }).join(" · ")
          + "<br><br>The glowing cell is the best spot for a joker. RTP about 95%."
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property var m: Config.machine
    readonly property var st: Game.arcade
    readonly property bool playing: !!st
    readonly property var lastRow: playing && st.idx > 0 ? st.spins[st.idx - 1] : null
    readonly property var hint: playing ? Arcade.bestCell(st) : null
    readonly property int lines: playing ? Arcade.linesDone(st).length : (ended ? Arcade.linesDone(ended).length : 0)
    property var ended: null                 // the finished card, shown until the next buy
    property bool rolling: false
    busy: playing

    function buy() {
        if (playing || !Game.canBet(bet.bet)) return
        Game.stake(bet.bet)
        Game.arcade = Arcade.newGame(m, bet.bet)
        Game.save()
        ended = null
        Sound.play("perk"); Haptics.tap()
    }
    function spin() {
        if (!playing || rolling || st.queue.length || st.idx >= m.spins) return
        var s = Arcade.copy(st)
        Arcade.applySpin(m, s)
        Game.arcade = s
        Game.save()
        rolling = true
        for (var c = 0; c < 5; ++c) slots.itemAt(c).roll(c)
        Sound.play("reel")
    }
    function rolled() {
        rolling = false
        Sound.play("tick")
        var row = lastRow, coins = 0
        for (var c = 0; c < 5; ++c) if (row[c] === "coin") coins++
        if (coins) { Sound.play("win"); Game.note("COIN +" + Money.fmt(coins * m.coin * st.stake), Neon.yellow) }
        if (st.queue.length) { Game.note(st.queue[0].type === "super" ? "SUPER JOKER · ANY CELL" : "JOKER · COLUMN " + "BINGO"[st.queue[0].col], m.color); Haptics.rumble(1) }
        checkEnd()
    }
    function tapCell(r, c) {
        if (!playing || rolling || !Arcade.canPlace(st, r, c)) return
        var before = Arcade.linesDone(st).length
        var s = Arcade.copy(st)
        Arcade.place(s, r, c)
        Game.arcade = s
        Game.save()
        Sound.play("tick"); Haptics.tap()
        if (Arcade.linesDone(s).length > before) { Sound.play("perk"); Game.note("LINE " + Arcade.linesDone(s).length + " · " + m.ladder[Arcade.linesDone(s).length] + "×", Neon.yellow) }
        checkEnd()
    }
    function checkEnd() {
        if (!Arcade.finished(m, st)) return
        var s = st, ret = Arcade.payout(m, s)
        Game.arcade = null
        Game.save()
        ended = s
        if (ret > s.stake) page.burst.show(ret - s.stake, ret >= s.stake * 20)
        else if (ret === 0) Sound.play("lose")
        Game.best("arcadeLines", Arcade.linesDone(s).length)
        Game.settle(s.stake, ret, "slots")
    }

    // ---- the reel row ----
    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall
        Repeater {
            id: slots
            model: 5
            Rectangle {
                id: slot
                width: (page.width - 2 * Theme.horizontalPageMargin - 4 * Theme.paddingSmall) / 5
                height: width * 0.8
                color: Neon.alpha("#0A0418", 0.85)
                border { width: 2; color: Neon.alpha(m.color, 0.7) }
                property var face: page.lastRow ? page.lastRow[index] : "ghost"
                property var shown: face
                property int ticks: 0
                function roll(c) { ticks = 6 + c * 3; spinT.restart() }
                Timer {
                    id: spinT; interval: 60; repeat: true
                    onTriggered: {
                        if (--slot.ticks <= 0) { stop(); slot.shown = Qt.binding(function () { return slot.face }); if (index === 4) page.rolled(); return }
                        slot.shown = Math.random() < 0.6 ? 15 * index + 1 + Math.floor(Math.random() * 15) : ["joker", "ghost", "coin"][Math.floor(Math.random() * 3)]
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: typeof slot.shown === "number"
                    text: typeof slot.shown === "number" ? slot.shown : ""
                    color: "white"
                    font { family: Neon.mono; bold: true; pixelSize: parent.height * 0.5 }
                }
                Image {
                    anchors { fill: parent; margins: parent.height * 0.1 }
                    fillMode: Image.PreserveAspectFit
                    visible: typeof slot.shown !== "number" && page.playing || (page.ended && typeof slot.shown !== "number")
                    source: typeof slot.shown === "number" ? "" : "../images/sym-arcade-" + ({ joker: "wild", super: "crown", ghost: "ghost", coin: "coin" })[slot.shown] + ".png"
                    opacity: slot.shown === "ghost" ? 0.35 : 1
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top }
                    text: "BINGO"[index]
                    color: m.color
                    font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeExtraSmall }
                }
            }
        }
    }
    // ---- the card ----
    NeonPanel {
        id: cardPanel
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 0.9
        glowColor: page.playing && page.st.queue.length ? Neon.yellow : m.color
        strong: true
        Grid {
            id: grid
            anchors { fill: parent; margins: Theme.paddingMedium }
            columns: 5; spacing: 4
            readonly property real cw: (width - 16) / 5
            readonly property real ch: (height - 16) / 5
            readonly property var view: page.playing ? page.st : page.ended
            Repeater {
                model: 25
                MouseArea {
                    id: cell
                    readonly property int r: Math.floor(index / 5)
                    readonly property int c: index % 5
                    readonly property bool marked: !!grid.view && grid.view.marked[r][c]
                    readonly property bool target: page.playing && !page.rolling && Arcade.canPlace(page.st, r, c)
                    readonly property bool best: target && page.hint && page.hint[0] === r && page.hint[1] === c
                    readonly property bool lined: marked && Arcade.inLine(grid.view, r, c)
                    width: grid.cw; height: grid.ch
                    onClicked: page.tapCell(r, c)
                    Rectangle {
                        anchors.fill: parent
                        color: cell.lined ? Neon.alpha(Neon.yellow, 0.55) : cell.marked ? Neon.alpha(m.color, 0.5) : cell.target ? Neon.alpha(Neon.yellow, cell.best ? 0.35 : 0.12) : Neon.alpha("#0A0418", 0.6)
                        border { width: cell.best ? 3 : 1; color: cell.best ? Neon.yellow : cell.target ? Neon.alpha(Neon.yellow, 0.6) : Neon.alpha(m.color, 0.35) }
                        SequentialAnimation on opacity {
                            running: cell.best; loops: Animation.Infinite
                            NumberAnimation { to: 0.55; duration: 380 } NumberAnimation { to: 1; duration: 380 }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: grid.view ? grid.view.card[cell.r][cell.c] : "BINGO"[cell.c]
                        color: cell.lined ? Neon.ink : cell.marked ? "white" : Theme.secondaryColor
                        font { family: Neon.mono; bold: cell.marked; pixelSize: grid.ch * 0.42 }
                    }
                }
            }
        }
    }
    Item {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeSmall
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.45
            elide: Text.ElideRight
            fontSizeMode: Text.HorizontalFit; minimumPixelSize: Theme.fontSizeTiny
            text: page.playing ? "SPIN " + Math.min(page.st.idx + 1, m.spins) + " / " + m.spins + (page.st.coins ? " · COINS " + Money.fmt(page.st.coins * page.st.stake) : "")
                               : page.ended ? "PAID " + Money.fmt(Arcade.payout(m, page.ended)) : "BUY A CARD TO PLAY"
            color: Neon.alpha(m.color, 0.9)
            font { family: Neon.mono; pixelSize: Theme.fontSizeSmall }
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: parent.width * 0.53
            horizontalAlignment: Text.AlignRight
            fontSizeMode: Text.HorizontalFit; minimumPixelSize: Theme.fontSizeTiny
            text: page.lines + " LINE" + (page.lines === 1 ? "" : "S") + " " + m.ladder[page.lines] + "× → " + (page.lines < 12 ? m.ladder[page.lines + 1] + "×" : "MAX")
            color: Neon.yellow
            font { family: Neon.mono; pixelSize: Theme.fontSizeSmall }
        }
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
            text: !page.playing ? "Buy card · " + Money.fmt(bet.bet)
                  : page.st.queue.length ? "Place your " + (page.st.queue[0].type === "super" ? "super joker" : "joker")
                  : "Spin · " + (m.spins - page.st.idx) + " left"
            color: m.color; primary: true
            fontSize: Theme.fontSizeMedium
            enabled: !page.playing ? Game.canBet(bet.bet) : (!page.rolling && !page.st.queue.length)
            onClicked: page.playing ? page.spin() : page.buy()
        }
    }
}
