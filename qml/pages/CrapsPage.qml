import QtQuick 2.6
import QtSensors 5.2
import Sailfish.Silica 1.0
import "../components"
import "../js/Craps.js" as Craps
import "../js/Money.js" as Money

// Craps. Place chips, then flick the dice across the felt (or shake the phone, or tap Roll).
// Bets stay on the table between rolls (saved in Game.craps); each roll is decided and saved
// before the dice land.
TablePage {
    id: page
    title: "Craps"
    accent: Neon.green
    scene: "felt"
    code: "PASS · ODDS · FIELD · FLICK OR SHAKE"
    musicTrack: "craps"
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property var st: Game.craps || { point: 0, table: {} }
    property var fresh: ({})                 // chips placed since the last roll (not yet staked)
    property var dice: [3, 4]
    property var history: []
    property bool rolling: false
    property var lastResult: null
    property int chipIndex: 0
    busy: rolling
    readonly property real freshTotal: sum(fresh)
    readonly property real canAfford: Game.balance - freshTotal

    readonly property var chipValues: {
        var b = Game.balance + Game.crapsOnTable, out = [], fr = [0.01, 0.05, 0.2, 0.5]
        for (var i = 0; i < fr.length; ++i) { var v = Math.max(Game.minBet, niceFloor(b * fr[i])); if (out.indexOf(v) < 0) out.push(v) }
        return out
    }
    readonly property real chip: chipValues[Math.min(chipIndex, chipValues.length - 1)]
    function niceFloor(v) {
        if (v < 1) return 1
        var p = Math.pow(10, Math.floor(Math.log(v) / Math.LN10 + 1e-9)), steps = p >= 10 ? [5, 2.5, 2, 1] : [5, 2, 1]
        for (var i = 0; i < steps.length; ++i) if (steps[i] * p <= v + 1e-9) return steps[i] * p
        return p
    }
    function sum(b) { var t = 0; for (var k in b) t += b[k]; return t }
    function onTable(key) { return (st.table[key] || 0) + (fresh[key] || 0) }
    function blocked() { return Game.runOver || Game.sessionLocked || Game.pending || Game.blackjack || Game.poker || Game.slotBonus }

    function place(key) {
        if (rolling || blocked()) return
        var probe = { point: st.point, table: {} }
        for (var k in st.table) probe.table[k] = st.table[k]
        for (k in fresh) probe.table[k] = (probe.table[k] || 0) + fresh[k]
        if (!Craps.canPlace(probe, key)) {
            Game.note(key === "odds" ? "ODDS NEED A POINT AND A PASS BET" : "ONLY ON THE COME-OUT ROLL", Neon.red); return
        }
        var amt = chip
        if (key === "odds") amt = Math.min(amt, Craps.oddsLimit(probe))
        if (amt <= 0) { Game.note("ODDS ARE CAPPED AT 3× PASS", Neon.red); return }
        if (amt > canAfford + 1e-9) { Game.note("NOT ENOUGH CREDITS", Neon.red); return }
        var f = {}; for (k in fresh) f[k] = fresh[k]
        f[key] = (f[key] || 0) + amt
        fresh = f
        Sound.play("tick"); Haptics.tick()
    }
    function clearFresh(key) { if (rolling || !fresh[key]) return; var f = {}; for (var k in fresh) if (k !== key) f[k] = fresh[k]; fresh = f }

    function throwDice(power) {
        if (rolling || blocked()) return
        var totalAfter = sum(st.table) + freshTotal
        if (totalAfter <= 0) { Game.note("PLACE A BET FIRST", Neon.green); return }
        if (freshTotal > 0 && freshTotal < Game.minBet && sum(st.table) === 0) { Game.note("MINIMUM BET " + Money.fmt(Game.minBet), Neon.red); return }
        if (freshTotal > 0) Game.stake(freshTotal)
        var merged = { point: st.point, table: {} }, k
        for (k in st.table) merged.table[k] = st.table[k]
        for (k in fresh) merged.table[k] = (merged.table[k] || 0) + fresh[k]
        fresh = ({})
        var d = Craps.roll(), r = Craps.resolve(merged, d)
        Game.craps = r.state
        if (r.staked > 0) Game.pending = { game: "craps", staked: r.staked, returned: r.returned }
        Game.save()                                      // decided before the dice stop
        lastResult = r
        rolling = true
        throwAnim.duration = 700 + 500 * (power === undefined ? 0.5 : power)
        targetDice = d
        Sound.play("card"); Haptics.tap()
        tumble.start(); throwAnim.restart()
    }
    property var targetDice: [1, 1]
    Timer { id: tumble; interval: 70; repeat: true; onTriggered: page.dice = Craps.roll() }
    function landed() {
        tumble.stop()
        dice = targetDice
        rolling = false
        Haptics.tap(); Sound.play("tick")
        var r = lastResult
        history = [r.total].concat(history).slice(0, 14)
        if (r.events.length) Game.note(r.events.join(" · "), r.outcome === "seven" || r.outcome === "craps" ? Neon.red : Neon.green)
        if (r.staked > 0) {
            if (r.returned > r.staked) page.burst.show(r.returned - r.staked, r.returned >= r.staked * 4)
            else if (r.returned < r.staked) Sound.play("lose")
            Game.settle(r.staked, r.returned, "craps")
        }
        if (Game.crapsOnTable === 0) { Game.craps = null; Game.save() }
    }

    // shake to roll
    Accelerometer {
        id: accel
        active: Qt.application.active && page.status === PageStatus.Active && !page.rolling
        property real last: 0
        onReadingChanged: {
            var r = reading, g = Math.sqrt(r.x * r.x + r.y * r.y + r.z * r.z)
            var now = Date.now()
            if (Math.abs(g - 9.81) > 9 && now - last > 1500) { last = now; page.throwDice(Math.min(1, (Math.abs(g - 9.81) - 9) / 10)) }
        }
    }

    // ---- the felt: dice area ----
    NeonPanel {
        id: feltPanel
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 0.62
        glowColor: Neon.green
        Item {
            id: diceArea
            anchors { fill: parent; margins: Theme.paddingMedium }
            clip: true
            // point puck
            Rectangle {
                anchors { right: parent.right; top: parent.top }
                width: Theme.itemSizeSmall; height: width; radius: width / 2
                color: page.st.point ? "white" : Neon.ink
                border { width: 3; color: page.st.point ? Neon.green : Neon.alpha("white", 0.4) }
                Text {
                    anchors.centerIn: parent
                    text: page.st.point ? String(page.st.point) : "OFF"
                    color: page.st.point ? Neon.ink : "white"
                    font { pixelSize: page.st.point ? Theme.fontSizeLarge : Theme.fontSizeTiny; bold: true; family: Neon.display }
                }
            }
            Text {
                anchors { left: parent.left; top: parent.top }
                text: page.st.point ? "HIT " + page.st.point + " BEFORE A 7" : "COME-OUT ROLL"
                color: Neon.alpha(Neon.green, 0.9)
                font { pixelSize: Theme.fontSizeExtraSmall; bold: true; letterSpacing: 1; family: Neon.display }
            }
            Item {
                id: diceGroup
                width: d1.width * 2.3; height: d1.width
                x: (diceArea.width - width) / 2; y: (diceArea.height - height) / 2
                Die { id: d1; width: Theme.itemSizeMedium * 0.9; face: page.dice[0] }
                Die { id: d2; width: d1.width; x: d1.width * 1.3; face: page.dice[1]; ink: Neon.cyan }
            }
            NumberAnimation {
                id: throwAnim
                property real fromX: diceArea.width
                target: diceGroup; property: "x"
                from: diceArea.width; to: (diceArea.width - diceGroup.width) / 2
                easing.type: Easing.OutBounce
                onStarted: { rot1.restart(); rot2.restart() }
                onStopped: page.landed()
            }
            RotationAnimation { id: rot1; target: d1; from: 0; to: 720 + Math.random() * 360; duration: throwAnim.duration; easing.type: Easing.OutCubic; onStopped: d1.rotation = 0 }
            RotationAnimation { id: rot2; target: d2; from: 0; to: -720 - Math.random() * 360; duration: throwAnim.duration; easing.type: Easing.OutCubic; onStopped: d2.rotation = 0 }
            NeonText {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                visible: !page.rolling && page.lastResult !== null
                text: page.lastResult ? String(page.lastResult.total) : ""
                color: Neon.yellow; glow: 10
                font.pixelSize: Theme.fontSizeExtraLarge
            }
            // flick to throw
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                property real x0; property real y0; property real t0
                onPressed: { x0 = mouse.x; y0 = mouse.y; t0 = Date.now() }
                onReleased: {
                    var dx = mouse.x - x0, dy = mouse.y - y0, dist = Math.sqrt(dx * dx + dy * dy)
                    if (dist > Theme.itemSizeSmall) page.throwDice(Math.min(1, dist / Math.max(1, Date.now() - t0) / 3))
                }
            }
        }
    }
    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall
        Text { text: "ROLLS"; color: Neon.alpha(Neon.green, 0.7); font { pixelSize: Theme.fontSizeTiny; letterSpacing: 2; family: Neon.display } }
        Repeater {
            model: page.history
            Text {
                text: modelData
                color: modelData === 7 ? Neon.red : [2, 3, 12].indexOf(modelData) >= 0 ? Neon.violet : Neon.green
                font { pixelSize: Theme.fontSizeExtraSmall; bold: true; family: Neon.display }
            }
        }
    }

    // ---- the layout ----
    Grid {
        id: layout
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        columns: 2
        spacing: Theme.paddingSmall
        property real w: (width - spacing) / 2
        Repeater {
            model: [
                { key: "pass", label: "PASS LINE", sub: "1:1", color: Neon.green },
                { key: "dontpass", label: "DON'T PASS", sub: "1:1 · 12 PUSHES", color: Neon.red },
                { key: "odds", label: "ODDS", sub: "TRUE ODDS · ≤3× PASS", color: Neon.yellow },
                { key: "field", label: "FIELD", sub: "2,3,4,9,10,11,12 · 1:1\n2 PAYS 2:1 · 12 PAYS 3:1", color: Neon.cyan },
                { key: "any7", label: "ANY 7", sub: "4:1 · ONE ROLL", color: Neon.pink },
                { key: "anycraps", label: "ANY CRAPS", sub: "2,3,12 · 7:1", color: Neon.violet }
            ]
            MouseArea {
                width: layout.w; height: Theme.itemSizeMedium * 1.1
                readonly property real riding: page.st.table[modelData.key] || 0
                readonly property real added: page.fresh[modelData.key] || 0
                onClicked: page.place(modelData.key)
                onPressAndHold: page.clearFresh(modelData.key)
                Rectangle {
                    anchors.fill: parent; radius: 6
                    color: Neon.alpha(modelData.color, parent.pressed ? 0.45 : (parent.riding + parent.added > 0 ? 0.28 : 0.1))
                    border { width: 2; color: Neon.alpha(modelData.color, 0.85) }
                }
                Column {
                    anchors { left: parent.left; leftMargin: Theme.paddingMedium; right: parent.right; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.label; color: "white"; font { pixelSize: Theme.fontSizeSmall; bold: true; family: Neon.display } }
                    Text {
                        width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                        text: modelData.sub; color: Neon.alpha(modelData.color, 0.9)
                        font { pixelSize: Theme.fontSizeTiny * 0.9; family: Neon.mono }
                    }
                }
                Rectangle {
                    visible: parent.riding + parent.added > 0
                    anchors { right: parent.right; top: parent.top; margins: 4 }
                    height: Theme.iconSizeSmall; width: Math.max(height, ct.implicitWidth + 10); radius: height / 2
                    color: parent.added > 0 ? Neon.yellow : Neon.green
                    Text { id: ct; anchors.centerIn: parent; text: page.chipLabel(parent.parent.riding + parent.parent.added); color: Neon.ink; font { pixelSize: Theme.fontSizeTiny; bold: true } }
                }
            }
        }
    }
    Label {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        wrapMode: Text.Wrap
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.secondaryColor
        text: "Pass wins on a first-roll 7 or 11 and loses on 2, 3 or 12; anything else sets the point, then Pass needs "
              + "the point again before a 7. Odds pay 2:1 on 4/10, 3:2 on 5/9, 6:5 on 6/8. Yellow chips are new, green ones ride."
    }
    function chipLabel(v) {
        if (v >= 1e9) return +(v / 1e9).toFixed(1) + "B"
        if (v >= 1e6) return +(v / 1e6).toFixed(1) + "M"
        if (v >= 1e3) return +(v / 1e3).toFixed(1) + "K"
        return String(v)
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingMedium
            Repeater {
                model: page.chipValues
                MouseArea {
                    width: Theme.itemSizeSmall; height: width
                    onClicked: { page.chipIndex = index; Sound.play("click"); Haptics.tick() }
                    Image { anchors.fill: parent; source: "../images/sym-chip.png"; opacity: index === page.chipIndex ? 1 : 0.45; scale: index === page.chipIndex ? 1.1 : 0.9 }
                    Text { anchors.centerIn: parent; text: page.chipLabel(modelData); color: "white"; font { pixelSize: Theme.fontSizeExtraSmall; bold: true; family: Neon.display } }
                }
            }
        }
        NeonButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            height: Theme.itemSizeMedium
            text: page.rolling ? "Rolling…" : "Roll" + (page.freshTotal > 0 ? " · " + Money.fmt(page.freshTotal) + " new" : "")
            color: Neon.green; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: !page.rolling && (page.freshTotal > 0 || Game.crapsOnTable > 0)
            onClicked: page.throwDice(0.5)
        }
    }
}
