import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/Money.js" as Money
import "."

// Bet picker on a 1-2.5-5 ladder, clamped to [min bet, balance].
Item {
    id: sel
    objectName: "betSelector"
    property var game: Game
    property real bet: game.minBet
    property bool locked: false
    property color color: Neon.yellow
    property int factor: 1               // the table charges bet × factor (slot lines)
    property string caption: "BET"
    onFactorChanged: clamp()
    height: Theme.itemSizeMedium

    function ladderUp(v) {
        var p = Math.pow(10, Math.floor(Math.log(v) / Math.LN10 + 1e-9))
        // whole dollars only: 2.5 is a step from 10 up (25, 250 …), otherwise 2 → 2.5 floors back to 2
        var steps = p >= 10 ? [1, 2, 2.5, 5, 10] : [1, 2, 5, 10]
        for (var i = 0; i < steps.length; ++i) if (steps[i] * p > v + 1e-9) return steps[i] * p
        return 10 * p
    }
    function ladderDown(v) {
        var p = Math.pow(10, Math.floor(Math.log(v) / Math.LN10 + 1e-9))
        var steps = p >= 10 ? [5, 2.5, 2, 1, 0.5] : [5, 2, 1, 0.5]
        for (var i = 0; i < steps.length; ++i) if (steps[i] * p < v - 1e-9) return steps[i] * p
        return v / 2
    }
    function clamp() {
        var b = Math.floor(sel.bet)
        b = Math.min(b, Math.floor(game.balance / factor))
        b = Math.max(b, Math.max(1, Math.ceil(game.minBet / factor)))
        if (b !== sel.bet) sel.bet = b
    }
    // + / − climb the 1-2-5 ladder; past the ladder top the next step is your whole stack.
    function stepUp() {
        var maxBet = Math.floor(game.balance / factor)
        var next = Math.floor(ladderUp(bet))
        bet = next > maxBet ? maxBet : next
        clamp()
        Haptics.tick()
    }
    function stepDown() { bet = Math.floor(ladderDown(bet)); clamp(); Haptics.tick() }
    // hold to repeat, speeding up
    Timer {
        id: repeat
        property int dir: 1
        repeat: true
        onTriggered: {
            if (dir > 0) sel.stepUp(); else sel.stepDown()
            interval = Math.max(70, interval * 0.8)
        }
    }
    Connections { target: sel.game; onMinBetChanged: sel.clamp(); onBalanceChanged: if (!sel.locked) sel.clamp() }
    Component.onCompleted: clamp()

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.paddingSmall
        // ½ − [BET] + MAX across the page width
        property real u: (sel.width - 2 * Theme.horizontalPageMargin - 4 * spacing) / 6.5
        NeonButton {
            text: "½"; width: row.u; color: sel.color; enabled: !sel.locked
            onClicked: { sel.bet = Math.floor(sel.bet / 2); sel.clamp() }
        }
        NeonButton {
            text: "−"; width: row.u; color: sel.color; enabled: !sel.locked
            onClicked: sel.stepDown()
            onPressAndHold: { repeat.dir = -1; repeat.interval = 260; repeat.start() }
            onReleased: repeat.stop()
            onCanceled: repeat.stop()
        }
        NeonPanel {
            width: row.u * 2.2; height: Theme.itemSizeSmall
            glowColor: sel.color; strong: true
            Column {
                anchors.centerIn: parent
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: sel.factor > 1 ? sel.caption + " ×" + sel.factor : sel.caption; color: Neon.alpha(sel.color, 0.7)
                    font { pixelSize: Theme.fontSizeTiny; letterSpacing: 3; family: Neon.display }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Money.fmt(sel.bet); color: sel.color
                    font { pixelSize: Theme.fontSizeMedium; bold: true; family: Neon.display }
                }
            }
        }
        NeonButton {
            text: "+"; width: row.u; color: sel.color; enabled: !sel.locked
            onClicked: sel.stepUp()
            onPressAndHold: { repeat.dir = 1; repeat.interval = 260; repeat.start() }
            onReleased: repeat.stop()
            onCanceled: repeat.stop()
        }
        NeonButton {
            text: "MAX"; width: row.u * 1.3; color: Neon.red; enabled: !sel.locked
            fontSize: Theme.fontSizeExtraSmall
            onClicked: { sel.bet = Math.floor(sel.game.balance / sel.factor); sel.clamp() }
        }
    }
}
