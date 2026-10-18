import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// Penalty shootout: swipe from the ball toward a corner (or tap a zone). The keeper dives to
// one of three columns; low shots pay 1.45×, high shots pay 1.94× but one in four sails over the
// bar. Both return 97%. The keeper's dive (and any miss) is drawn and saved before the kick.
TablePage {
    id: page
    title: "Penalty"
    accent: Neon.green
    scene: "circuit"
    musicTrack: "penalty"
    code: "SWIPE TO SHOOT · LOW 1.45× · HIGH 1.94× · 97% RTP"
    info: "Swipe from the ball toward the goal, or tap a zone. The keeper dives to the left, the middle or the right. "
          + "Beat the keeper and a LOW shot pays 1.45×, a HIGH shot 1.94×, but a high shot goes over the bar one time in four. "
          + "Each choice returns 97% on average."
    footerHeight: footerCol.height + Theme.paddingLarge

    property bool shooting: false
    property int aimCol: -1
    property int aimRow: -1                 // 0 top, 1 bottom
    property int keeperCol: 1
    property string verdict: ""
    property int streak: 0
    property var history: []
    busy: shooting

    function pays(row) { return row === 0 ? 1.94 : 1.45 }
    function shoot(col, row) {
        if (shooting || !Game.canBet(bet.bet)) return
        var stake = bet.bet
        Game.stake(stake)
        var k = Math.floor(Math.random() * 3), over = row === 0 && Math.random() < 0.25
        var res = over ? "over" : k === col ? "saved" : "goal"
        Game.pending = { game: "penalty", staked: stake, returned: res === "goal" ? Math.round(stake * pays(row) * 100) / 100 : 0 }
        Game.save()
        aimCol = col; aimRow = row; keeperCol = k; verdict = res
        shooting = true
        kick.restart()
        Sound.play("card"); Haptics.tap()
    }
    function done() {
        var p = Game.pending
        shooting = false
        streak = verdict === "goal" ? streak + 1 : 0
        history = [verdict].concat(history).slice(0, 14)
        if (verdict === "goal") page.burst.show(p.returned - p.staked, streak >= 5)
        else Sound.play("lose")
        Haptics.tap()
        Game.settle(p.staked, p.returned, "penalty")
    }

    // ---- the pitch ----
    Item {
        id: pitch
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 1.05
        // goal
        Item {
            id: goal
            x: parent.width * 0.06; y: parent.height * 0.08
            width: parent.width * 0.88; height: parent.height * 0.42
            Rectangle { anchors.fill: parent; color: Neon.alpha("#0A0418", 0.6); border { width: 4; color: "white" } }
            Grid {
                anchors.fill: parent
                columns: 3
                Repeater {
                    model: 6
                    MouseArea {
                        width: goal.width / 3; height: goal.height / 2
                        enabled: !page.shooting
                        onClicked: page.shoot(index % 3, Math.floor(index / 3))
                        Rectangle {
                            anchors { fill: parent; margins: 2 }
                            color: Neon.alpha(Math.floor(index / 3) === 0 ? Neon.yellow : Neon.green, parent.pressed ? 0.35 : 0.08)
                            border { width: 1; color: Neon.alpha("white", 0.2) }
                            Text {
                                anchors.centerIn: parent
                                text: page.pays(Math.floor(index / 3)).toFixed(2) + "×"
                                color: Neon.alpha(Math.floor(index / 3) === 0 ? Neon.yellow : Neon.green, 0.6)
                                font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall }
                            }
                        }
                    }
                }
            }
            // keeper
            Rectangle {
                id: keeper
                width: goal.width / 3 * 0.8; height: goal.height * 0.85
                radius: width * 0.2
                y: goal.height - height
                x: (page.shooting || page.verdict ? page.keeperCol : 1) * goal.width / 3 + goal.width / 30
                Behavior on x { enabled: page.shooting; NumberAnimation { duration: 380; easing.type: Easing.OutQuad } }
                color: Neon.alpha(Neon.red, 0.55)
                border { width: 3; color: Neon.red }
                Text { anchors.centerIn: parent; text: "AI"; color: "white"; font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeMedium } }
            }
        }
        // ball
        Image {
            id: ball
            source: "../images/coin-heads.png"
            width: Theme.itemSizeMedium * (1 - 0.45 * ballT.v); height: width
            readonly property real homeX: pitch.width / 2 - Theme.itemSizeMedium / 2
            readonly property real homeY: pitch.height * 0.8
            readonly property real tx: page.aimCol < 0 ? homeX : goal.x + (page.aimCol + 0.5) * goal.width / 3 - width / 2
            readonly property real ty: page.aimRow < 0 ? homeY : (page.verdict === "over" ? goal.y - height * 1.2 : goal.y + (page.aimRow + 0.5) * goal.height / 2 - height / 2)
            x: homeX + (tx - homeX) * ballT.v
            y: homeY + (ty - homeY) * ballT.v
        }
        QtObject { id: ballT; property real v: 0 }
        SequentialAnimation {
            id: kick
            NumberAnimation { target: ballT; property: "v"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 500 }
            ScriptAction { script: page.done() }
            PauseAnimation { duration: 700 }
            NumberAnimation { target: ballT; property: "v"; to: 0; duration: 1 }
        }
        NeonText {
            anchors { horizontalCenter: parent.horizontalCenter; top: goal.bottom; topMargin: Theme.paddingLarge }
            visible: !page.shooting && page.verdict !== ""
            text: page.verdict === "goal" ? "GOAL!" : page.verdict === "saved" ? "SAVED" : "OVER THE BAR"
            color: page.verdict === "goal" ? Neon.green : Neon.red
            font.pixelSize: Theme.fontSizeExtraLarge
        }
        MouseArea {        // swipe from the ball toward the goal
            x: 0; y: goal.y + goal.height; width: parent.width; height: parent.height - y
            enabled: !page.shooting
            property real x0; property real y0
            onPressed: { x0 = mouse.x; y0 = mouse.y }
            onReleased: {
                var dx = mouse.x - x0, dy = y0 - mouse.y
                if (dy < Theme.itemSizeSmall * 0.5) return
                var col = dx < -dy * 0.25 ? 0 : dx > dy * 0.25 ? 2 : 1
                var row = dy > Theme.itemSizeLarge * 1.6 ? 0 : 1          // a long, hard swipe goes high
                page.shoot(col, row)
            }
        }
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            text: "SWIPE UP · LONG SWIPE = HIGH · OR TAP A ZONE"
            color: Theme.secondaryColor
            font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 1 }
        }
    }
    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall
        Text { text: "STREAK " + page.streak; color: page.streak >= 3 ? Neon.yellow : Theme.secondaryColor; font { family: Neon.mono; pixelSize: Theme.fontSizeSmall } }
        Repeater {
            model: page.history
            Text { text: modelData === "goal" ? "●" : "○"; color: modelData === "goal" ? Neon.green : Neon.red; font.pixelSize: Theme.fontSizeSmall }
        }
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        BetSelector { id: bet; width: parent.width; locked: page.busy; color: Neon.yellow }
    }
}
