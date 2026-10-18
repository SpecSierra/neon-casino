import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// Drone race: six drones, fixed odds (the favourite wins most, the long shot pays most). Back
// one, launch, watch. Every drone returns 97% (odds = 0.97 / chance). The winner and the whole
// race (each drone's finishing time) are drawn and saved before the gates open.
TablePage {
    id: page
    title: "Drone race"
    accent: Neon.green
    scene: "circuit"
    musicTrack: "race"
    code: "BACK A DRONE · 6 RUNNERS · 97% RTP"
    info: "Pick a drone, then launch. If it crosses the line first you win the odds shown. "
          + "The favourite wins about a third of the races; the long shot pays 12×."
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property var drones: [
        { name: "VOLT", p: 0.32, color: Neon.cyan }, { name: "HEX", p: 0.22, color: Neon.green },
        { name: "GLITCH", p: 0.16, color: Neon.yellow }, { name: "ROGUE", p: 0.12, color: "#FF9F14" },
        { name: "NULL", p: 0.10, color: Neon.pink }, { name: "ZERO", p: 0.08, color: Neon.red }
    ]
    function odds(i) { return Math.floor(0.97 / drones[i].p * 100) / 100 }
    property int pick: 0
    property bool racing: false
    property real t: 0                  // race clock, 0..1 = the winner's finish
    property var finish: [1, 1, 1, 1, 1, 1]   // finishing time of each drone (winner = 1)
    property var wobble: [0, 0, 0, 0, 0, 0]
    property int winner: -1
    property var history: []
    busy: racing

    function launch() {
        if (racing || !Game.canBet(bet.bet)) return
        var stake = bet.bet
        Game.stake(stake)
        var r = Math.random(), w = 0
        for (var i = 0; i < drones.length; ++i) { r -= drones[i].p; if (r < 0) { w = i; break } }
        var f = [], wb = []
        for (i = 0; i < drones.length; ++i) { f.push(i === w ? 1 : 1.03 + Math.random() * 0.25); wb.push(Math.random() * 6.28) }
        Game.pending = { game: "race", staked: stake, returned: w === pick ? Math.round(stake * odds(pick) * 100) / 100 : 0, winner: w }
        Game.save()
        finish = f; wobble = wb; winner = -1
        racing = true
        clock.restart()
        Sound.play("reel"); Haptics.tap()
    }
    NumberAnimation { id: clock; target: page; property: "t"; from: 0; to: 1.3; duration: 5200; easing.type: Easing.Linear; onStopped: page.done() }
    property bool crossed: false
    onTChanged: if (racing && !crossed && t >= 1) { crossed = true; winner = Game.pending.winner; Sound.play("tick") }
    function done() {
        var p = Game.pending
        racing = false; crossed = false
        winner = p.winner
        history = [p.winner].concat(history).slice(0, 10)
        if (p.returned > 0) page.burst.show(p.returned - p.staked, page.odds(page.pick) >= 8)
        else Sound.play("lose")
        Haptics.tap()
        Game.settle(p.staked, p.returned, "race")
    }
    // position along the track (0..1) of drone i at race time t: ease-in-out with a wobble,
    // reaching 1 exactly at its finishing time
    function pos(i, tt) {
        var u = Math.min(1, tt / finish[i])
        var base = u * u * (3 - 2 * u) * 0.35 + u * 0.65
        return Math.min(1, base + 0.03 * Math.sin(tt * 9 + wobble[i]) * (1 - u) * u * 4)
    }

    // ---- the track ----
    NeonPanel {
        id: track
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeSmall * 1.05 * page.drones.length + 2 * Theme.paddingLarge
        glowColor: Neon.green
        Rectangle {          // finish line
            x: parent.width - Theme.paddingLarge - Theme.itemSizeSmall * 0.5
            y: Theme.paddingMedium; width: 4; height: parent.height - 2 * y
            color: "white"; opacity: 0.8
        }
        Column {
            anchors { fill: parent; margins: Theme.paddingLarge }
            Repeater {
                model: page.drones
                Item {
                    width: parent.width; height: Theme.itemSizeSmall * 1.05
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Neon.alpha(modelData.color, 0.25) }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: Neon.alpha(modelData.color, 0.35)
                        font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeLarge }
                    }
                    Image {
                        width: parent.height * 0.8; height: width
                        anchors.verticalCenter: parent.verticalCenter
                        x: page.pos(index, page.t) * (parent.width - width - Theme.itemSizeSmall * 0.3)
                        source: "../images/sym-race.png"
                        opacity: index === page.pick ? 1 : 0.75
                        Rectangle {
                            anchors.fill: parent; radius: width / 2
                            color: "transparent"; border { width: 2; color: modelData.color }
                            visible: index === page.pick
                        }
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        visible: page.winner === index
                        text: "1ST"
                        color: Neon.yellow
                        font { family: Neon.mono; bold: true; pixelSize: Theme.fontSizeSmall }
                    }
                }
            }
        }
    }
    // ---- the board: pick your drone ----
    Grid {
        id: board
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        columns: 3; spacing: 3
        Repeater {
            model: page.drones
            MouseArea {
                width: (board.width - 6) / 3; height: Theme.itemSizeSmall * 1.1
                enabled: !page.racing
                onClicked: { page.pick = index; Sound.play("click"); Haptics.tick() }
                Rectangle {
                    anchors.fill: parent
                    color: Neon.alpha(modelData.color, index === page.pick ? 0.45 : 0.12)
                    border { width: index === page.pick ? 3 : 1; color: modelData.color }
                }
                Column {
                    anchors.centerIn: parent
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; color: "white"; font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeSmall } }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: page.odds(index).toFixed(2) + "×"; color: modelData.color; font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall } }
                }
            }
        }
    }
    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall
        Text { text: "WINNERS"; color: Neon.alpha(Neon.green, 0.7); font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 2 } }
        Repeater {
            model: page.history
            Text { text: page.drones[modelData].name; color: page.drones[modelData].color; font { family: Neon.mono; pixelSize: Theme.fontSizeTiny } }
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
            text: page.racing ? "Racing…" : "Launch · " + Money.fmt(bet.bet) + " on " + page.drones[page.pick].name
            color: Neon.green; primary: true
            fontSize: Theme.fontSizeMedium
            enabled: !page.racing && Game.canBet(bet.bet)
            onClicked: page.launch()
        }
    }
}
