import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// REBOOT: a one-shot, endless Flappy-style run you get when you go broke. Tap to boost the drone
// through the gaps in the laser gates. Clear Game.rebootGates of them to get credits back and keep
// the run; then keep flying: every further gate pays more than the last, until you crash.
// Fall short of the minimum and the run is over. The attempt is spent when the run starts.
Page {
    id: page
    objectName: "reboot"
    // no way out until the run is played: crashed or won, then the button decides
    backNavigation: false

    property string phase: "ready"          // ready | flying | won (crashed after the minimum) | crashed
    property bool rebooted: false            // the minimum is cleared: the run lives, overtime pays
    property real bonusTotal: 0
    property int target: Game.rebootGates     // frozen at launch: a successful reboot raises Game.rebootGates
    property int passed: 0
    // physics in field units: the field is 1.0 tall, x runs in the same units
    property real py: 0.45
    property real vy: 0
    // tuned with a simulated player: a careful one clears every run, a sloppy one about 2 in 3
    readonly property real gravity: 2.0
    readonly property real flap: -0.72
    readonly property real px: 0.28 * field.width / field.height
    readonly property real radius: 0.028
    readonly property real hitRadius: radius * 0.8          // a little forgiving
    readonly property real gateW: 0.07
    property real lastGap: 0.5
    property var gates: []                   // [{ x, gap (centre), size, scored }]
    property real speed: 0.42
    property real nextGateIn: 0.4
    property double lastTick: 0

    Backdrop { accent: Neon.yellow; scene: "circuit" }
    onStatusChanged: if (status === PageStatus.Active) Music.track = "reboot"

    function start() {
        if (phase !== "ready") return
        if (!Game.startReboot()) { phase = "crashed"; return }
        target = Game.rebootGates
        phase = "flying"
        rebooted = false; bonusTotal = 0
        py = 0.45; vy = flap; passed = 0; gates = []; nextGateIn = 0.4; speed = 0.36; lastGap = 0.5
        lastTick = Date.now()
        loop.start()
        Haptics.tap(); Sound.play("reel")
    }
    function boost() {
        if (phase === "ready") { start(); return }
        if (phase !== "flying") return
        vy = flap
        Sound.play("tick"); Haptics.tick()
    }
    function crash() {
        loop.stop()
        phase = rebooted ? "won" : "crashed"
        Sound.play(rebooted ? "bigwin" : "bust"); Haptics.rumble(4)
        flash.restart()
    }
    function gateCleared() {
        if (passed === target) {
            rebooted = true
            Game.rebootWon()
            Sound.play("bigwin"); Haptics.rumble(6)
            overtimeFlash.restart()
        } else if (passed > target) {
            bonusTotal += Game.rebootGate(passed - target)
            Sound.play("win"); Haptics.tap()
        } else {
            Sound.play("win"); Haptics.tap()
        }
    }
    Timer {
        id: loop
        interval: 16; repeat: true
        onTriggered: {
            var now = Date.now(), dt = Math.min(0.05, (now - page.lastTick) / 1000)
            page.lastTick = now
            page.vy += page.gravity * dt
            page.py += page.vy * dt
            if (page.py < page.hitRadius || page.py > 1 - page.hitRadius) { page.crash(); return }
            var w = field.width / field.height, gw = page.gateW, hr = page.hitRadius
            var g = page.gates.slice(), i
            for (i = 0; i < g.length; ++i) g[i] = { x: g[i].x - page.speed * dt, gap: g[i].gap, size: g[i].size, scored: g[i].scored }
            g = g.filter(function (q) { return q.x > -gw })
            page.nextGateIn -= dt
            if (page.nextGateIn <= 0) {
                // gaps shrink as you go
                // gaps shrink slowly; the next gap is never more than 0.25 away from the last
                var size = Math.max(0.27, 0.40 - 0.005 * page.passed)
                var lo = Math.max(size / 2 + 0.06, page.lastGap - 0.25), hi = Math.min(1 - size / 2 - 0.06, page.lastGap + 0.25)
                var gap = lo + Math.random() * (hi - lo)
                page.lastGap = gap
                g.push({ x: w + gw, gap: gap, size: size, scored: false })
                page.nextGateIn = 1.7 - Math.min(0.3, page.passed * 0.015)
                page.speed = 0.36 + Math.min(0.18, page.passed * 0.008)
            }
            for (i = 0; i < g.length; ++i) {
                var q = g[i]
                var inX = page.px + hr > q.x && page.px - hr < q.x + gw
                if (inX && (page.py - hr < q.gap - q.size / 2 || page.py + hr > q.gap + q.size / 2)) {
                    page.gates = g; page.crash(); return
                }
                if (!q.scored && q.x + gw < page.px - hr) {
                    q.scored = true
                    page.passed += 1
                    page.gateCleared()
                }
            }
            page.gates = g
        }
    }

    Column {
        id: top
        width: parent.width
        NeonHeader {
            title: "Reboot"
            code: page.rebooted ? "OVERTIME · NEXT GATE +" + Money.fmt(Game.rebootBonusFor(page.passed - page.target + 1))
                                : "CLEAR " + page.target + " TO KEEP THE RUN · THEN EVERY GATE PAYS MORE"
            color: Neon.yellow
        }
        Item {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            height: Theme.itemSizeSmall
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: page.rebooted ? "+" + Money.fmt(Game.rebootAmount + page.bonusTotal) : "GATES " + page.passed + " / " + page.target
                color: page.rebooted ? Neon.green : Neon.yellow
                font { family: Neon.mono; pixelSize: Theme.fontSizeLarge }
            }
            Text {
                visible: page.rebooted
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "GATE " + page.passed
                color: Neon.yellow
                font { family: Neon.mono; pixelSize: Theme.fontSizeLarge }
            }
            Row {
                visible: !page.rebooted
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 3
                Repeater {
                    model: page.target
                    Rectangle {
                        width: Math.max(4, (top.width * 0.42) / page.target - 3); height: Theme.paddingLarge
                        color: index < page.passed ? Neon.yellow : Neon.alpha(Neon.yellow, 0.15)
                    }
                }
            }
        }
    }

    // ---- play field ----
    NeonPanel {
        id: frame
        anchors { left: parent.left; right: parent.right; top: top.bottom; bottom: parent.bottom; margins: Theme.horizontalPageMargin }
        glowColor: page.phase === "crashed" ? Neon.red : page.phase === "won" ? Neon.green : Neon.yellow
        glowStrength: 0.5
        strong: true
        Item {
            id: field
            anchors { fill: parent; margins: Theme.paddingMedium }
            clip: true
            readonly property real u: height           // one field unit in pixels
            // the laser gates
            Repeater {
                model: page.gates
                Item {
                    id: gateItem
                    readonly property var gate: modelData        // the inner Repeater has its own modelData
                    x: gate.x * field.u; width: page.gateW * field.u; height: field.height
                    Repeater {
                        model: 2
                        Rectangle {
                            width: parent.width
                            y: index === 0 ? 0 : (gateItem.gate.gap + gateItem.gate.size / 2) * field.u
                            height: index === 0 ? (gateItem.gate.gap - gateItem.gate.size / 2) * field.u : field.height - y
                            color: Neon.alpha(Neon.red, 0.18)
                            border { width: 2; color: Neon.red }
                            Rectangle {      // the beam
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 3; height: parent.height
                                color: Neon.red
                                opacity: 0.8
                            }
                        }
                    }
                }
            }
            // the drone
            Item {
                id: drone
                width: page.radius * 2 * field.u; height: width
                x: page.px * field.u - width / 2; y: page.py * field.u - height / 2
                rotation: Math.max(-30, Math.min(60, page.vy * 45))
                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    color: Neon.alpha(Neon.cyan, 0.3)
                    border { width: 3; color: Neon.cyan }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.4; height: width; radius: width / 2
                    color: "white"
                }
                Rectangle {        // thruster
                    anchors { right: parent.left; verticalCenter: parent.verticalCenter }
                    width: parent.width * (page.vy < 0 ? 0.9 : 0.4); height: 4
                    color: Neon.yellow
                    opacity: page.phase === "flying" ? 0.9 : 0
                }
            }
            NeonText {
                id: overtime
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.paddingLarge }
                text: "RUN SAVED · OVERTIME"
                color: Neon.green; font.pixelSize: Theme.fontSizeLarge
                opacity: 0
                SequentialAnimation {
                    id: overtimeFlash
                    NumberAnimation { target: overtime; property: "opacity"; to: 1; duration: 150 }
                    PauseAnimation { duration: 1400 }
                    NumberAnimation { target: overtime; property: "opacity"; to: 0; duration: 500 }
                }
            }
            Rectangle {
                id: flashRect
                anchors.fill: parent; color: Neon.red; opacity: 0
                NumberAnimation { id: flash; target: flashRect; property: "opacity"; from: 0.6; to: 0; duration: 600 }
            }
            // overlays
            Column {
                anchors.centerIn: parent
                width: parent.width * 0.85
                spacing: Theme.paddingMedium
                visible: page.phase !== "flying"
                NeonText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.phase === "ready" ? "TAP TO LAUNCH" : page.phase === "won" ? "SYSTEM REBOOTED" : "CRASHED"
                    color: page.phase === "crashed" ? Neon.red : page.phase === "won" ? Neon.green : Neon.yellow
                    font.pixelSize: Theme.fontSizeExtraLarge
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: page.phase === "ready" ? "Tap anywhere to boost. Clear " + page.target + " laser gates to keep your run, then fly on: every gate after that pays more. One try."
                          : page.phase === "won" ? page.passed + " gates. +" + Money.fmt(Game.rebootAmount + page.bonusTotal) + " in total. Your run goes on."
                          : "Gate " + page.passed + " of " + page.target + ". The run is over."
                    color: "white"
                    font { family: Neon.mono; pixelSize: Theme.fontSizeSmall }
                }
                NeonButton {
                    visible: page.phase === "won" || page.phase === "crashed"
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.8
                    text: page.phase === "won" ? "Play on" : "New run…"
                    color: page.phase === "won" ? Neon.green : Neon.red
                    primary: true
                    onClicked: {
                        if (page.phase === "won") pageStack.pop(pageStack.find(function (p) { return p.objectName === "hub" }))
                        else pageStack.replace(Qt.resolvedUrl("NewRunPage.qml"))
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: page.phase === "ready" || page.phase === "flying"
            onPressed: page.boost()
        }
    }
}
