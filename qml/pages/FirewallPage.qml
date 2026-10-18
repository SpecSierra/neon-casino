import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// FIREWALL: the other REBOOT game. Firewalls fall toward your packet; drag left and right to
// slip through the gaps. Same rules as the drone: clear Game.rebootGates walls to keep the run,
// then every further wall pays more. One attempt, spent at launch; crash short and the run ends.
// Tuned with a simulated player: careful ~100%, sloppy ~32% on 8 walls (the drone is ~66%).
Page {
    id: page
    objectName: "reboot"
    backNavigation: false

    property string phase: "ready"          // ready | flying | won (crashed after the minimum) | crashed
    property int target: Game.rebootGates
    property bool rebooted: false
    property real bonusTotal: 0
    property int passed: 0
    // field units: x runs 0..1 across, y 0..fieldH down
    readonly property real fieldH: field.height / Math.max(1, field.width)
    readonly property real shipY: 0.82 * fieldH
    readonly property real shipW: 0.085
    readonly property real maxV: 2.2                 // widths per second the packet can slide
    readonly property real wallT: 0.05
    property real sx: 0.5
    property real aim: 0.5
    property real lastGap: 0.5
    property var walls: []                            // [{ y, gap (centre), size, scored }]
    property real nextIn: 0.6
    property double lastTick: 0

    Backdrop { accent: Neon.cyan; scene: "circuit" }
    onStatusChanged: if (status === PageStatus.Active) Music.track = "reboot"

    function start() {
        if (phase !== "ready") return
        if (!Game.startReboot()) { phase = "crashed"; return }
        target = Game.rebootGates
        phase = "flying"
        rebooted = false; bonusTotal = 0; passed = 0; walls = []; nextIn = 0.6; lastGap = 0.5
        lastTick = Date.now()
        loop.start()
        Haptics.tap(); Sound.play("reel")
    }
    function crash() {
        loop.stop()
        phase = rebooted ? "won" : "crashed"
        Sound.play(rebooted ? "bigwin" : "bust"); Haptics.rumble(4)
        flash.restart()
    }
    function wallCleared() {
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
            var d = page.aim - page.sx, step = page.maxV * dt
            page.sx = Math.max(page.shipW / 2, Math.min(1 - page.shipW / 2, page.sx + Math.max(-step, Math.min(step, d))))
            var speed = (0.60 + Math.min(0.45, page.passed * 0.03)) * page.fieldH
            var w = [], i
            for (i = 0; i < page.walls.length; ++i) {
                var q = page.walls[i]
                w.push({ y: q.y + speed * dt, gap: q.gap, size: q.size, scored: q.scored })
            }
            page.nextIn -= dt
            if (page.nextIn <= 0) {
                var size = Math.max(0.19, 0.28 - 0.008 * page.passed)
                var lo = Math.max(size / 2 + 0.03, page.lastGap - 0.40), hi = Math.min(1 - size / 2 - 0.03, page.lastGap + 0.40)
                var gap = lo + Math.random() * (hi - lo)
                page.lastGap = gap
                w.push({ y: -page.wallT, gap: gap, size: size, scored: false })
                page.nextIn = Math.max(0.48, 0.75 - page.passed * 0.02)
            }
            var half = page.shipW / 2 * 0.8
            for (i = 0; i < w.length; ++i) {
                var r = w[i]
                if (!r.scored && r.y + page.wallT >= page.shipY - 0.03 && r.y <= page.shipY + 0.03
                        && (page.sx - half < r.gap - r.size / 2 || page.sx + half > r.gap + r.size / 2)) {
                    page.walls = w; page.crash(); return
                }
                if (!r.scored && r.y > page.shipY + 0.03) {
                    r.scored = true
                    page.passed += 1
                    page.wallCleared()
                }
            }
            page.walls = w.filter(function (r) { return r.y < page.fieldH + 0.1 })
        }
    }

    Column {
        id: top
        width: parent.width
        NeonHeader {
            title: "Firewall"
            code: page.rebooted ? "OVERTIME · NEXT WALL +" + Money.fmt(Game.rebootBonusFor(page.passed - page.target + 1))
                                : "SLIP " + page.target + " WALLS TO KEEP THE RUN · THEN EVERY WALL PAYS MORE"
            color: Neon.cyan
        }
        Item {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            height: Theme.itemSizeSmall
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: page.rebooted ? "+" + Money.fmt(Game.rebootAmount + page.bonusTotal) : "WALLS " + page.passed + " / " + page.target
                color: page.rebooted ? Neon.green : Neon.cyan
                font { family: Neon.mono; pixelSize: Theme.fontSizeLarge }
            }
            Text {
                visible: page.rebooted
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "WALL " + page.passed
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
                        color: index < page.passed ? Neon.cyan : Neon.alpha(Neon.cyan, 0.15)
                    }
                }
            }
        }
    }

    NeonPanel {
        id: frame
        anchors { left: parent.left; right: parent.right; top: top.bottom; bottom: parent.bottom; margins: Theme.horizontalPageMargin }
        glowColor: page.phase === "crashed" ? Neon.red : page.phase === "won" ? Neon.green : Neon.cyan
        glowStrength: 0.5
        strong: true
        Item {
            id: field
            anchors { fill: parent; margins: Theme.paddingMedium }
            clip: true
            readonly property real u: width            // one field unit in pixels
            Repeater {
                model: page.walls
                Item {
                    id: wallItem
                    readonly property var wall: modelData
                    y: wall.y * field.u; width: field.width; height: page.wallT * field.u
                    Repeater {
                        model: 2
                        Rectangle {
                            height: parent.height
                            x: index === 0 ? 0 : (wallItem.wall.gap + wallItem.wall.size / 2) * field.u
                            width: index === 0 ? (wallItem.wall.gap - wallItem.wall.size / 2) * field.u : field.width - x
                            color: Neon.alpha(Neon.red, 0.25)
                            border { width: 2; color: Neon.red }
                        }
                    }
                }
            }
            // the packet
            Rectangle {
                width: page.shipW * field.u; height: width * 0.6
                x: page.sx * field.u - width / 2; y: page.shipY * field.u - height / 2
                radius: 4
                color: Neon.alpha(Neon.cyan, 0.35)
                border { width: 3; color: Neon.cyan }
                Rectangle { anchors.centerIn: parent; width: parent.width * 0.35; height: width; radius: width / 2; color: "white" }
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
            Column {
                anchors.centerIn: parent
                width: parent.width * 0.85
                spacing: Theme.paddingMedium
                visible: page.phase !== "flying"
                NeonText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.phase === "ready" ? "TOUCH TO START" : page.phase === "won" ? "SYSTEM REBOOTED" : "BLOCKED"
                    color: page.phase === "crashed" ? Neon.red : page.phase === "won" ? Neon.green : Neon.cyan
                    font.pixelSize: Theme.fontSizeExtraLarge
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: page.phase === "ready" ? "Drag left and right to slip your packet through the gaps. Clear " + page.target + " walls to keep your run, then every wall pays more. One try: crash short and the run is over."
                          : page.phase === "won" ? page.passed + " walls. +" + Money.fmt(Game.rebootAmount + page.bonusTotal) + " in total. Your run goes on."
                          : "Wall " + page.passed + " of " + page.target + ". The run is over."
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
        MouseArea {           // touch starts it; dragging steers (the packet chases your finger)
            anchors.fill: parent
            enabled: page.phase === "ready" || page.phase === "flying"
            preventStealing: true
            onPressed: { if (page.phase === "ready") page.start(); page.aim = (mouse.x - field.x) / field.width }
            onPositionChanged: page.aim = (mouse.x - field.x) / field.width
        }
    }
}
