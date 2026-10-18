import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// Rock paper scissors against the house AI. Win pays 1.91×, a tie gives the bet back, so the
// game returns 97%. The AI's hand is drawn and saved the moment you throw.
TablePage {
    id: page
    title: "Rock paper scissors"
    accent: Neon.pink
    scene: "circuit"
    musicTrack: "rps"
    code: "BEAT THE AI · WIN 1.91× · TIE = PUSH · 97% RTP"
    info: "Tap rock, paper or scissors to throw. Rock blunts scissors, scissors cut paper, paper wraps rock. "
          + "A win returns 1.91× your bet, a tie returns your bet, a loss takes it."
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property var hands: [{ id: "rock", name: "ROCK" }, { id: "paper", name: "PAPER" }, { id: "scissors", name: "SCISSORS" }]
    property int mine: -1
    property int theirs: -1
    property bool throwing: false
    property string verdict: ""
    property int streak: 0
    busy: throwing

    function play(h) {
        if (throwing || !Game.canBet(bet.bet)) return
        var stake = bet.bet
        Game.stake(stake)
        var ai = Math.floor(Math.random() * 3)
        var res = ai === h ? "tie" : (h - ai + 3) % 3 === 1 ? "win" : "lose"
        Game.pending = { game: "rps", staked: stake, returned: res === "win" ? Math.round(stake * 191) / 100 : res === "tie" ? stake : 0 }
        Game.save()
        mine = h; theirs = ai; verdict = res; throwing = true
        shake.restart()
        Sound.play("card"); Haptics.tick()
    }
    function reveal() {
        var p = Game.pending
        throwing = false
        streak = verdict === "win" ? streak + 1 : verdict === "lose" ? 0 : streak
        if (verdict === "win") page.burst.show(p.returned - p.staked, streak >= 4)
        else if (verdict === "lose") Sound.play("lose")
        Haptics.tap()
        Game.settle(p.staked, p.returned, "rps")
    }

    // ---- the duel ----
    NeonPanel {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 0.85
        glowColor: page.throwing || !page.verdict ? Neon.pink : page.verdict === "win" ? Neon.green : page.verdict === "tie" ? Neon.yellow : Neon.red
        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingLarge * 2
            Repeater {
                model: [{ who: "YOU", i: page.mine, c: Neon.cyan }, { who: "AI", i: page.theirs, c: Neon.pink }]
                Column {
                    spacing: Theme.paddingMedium
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.who; color: modelData.c; font { family: Neon.mono; pixelSize: Theme.fontSizeSmall; letterSpacing: 3 } }
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Theme.itemSizeExtraLarge * 1.2; height: width
                        source: "../images/rps-" + (page.throwing || modelData.i < 0 ? "rock" : page.hands[modelData.i].id) + ".png"
                        opacity: modelData.i < 0 && !page.throwing ? 0.3 : 1
                        mirror: index === 1
                        transform: Translate { y: page.throwing ? shakeY.v : 0 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: !page.throwing && modelData.i >= 0 ? page.hands[modelData.i].name : " "
                        color: "white"; font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeMedium }
                    }
                }
            }
        }
        NeonText {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.paddingLarge }
            visible: !page.throwing && page.verdict !== ""
            text: page.verdict === "win" ? "YOU WIN" : page.verdict === "tie" ? "TIE · PUSH" : "AI WINS"
            color: page.verdict === "win" ? Neon.green : page.verdict === "tie" ? Neon.yellow : Neon.red
            font.pixelSize: Theme.fontSizeExtraLarge
        }
        Text {
            anchors { right: parent.right; top: parent.top; margins: Theme.paddingLarge }
            text: "STREAK " + page.streak
            color: page.streak >= 3 ? Neon.yellow : Theme.secondaryColor
            font { family: Neon.mono; pixelSize: Theme.fontSizeSmall }
        }
    }
    QtObject { id: shakeY; property real v: 0 }
    SequentialAnimation {        // "rock, paper, scissors, shoot": three pumps then the reveal
        id: shake
        loops: 1
        SequentialAnimation {
            loops: 3
            NumberAnimation { target: shakeY; property: "v"; to: -Theme.paddingLarge * 2; duration: 140; easing.type: Easing.OutQuad }
            NumberAnimation { target: shakeY; property: "v"; to: 0; duration: 140; easing.type: Easing.InQuad }
        }
        ScriptAction { script: page.reveal() }
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        BetSelector { id: bet; width: parent.width; locked: page.busy; color: Neon.yellow }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            Repeater {
                model: page.hands
                NeonButton {
                    width: (page.width - 2 * Theme.horizontalPageMargin - 2 * Theme.paddingSmall) / 3
                    height: Theme.itemSizeLarge
                    text: modelData.name
                    color: [Neon.cyan, Neon.yellow, Neon.pink][index]; primary: true
                    fontSize: Theme.fontSizeExtraSmall
                    enabled: !page.throwing && Game.canBet(bet.bet)
                    onClicked: page.play(index)
                }
            }
        }
    }
}
