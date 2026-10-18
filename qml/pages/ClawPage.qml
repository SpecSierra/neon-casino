import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// Claw machine: the claw sweeps the cabinet; tap Drop (or the glass) to drop it on the prize
// below. Bigger prizes are harder to hold: the grip chance is 0.97 / prize, so every prize
// returns 97%. The grab is decided and saved the moment you drop.
TablePage {
    id: page
    title: "Claw machine"
    accent: Neon.yellow
    scene: "arcade"
    musicTrack: "claw"
    code: "TIME THE DROP · BIG PRIZES SLIP · 97% RTP"
    info: "The claw slides back and forth. Tap Drop (or the glass) when it's over the prize you want. "
          + "Prizes pay 1.2×, 2×, 3×, 5× and 10× your bet; the bigger the prize, the more likely it slips: "
          + "81%, 49%, 32%, 19% and 10% to hold it. Whatever you aim for, it returns 97%."
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property var prizes: [
        { v: 2, color: Neon.green }, { v: 5, color: Neon.pink }, { v: 1.2, color: Neon.cyan },
        { v: 10, color: Neon.red }, { v: 3, color: Neon.yellow }
    ]
    property real clawX: 0.5          // 0..1 across the cabinet
    property int dir: 1
    property string phase: "sweep"    // sweep | drop | lift | done
    property int target: -1
    property bool caught: false
    property real ropeT: 0            // 0 up, 1 down
    property real slipAt: 1           // how far up the prize falls out (1 = it holds)
    busy: phase !== "sweep"

    Timer {
        interval: 16; repeat: true
        running: page.phase === "sweep" && page.status === PageStatus.Active && Qt.application.active
        onTriggered: {
            page.clawX += page.dir * 0.009
            if (page.clawX > 0.95) { page.clawX = 0.95; page.dir = -1 }
            if (page.clawX < 0.05) { page.clawX = 0.05; page.dir = 1 }
        }
    }
    function drop() {
        if (phase !== "sweep" || !Game.canBet(bet.bet)) return
        var stake = bet.bet
        target = Math.max(0, Math.min(prizes.length - 1, Math.floor(clawX * prizes.length)))
        Game.stake(stake)
        caught = Math.random() < 0.97 / prizes[target].v
        slipAt = caught ? 1 : 0.25 + Math.random() * 0.5
        Game.pending = { game: "claw", staked: stake, returned: caught ? Math.round(stake * prizes[target].v * 100) / 100 : 0 }
        Game.save()
        phase = "drop"
        dropAnim.restart()
        Sound.play("reel"); Haptics.tap()
    }
    function done() {
        var p = Game.pending
        phase = "sweep"
        if (caught) page.burst.show(p.returned - p.staked, prizes[target].v >= 5)
        else { Sound.play("lose"); Game.note("IT SLIPPED", Neon.red) }
        Haptics.tap()
        Game.settle(p.staked, p.returned, "claw")
        target = -1
    }
    SequentialAnimation {
        id: dropAnim
        NumberAnimation { target: page; property: "ropeT"; from: 0; to: 1; duration: 700; easing.type: Easing.InQuad }
        ScriptAction { script: { page.phase = "lift"; Sound.play("tick") } }
        PauseAnimation { duration: 250 }
        NumberAnimation { target: page; property: "ropeT"; to: 0; duration: 900; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 300 }
        ScriptAction { script: page.done() }
    }

    NeonPanel {
        id: cabinet
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 1.05
        glowColor: Neon.yellow
        strong: true
        Item {
            id: glass
            anchors { fill: parent; margins: Theme.paddingLarge }
            clip: true
            readonly property real floorY: height * 0.82
            readonly property real slotW: width / page.prizes.length
            // prizes on the floor
            Repeater {
                model: page.prizes
                Item {
                    id: prize
                    readonly property bool held: index === page.target && page.phase === "lift" && (page.caught || page.ropeT > 1 - page.slipAt)
                    width: glass.slotW * 0.78; height: width
                    x: index * glass.slotW + (glass.slotW - width) / 2
                    // carried: hangs under the claw, never below the floor
                    y: held ? Math.min(glass.floorY - height, claw.y + claw.height * 0.75) : glass.floorY - height
                    Behavior on y { enabled: !prize.held && page.phase !== "sweep"; NumberAnimation { duration: 300; easing.type: Easing.OutBounce } }
                    Rectangle {
                        anchors.fill: parent; radius: width / 2
                        color: Neon.alpha(modelData.color, 0.35)
                        border { width: 3; color: modelData.color }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: modelData.v + "×"
                        color: "white"
                        font { family: Neon.mono; bold: true; pixelSize: parent.width * 0.3 }
                    }
                }
            }
            Rectangle { x: 0; y: glass.floorY; width: parent.width; height: 3; color: Neon.alpha(Neon.yellow, 0.6) }
            // the claw
            Rectangle {      // rope
                x: claw.x + claw.width / 2 - 1.5; y: 0; width: 3; height: claw.y
                color: Neon.alpha("white", 0.7)
            }
            Image {
                id: claw
                source: "../images/sym-claw.png"
                width: glass.slotW * 0.9; height: width
                x: page.clawX * glass.width - width / 2
                y: page.ropeT * (glass.floorY - height * 0.95)
            }
        }
        MouseArea { anchors.fill: parent; enabled: page.phase === "sweep"; onClicked: page.drop() }
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
            text: page.phase === "sweep" ? "Drop · " + Money.fmt(bet.bet) : "Grabbing…"
            color: Neon.yellow; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: page.phase === "sweep" && Game.canBet(bet.bet)
            onClicked: page.drop()
        }
    }
}
