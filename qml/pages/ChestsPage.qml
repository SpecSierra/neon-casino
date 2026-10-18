import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// Treasure chests: three chests, one pick. The contents are drawn and saved when you pay; then
// all three open so you see what you missed. One deal in fifty is a golden set with a 15× chest.
// 96.9% RTP whatever you pick.
TablePage {
    id: page
    title: "Treasure chests"
    accent: "#FF9F14"
    scene: "velvet"
    musicTrack: "chests"
    code: "PICK ONE OF THREE · GOLDEN SET 15× · 97% RTP"
    info: "Pay your bet and three chests are filled. Tap one to keep what's inside; then the other two open. "
          + "Most deals hide prizes between 0× and 2.66×; one deal in fifty is a golden set with a 15× chest. "
          + "No chest is better than another on average: it returns about 97% whichever you pick."
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property var sets: [[0, 0, 2.66], [0, 0.66, 2], [0.2, 0.66, 1.8], [0.4, 0.4, 1.86], [0.3, 0.9, 1.46]]
    property var deal: []             // three values, × bet
    property int picked: -1
    property bool open: false
    property real stake: 0
    property bool golden: false
    readonly property bool waiting: deal.length === 3 && picked < 0
    busy: waiting || (picked >= 0 && !open)

    function pay() {
        if (deal.length && picked < 0) return
        if (!Game.canBet(bet.bet)) return
        stake = bet.bet
        Game.stake(stake)
        golden = Math.random() < 0.02
        var s = (golden ? [0, 0, 15] : sets[Math.floor(Math.random() * sets.length)]).slice()
        for (var k = 2; k > 0; --k) { var j = Math.floor(Math.random() * (k + 1)), t = s[k]; s[k] = s[j]; s[j] = t }
        // until a chest is picked the expected return is the set's mean; settle on load at that
        Game.pending = { game: "chests", staked: stake, returned: Math.round(stake * (s[0] + s[1] + s[2]) / 3 * 100) / 100 }
        Game.save()
        deal = s; picked = -1; open = false
        Sound.play("card"); Haptics.tap()
    }
    function pick(i) {
        if (!waiting) return
        picked = i
        var p = Game.pending
        p.returned = Math.round(stake * deal[i] * 100) / 100
        Game.pending = p
        Game.save()
        Sound.play("tick"); Haptics.tap()
        openT.restart()
    }
    Timer {
        id: openT; interval: 700
        onTriggered: {
            page.open = true
            var p = Game.pending
            if (page.golden) Game.note("GOLDEN SET", Neon.yellow)
            if (p.returned > p.staked) page.burst.show(p.returned - p.staked, page.deal[page.picked] >= 10)
            else if (p.returned === 0) Sound.play("lose")
            Game.settle(p.staked, p.returned, "chests")
        }
    }

    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingMedium
        Repeater {
            model: 3
            MouseArea {
                id: chest
                width: (page.width - 2 * Theme.horizontalPageMargin - 2 * Theme.paddingMedium) / 3
                height: width * 1.4
                enabled: page.waiting
                onClicked: page.pick(index)
                readonly property bool revealed: page.deal.length === 3 && (index === page.picked || page.open)
                readonly property real v: page.deal.length === 3 ? page.deal[index] : 0
                scale: index === page.picked ? 1.08 : 1
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                NeonPanel {
                    anchors.fill: parent
                    glowColor: chest.revealed ? (chest.v >= 10 ? Neon.yellow : chest.v > 1 ? Neon.green : chest.v > 0 ? Neon.cyan : Neon.red) : "#FF9F14"
                    glowStrength: index === page.picked ? 0.95 : page.waiting ? 0.5 : 0.25
                    strong: index === page.picked
                }
                Image {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.paddingLarge }
                    width: parent.width * 0.75; height: width
                    source: "../images/sym-chest.png"
                    opacity: chest.revealed ? 0.35 : 1
                    SequentialAnimation on rotation {
                        running: page.waiting; loops: Animation.Infinite
                        PauseAnimation { duration: 400 * index } NumberAnimation { to: 4; duration: 120 } NumberAnimation { to: -4; duration: 160 } NumberAnimation { to: 0; duration: 120 } PauseAnimation { duration: 1400 }
                    }
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.paddingLarge }
                    text: chest.revealed ? (chest.v ? chest.v + "×" : "EMPTY") : page.waiting ? "TAP" : ""
                    color: chest.revealed ? (chest.v >= 10 ? Neon.yellow : chest.v > 1 ? Neon.green : chest.v > 0 ? "white" : Neon.red) : Theme.secondaryColor
                    font { family: Neon.mono; bold: true; pixelSize: chest.revealed ? Theme.fontSizeLarge : Theme.fontSizeSmall }
                }
            }
        }
    }
    Text {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: page.waiting ? "PICK A CHEST" : page.open ? (page.deal[page.picked] ? "YOU KEPT " + Money.fmt(page.stake * page.deal[page.picked]) : "EMPTY · BETTER LUCK NEXT TIME") + (page.golden ? " · GOLDEN SET" : "")
              : "PAY TO FILL THREE CHESTS"
        color: page.open && page.deal[page.picked] > 1 ? Neon.green : Theme.secondaryColor
        font { family: Neon.mono; pixelSize: Theme.fontSizeSmall; letterSpacing: 1 }
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
            text: page.waiting ? "Pick a chest" : "Fill chests · " + Money.fmt(bet.bet)
            color: "#FF9F14"; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: !page.busy && Game.canBet(bet.bet)
            onClicked: page.pay()
        }
    }
}
