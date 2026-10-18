import QtQuick 2.6
import QtSensors 5.2
import Sailfish.Silica 1.0
import "../components"
import "../js/SicBo.js" as SicBo
import "../js/Money.js" as Money

// Sic Bo: three dice. Place chips, then flick the dice, shake the phone, or tap Roll.
// The roll is decided and saved before the dice land.
TablePage {
    id: page
    title: "Sic bo"
    accent: "#FF9F14"
    scene: "velvet"
    musicTrack: "sicbo"
    code: "3 DICE · SMALL / BIG 1:1 · TRIPLES 30:1"
    footerHeight: footerCol.height + Theme.paddingLarge

    property var bets: ({})
    property var lastBets: ({})
    property var dice: [2, 4, 6]
    property var target: [1, 1, 1]
    property bool rolling: false
    property var history: []
    property int chipIndex: 0
    readonly property real total: sum(bets)
    busy: rolling

    readonly property var chipValues: {
        var b = Game.balance, out = [], fr = [0.01, 0.05, 0.2, 0.5]
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
    function chipLabel(v) {
        if (v >= 1e9) return +(v / 1e9).toFixed(1) + "B"
        if (v >= 1e6) return +(v / 1e6).toFixed(1) + "M"
        if (v >= 1e3) return +(v / 1e3).toFixed(1) + "K"
        return String(v)
    }
    function place(key) {
        if (rolling) return
        if (total + chip > Game.balance + 1e-9) { Game.note("NOT ENOUGH CREDITS", Neon.red); return }
        var b = {}; for (var k in bets) b[k] = bets[k]
        b[key] = (b[key] || 0) + chip
        bets = b
        Sound.play("tick"); Haptics.tick()
    }
    function clearSpot(key) { if (rolling || !bets[key]) return; var b = {}; for (var k in bets) if (k !== key) b[k] = bets[k]; bets = b }
    function roll(power) {
        if (rolling || total < Game.minBet || !Game.canBet(Game.minBet) || total > Game.balance + 1e-9) return
        lastBets = bets
        Game.stake(total)
        var d = SicBo.roll(), returned = 0
        for (var k in bets) returned += SicBo.payout(k, bets[k], d)
        Game.pending = { game: "sicbo", staked: total, returned: Math.round(returned * 100) / 100 }
        Game.save()
        target = d
        rolling = true
        throwAnim.duration = 700 + 500 * (power === undefined ? 0.5 : power)
        Sound.play("card"); Haptics.tap()
        tumble.start(); throwAnim.restart()
    }
    Timer { id: tumble; interval: 70; repeat: true; onTriggered: page.dice = SicBo.roll() }
    function landed() {
        tumble.stop()
        dice = target
        rolling = false
        var p = Game.pending, t = dice[0] + dice[1] + dice[2]
        history = [t].concat(history).slice(0, 14)
        Game.note(t + (dice[0] === dice[1] && dice[1] === dice[2] ? " · TRIPLE" : t <= 10 ? " · SMALL" : " · BIG"), "#FF9F14")
        if (p.returned > p.staked) page.burst.show(p.returned - p.staked, p.returned >= p.staked * 8)
        else if (p.returned < p.staked) Sound.play("lose")
        Haptics.tap()
        bets = ({})
        Game.settle(p.staked, p.returned, "sicbo")
    }
    Accelerometer {
        active: Qt.application.active && page.status === PageStatus.Active && !page.rolling
        property real last: 0
        onReadingChanged: {
            var r = reading, g = Math.sqrt(r.x * r.x + r.y * r.y + r.z * r.z), now = Date.now()
            if (Math.abs(g - 9.81) > 9 && now - last > 1500) { last = now; page.roll(Math.min(1, (Math.abs(g - 9.81) - 9) / 10)) }
        }
    }

    // ---- dice tray ----
    NeonPanel {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeExtraLarge * 1.1
        glowColor: "#FF9F14"
        Item {
            id: tray
            anchors { fill: parent; margins: Theme.paddingMedium }
            clip: true
            Row {
                id: diceRow
                spacing: Theme.paddingLarge
                x: (tray.width - width) / 2; y: (tray.height - height) / 2
                Repeater {
                    model: 3
                    Die {
                        width: Theme.itemSizeMedium * 0.8
                        face: page.dice[index]
                        ink: index === 0 ? Neon.red : index === 1 ? "#FF9F14" : Neon.yellow
                    }
                }
            }
            NumberAnimation {
                id: throwAnim
                target: diceRow; property: "x"
                from: tray.width; to: (tray.width - diceRow.width) / 2
                easing.type: Easing.OutBounce
                onStopped: page.landed()
            }
            NeonText {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                visible: !page.rolling && page.history.length > 0
                text: page.history.length ? String(page.history[0]) : ""
                color: Neon.yellow; font.pixelSize: Theme.fontSizeExtraLarge
            }
            MouseArea {
                anchors.fill: parent
                property real x0; property real y0; property real t0
                onPressed: { x0 = mouse.x; y0 = mouse.y; t0 = Date.now() }
                onReleased: {
                    var dx = mouse.x - x0, dy = mouse.y - y0, dist = Math.sqrt(dx * dx + dy * dy)
                    if (dist > Theme.itemSizeSmall) page.roll(Math.min(1, dist / Math.max(1, Date.now() - t0) / 3))
                }
            }
        }
    }

    // ---- the board ----
    Column {
        id: boardCol
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        spacing: 3
        Row {
            spacing: 3
            Repeater {
                model: [{ key: "small", label: "SMALL", sub: "4-10 · 1:1" }, { key: "triple", label: "ANY TRIPLE", sub: "30:1" }, { key: "big", label: "BIG", sub: "11-17 · 1:1" }]
                SpotCell { width: (boardCol.width - 6) / 3; height: Theme.itemSizeSmall; key: modelData.key; label: modelData.label; sub: modelData.sub; tint: "#FF9F14" }
            }
        }
        Grid {
            columns: 7; spacing: 3
            Repeater {
                model: 14
                SpotCell {
                    width: (boardCol.width - 18) / 7; height: Theme.itemSizeSmall * 0.9
                    key: "t:" + (index + 4); label: String(index + 4); sub: SicBo.totalPays[index + 4] + ":1"; tint: Neon.red
                }
            }
        }
        Row {
            spacing: 3
            Repeater {
                model: 6
                SpotCell {
                    width: (boardCol.width - 15) / 6; height: Theme.itemSizeSmall
                    key: "n:" + (index + 1); label: ""; sub: "1:1 EACH"; tint: Neon.yellow
                    Die { anchors.centerIn: parent; anchors.verticalCenterOffset: -Theme.paddingSmall; width: parent.height * 0.5; face: index + 1; ink: Neon.yellow }
                }
            }
        }
        Row {
            spacing: Theme.paddingSmall
            Text { text: "ROLLS"; color: Neon.alpha("#FF9F14", 0.7); font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 2 } }
            Repeater {
                model: page.history
                Text { text: modelData; color: modelData <= 10 ? Neon.cyan : Neon.pink; font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall } }
            }
        }
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
                    Text { anchors.centerIn: parent; text: page.chipLabel(modelData); color: "white"; font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall; bold: true } }
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            height: Theme.itemSizeMedium
            property real w: (page.width - 2 * Theme.horizontalPageMargin - 2 * spacing) / 4
            NeonButton { width: parent.w; height: parent.height; text: "Clear"; color: Neon.violet; fontSize: Theme.fontSizeSmall; enabled: !page.rolling && page.total > 0; onClicked: page.bets = ({}) }
            NeonButton {
                width: parent.w; height: parent.height; text: "Rebet"; color: Neon.cyan; fontSize: Theme.fontSizeSmall
                enabled: !page.rolling && page.sum(page.lastBets) > 0 && page.sum(page.lastBets) <= Game.balance
                onClicked: page.bets = page.lastBets
            }
            NeonButton {
                width: parent.w * 2; height: parent.height
                text: page.rolling ? "Rolling…" : "Roll " + Money.fmt(page.total)
                color: "#FF9F14"; primary: true
                enabled: !page.rolling && page.total >= Game.minBet && page.total <= Game.balance + 1e-9
                onClicked: page.roll(0.5)
            }
        }
    }
}
