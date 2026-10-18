import QtQuick 2.6
import QtQuick.Particles 2.0
import "."

// Page backdrop: a translucent violet wash, hex mesh and scanlines over the ambience
// wallpaper, plus an animated scene per game / slot machine:
// lobby | classic | hacker | tokyo | sunset | cascade | felt | velvet | circuit | void | arcade | abyss
Item {
    id: root
    anchors.fill: parent
    property color accent: Neon.pink
    property string scene: "lobby"
    // light mode (slow phones, or chosen in Settings): the scenes hold still
    readonly property bool animate: Qt.application.active && visible && !Game.lowFx

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.0, 0.08, 0.55) }
            GradientStop { position: 0.6; color: Qt.rgba(0.05, 0.0, 0.12, 0.45) }
            GradientStop { position: 1.0; color: Qt.rgba(0.12, 0.0, 0.18, 0.60) }
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: ({ classic: cityScene, hacker: matrixScene, tokyo: tokyoScene, sunset: sunsetScene,
                            cascade: gemScene, felt: feltScene, poker: feltScene, baccarat: feltScene,
                            velvet: velvetScene, circuit: circuitScene,
                            ways: neuralScene, heist: laserScene, keno: ballScene,
                            void: voidScene, arcade: arcadeScene, abyss: abyssScene })[root.scene] || gridScene
    }

    Image { anchors.fill: parent; source: "../images/scan.png"; fillMode: Image.Tile; opacity: 0.18; smooth: false }

    // ---------------------------------------------------------------- scenes
    // synthwave horizon grid (lobby and fallback)
    Component {
        id: gridScene
        Item {
            HorizonGrid { color: root.accent; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: parent.height * 0.28 }
        }
    }
    // NEON SLOTS: night skyline with lit windows and two sweeping searchlights
    Component {
        id: cityScene
        Item {
            Repeater {
                model: 2
                Rectangle {
                    width: root.width * 0.18; height: root.height * 0.9
                    x: root.width * (0.25 + 0.5 * index); y: root.height * 0.35
                    transformOrigin: Item.Bottom
                    opacity: 0.12
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: index ? Neon.cyan : Neon.pink }
                    }
                    RotationAnimation on rotation {
                        running: root.animate; loops: Animation.Infinite
                        from: index ? 25 : -25; to: index ? -25 : 25; duration: 7000 + index * 1500
                        easing.type: Easing.InOutSine
                    }
                }
            }
            Canvas {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height * 0.32
                opacity: 0.55
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    var seed = 7
                    function rnd() { seed = (seed * 9301 + 49297) % 233280; return seed / 233280 }
                    var x = 0
                    while (x < width) {
                        var w = width * (0.06 + rnd() * 0.08), h = height * (0.35 + rnd() * 0.6)
                        ctx.fillStyle = "rgba(10,4,26,0.95)"
                        ctx.fillRect(x, height - h, w - 3, h)
                        ctx.strokeStyle = rnd() < 0.5 ? "rgba(255,43,214,0.6)" : "rgba(0,240,255,0.6)"
                        ctx.lineWidth = 2; ctx.strokeRect(x, height - h, w - 3, h)
                        for (var wy = height - h + 8; wy < height - 6; wy += 12)
                            for (var wx = x + 5; wx < x + w - 10; wx += 9)
                                if (rnd() < 0.35) { ctx.fillStyle = rnd() < 0.5 ? "rgba(248,255,58,0.7)" : "rgba(0,240,255,0.6)"; ctx.fillRect(wx, wy, 4, 5) }
                        x += w
                    }
                }
            }
        }
    }
    // HACKER GRID: matrix code rain
    Component {
        id: matrixScene
        Item {
            id: rain
            clip: true
            Repeater {
                model: 14
                Text {
                    id: colText
                    x: rain.width * index / 14 + (index % 3) * 4
                    width: rain.width / 14
                    font { family: "monospace"; pixelSize: rain.width / 22; bold: true }
                    lineHeight: 0.9
                    color: Neon.green
                    opacity: 0.18 + (index % 4) * 0.06
                    property int len: 10 + (index * 7) % 12
                    function glyphs() {
                        var s = "", set = "01アイウエオカキクケコ#$%{}<>/=+*ABCDEF"
                        for (var i = 0; i < len; ++i) s += set.charAt(Math.floor(Math.random() * set.length)) + "\n"
                        return s
                    }
                    text: glyphs()
                    NumberAnimation on y {
                        running: root.animate; loops: Animation.Infinite
                        from: -colText.height; to: rain.height
                        duration: 5000 + (index * 1373) % 6000
                    }
                    Timer { running: root.animate; repeat: true; interval: 700 + index * 37; onTriggered: colText.text = colText.glyphs() }
                }
            }
        }
    }
    // NEO TOKYO: striped rising sun, pagoda skyline, falling sakura petals
    Component {
        id: tokyoScene
        Item {
            Canvas {
                width: parent.width * 0.9; height: width
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.height * 0.08 }
                opacity: 0.35
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    var r = width / 2
                    var g = ctx.createLinearGradient(0, 0, 0, height)
                    g.addColorStop(0, "#FF3355"); g.addColorStop(1, "#FF9F14")
                    ctx.fillStyle = g
                    ctx.beginPath(); ctx.arc(r, r, r, 0, Math.PI * 2); ctx.fill()
                    ctx.globalCompositeOperation = "destination-out"
                    for (var i = 0; i < 7; ++i) ctx.fillRect(0, r + i * r / 7 + i * 3, width, 4 + i * 2)
                }
            }
            Canvas {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height * 0.22
                opacity: 0.6
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    ctx.fillStyle = "rgba(14,4,20,0.95)"
                    ctx.beginPath(); ctx.moveTo(0, height)
                    for (var x = 0; x <= width; x += width / 12) ctx.lineTo(x, height * (0.45 + 0.25 * Math.sin(x * 0.02)))
                    ctx.lineTo(width, height); ctx.fill()
                    // pagoda
                    var px = width * 0.7, base = height * 0.5
                    for (var t = 0; t < 4; ++t) {
                        var w = width * (0.16 - t * 0.03), y = base - t * height * 0.11
                        ctx.fillRect(px - w / 2, y - height * 0.03, w, height * 0.03)
                        ctx.fillRect(px - w * 0.3, y, w * 0.6, height * 0.08)
                    }
                    ctx.fillStyle = "rgba(255,51,85,0.8)"
                    ctx.fillRect(px - 2, base - 4 * height * 0.11 - height * 0.08, 4, height * 0.08)
                }
            }
            ParticleSystem { id: petals; running: root.animate }
            ImageParticle { system: petals; source: "../images/petal.png"; rotationVariation: 180; rotationVelocityVariation: 90; alpha: 0.7; colorVariation: 0.1 }
            Emitter {
                system: petals
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1
                emitRate: 3; lifeSpan: 9000
                size: 22; sizeVariation: 10
                velocity: PointDirection { x: 25; xVariation: 30; y: 70; yVariation: 30 }
                acceleration: PointDirection { x: -4; xVariation: 8 }
            }
        }
    }
    // SUNSET DRIVE: outrun sun, palms, rolling grid
    Component {
        id: sunsetScene
        Item {
            Canvas {
                width: parent.width * 0.8; height: width / 2
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.height * 0.28 }
                opacity: 0.5
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    var r = width / 2
                    var g = ctx.createLinearGradient(0, 0, 0, height)
                    g.addColorStop(0, "#FFE14A"); g.addColorStop(1, "#FF2BD6")
                    ctx.fillStyle = g
                    ctx.beginPath(); ctx.arc(r, height, r, Math.PI, 0); ctx.fill()
                    ctx.globalCompositeOperation = "destination-out"
                    for (var i = 0; i < 6; ++i) ctx.fillRect(0, height * (0.45 + i * 0.1), width, 3 + i * 2)
                }
            }
            Repeater {
                model: [[0.04, 0.42], [0.8, 0.36]]
                Image {
                    source: "../images/sym-sunset-palm.png"
                    width: root.width * modelData[1]; height: width
                    x: root.width * modelData[0]; y: root.height * 0.72 - height
                    opacity: 0.3
                    mirror: index === 1
                }
            }
            HorizonGrid { color: "#FF9F14"; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: parent.height * 0.28 }
        }
    }
    // VOID RUNNER: warp-speed starfield streaming from the centre, a ringed planet far off
    Component {
        id: voidScene
        Item {
            Image {
                source: "../images/sym-void-ring.png"
                width: root.width * 0.7; height: width
                x: root.width * 0.45; y: root.height * 0.08
                opacity: 0.22
                RotationAnimation on rotation { from: -8; to: 8; duration: 18000; loops: Animation.Infinite; running: root.animate; easing.type: Easing.InOutSine }
            }
            ParticleSystem { id: stars; running: root.animate }
            ImageParticle { system: stars; source: "../images/spark.png"; color: "#B9B2FF"; colorVariation: 0.3; alpha: 0.6 }
            Emitter {
                system: stars
                x: root.width / 2; y: root.height * 0.4; width: 2; height: 2
                emitRate: 26; lifeSpan: 3200
                size: 4; endSize: 22; sizeVariation: 3
                velocity: AngleDirection { angleVariation: 180; magnitude: 90; magnitudeVariation: 60 }
                acceleration: AngleDirection { angleVariation: 180; magnitude: 160 }
            }
        }
    }
    // PIXEL ARCADE: a dim pixel grid with sprites marching across, like an attract screen
    Component {
        id: arcadeScene
        Item {
            Grid {
                anchors.fill: parent
                columns: Math.ceil(root.width / 24)
                opacity: 0.08
                Repeater {
                    model: Math.ceil(root.width / 24) * Math.ceil(root.height / 24)
                    Rectangle { width: 24; height: 24; color: "transparent"; border { width: 1; color: "#39FFD2" } }
                }
            }
            Repeater {
                model: [["invader", 0.12, 26000], ["ghost", 0.34, 21000], ["mushroom", 0.58, 30000], ["coin", 0.8, 17000]]
                Image {
                    source: "../images/sym-arcade-" + modelData[0] + ".png"
                    width: root.width * 0.2; height: width
                    y: root.height * modelData[1]
                    opacity: 0.22
                    smooth: false
                    NumberAnimation on x {
                        from: index % 2 ? root.width : -root.width * 0.2; to: index % 2 ? -root.width * 0.2 : root.width
                        duration: modelData[2]; loops: Animation.Infinite; running: root.animate
                    }
                }
            }
        }
    }
    // ABYSS: deep water, bubbles rising, jellyfish drifting up through the dark
    Component {
        id: abyssScene
        Item {
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0.0, 0.18, 0.35, 0.35) }
                    GradientStop { position: 1; color: Qt.rgba(0.0, 0.02, 0.08, 0.55) }
                }
            }
            ParticleSystem { id: sea; running: root.animate }
            ImageParticle { system: sea; groups: ["bubble"]; source: "../images/spark.png"; color: "#8FD8FF"; alpha: 0.35 }
            ImageParticle { system: sea; groups: ["jelly"]; source: "../images/sym-abyss-jelly.png"; alpha: 0.18 }
            Emitter {
                system: sea; group: "bubble"
                x: 0; y: root.height; width: root.width; height: 1
                emitRate: 6; lifeSpan: 9000
                size: 10; sizeVariation: 8
                velocity: PointDirection { y: -120; yVariation: 50; xVariation: 10 }
            }
            Emitter {
                system: sea; group: "jelly"
                x: 0; y: root.height; width: root.width; height: 1
                emitRate: 0.25; lifeSpan: 24000
                size: 120; sizeVariation: 50
                velocity: PointDirection { y: -55; yVariation: 15; xVariation: 6 }
            }
        }
    }
    // CHAIN REACTION: gems drifting up like bubbles
    Component {
        id: gemScene
        Item {
            ParticleSystem { id: bubbles; running: root.animate }
            Repeater {
                model: ["ruby", "sapphire", "emerald", "nova"]
                Item {
                    ImageParticle { system: bubbles; groups: [modelData]; source: "../images/gem-" + modelData + ".png"; alpha: 0.25; rotationVariation: 40 }
                    Emitter {
                        system: bubbles; group: modelData
                        x: 0; y: root.height; width: root.width; height: 1
                        emitRate: 0.6; lifeSpan: 14000
                        size: 46; sizeVariation: 24
                        velocity: PointDirection { y: -70; yVariation: 30; xVariation: 12 }
                    }
                }
            }
        }
    }
    // BLACKJACK: green felt with drifting suits
    Component {
        id: feltScene
        Item {
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    // green felt for blackjack, royal blue for poker, plum for baccarat
                    GradientStop { position: 0; color: root.scene === "poker" ? Qt.rgba(0.05, 0.1, 0.35, 0.4) : root.scene === "baccarat" ? Qt.rgba(0.3, 0.05, 0.25, 0.4) : Qt.rgba(0.0, 0.25, 0.2, 0.35) }
                    GradientStop { position: 0.5; color: root.scene === "poker" ? Qt.rgba(0.03, 0.06, 0.25, 0.3) : root.scene === "baccarat" ? Qt.rgba(0.2, 0.03, 0.18, 0.3) : Qt.rgba(0.0, 0.18, 0.16, 0.3) }
                    GradientStop { position: 1; color: Qt.rgba(0.0, 0.05, 0.1, 0.45) }
                }
            }
            Rectangle {   // table rail
                width: parent.width * 1.6; height: width
                radius: width / 2
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: -width * 0.62 }
                color: "transparent"
                border { width: 3; color: Neon.alpha(Neon.yellow, 0.35) }
            }
            Repeater {
                model: ["spades", "hearts", "diamonds", "clubs", "spades", "hearts"]
                Image {
                    source: "../images/suit-" + modelData + ".png"
                    width: root.width * 0.3; height: width
                    x: root.width * ((index * 0.37) % 1) - width / 4
                    opacity: 0.07
                    NumberAnimation on y {
                        running: root.animate; loops: Animation.Infinite
                        from: root.height + 100 - index * 80; to: -root.width * 0.3; duration: 26000 + index * 3000
                    }
                    NumberAnimation on rotation { running: root.animate; loops: Animation.Infinite; from: 0; to: index % 2 ? 360 : -360; duration: 30000 }
                }
            }
        }
    }
    // ROULETTE: red velvet with slowly turning wheel rays
    Component {
        id: velvetScene
        Item {
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0.35, 0.0, 0.08, 0.3) }
                    GradientStop { position: 1; color: Qt.rgba(0.12, 0.0, 0.05, 0.45) }
                }
            }
            Canvas {
                width: Math.max(root.width, root.height) * 1.4; height: width
                anchors.centerIn: parent
                opacity: 0.12
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    var c = width / 2
                    for (var i = 0; i < 37; ++i) {
                        ctx.fillStyle = i === 0 ? "#39FF88" : (i % 2 ? "#FF3355" : "#100A28")
                        ctx.beginPath(); ctx.moveTo(c, c)
                        ctx.arc(c, c, c, i * 2 * Math.PI / 37, (i + 1) * 2 * Math.PI / 37); ctx.closePath(); ctx.fill()
                    }
                }
                RotationAnimation on rotation { running: root.animate; loops: Animation.Infinite; from: 0; to: 360; duration: 90000 }
            }
        }
    }
    // KENO: numbered balls floating up
    Component {
        id: ballScene
        Item {
            clip: true
            Repeater {
                model: 9
                Rectangle {
                    id: ball
                    width: root.width * (0.12 + (index % 3) * 0.04); height: width; radius: width / 2
                    x: root.width * ((index * 0.31) % 1) - width / 3
                    opacity: 0.16
                    gradient: Gradient {
                        GradientStop { position: 0; color: "white" }
                        GradientStop { position: 1; color: index % 2 ? Neon.pink : Neon.cyan }
                    }
                    Text { anchors.centerIn: parent; text: 1 + (index * 37) % 80; color: Neon.ink; font { pixelSize: ball.width * 0.4; bold: true } }
                    NumberAnimation on y {
                        running: root.animate; loops: Animation.Infinite
                        from: root.height + ball.height - index * 130; to: -ball.height; duration: 16000 + index * 2100
                    }
                }
            }
        }
    }
    // NEURAL WAYS: a network of nodes whose links fire in waves
    Component {
        id: neuralScene
        // painted once; the whole network breathes (an opacity pulse costs nothing to render)
        Canvas {
            id: net
            opacity: 0.4
            property real phase: 0.25
            onWidthChanged: requestPaint()
            SequentialAnimation on opacity {
                running: root.animate; loops: Animation.Infinite
                NumberAnimation { to: 0.55; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.3; duration: 1500; easing.type: Easing.InOutSine }
            }
            onPaint: {
                var ctx = getContext("2d"); ctx.reset()
                var seed = 11
                function rnd() { seed = (seed * 9301 + 49297) % 233280; return seed / 233280 }
                var nodes = []
                for (var i = 0; i < 26; ++i) nodes.push([rnd() * width, rnd() * height])
                for (i = 0; i < nodes.length; ++i)
                    for (var j = i + 1; j < nodes.length; ++j) {
                        var dx = nodes[i][0] - nodes[j][0], dy = nodes[i][1] - nodes[j][1], d = Math.sqrt(dx * dx + dy * dy)
                        if (d > width * 0.33) continue
                        var wave = 0.5 + 0.5 * Math.sin((nodes[i][1] / height - phase) * Math.PI * 4)
                        ctx.strokeStyle = "rgba(0,240,255," + (0.15 + 0.6 * wave * wave) + ")"
                        ctx.lineWidth = 1 + 2 * wave
                        ctx.beginPath(); ctx.moveTo(nodes[i][0], nodes[i][1]); ctx.lineTo(nodes[j][0], nodes[j][1]); ctx.stroke()
                    }
                for (i = 0; i < nodes.length; ++i) {
                    ctx.fillStyle = "rgba(255,43,214,0.9)"
                    ctx.beginPath(); ctx.arc(nodes[i][0], nodes[i][1], 5, 0, Math.PI * 2); ctx.fill()
                }
            }
        }
    }
    // DATA HEIST: sweeping red security lasers
    Component {
        id: laserScene
        Item {
            clip: true
            Repeater {
                model: 5
                Rectangle {
                    width: root.width * 1.6; height: 3
                    x: -root.width * 0.3
                    color: Neon.red
                    opacity: 0.45
                    transformOrigin: Item.Center
                    property real base: root.height * (0.15 + index * 0.17)
                    y: base
                    rotation: (index % 2 ? 1 : -1) * 12
                    SequentialAnimation on y {
                        running: root.animate; loops: Animation.Infinite
                        NumberAnimation { to: base + root.height * 0.12; duration: 2600 + index * 500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: base; duration: 2600 + index * 500; easing.type: Easing.InOutSine }
                    }
                    Rectangle { anchors.fill: parent; anchors.margins: -4; color: Neon.red; opacity: 0.25; radius: 4 }
                }
            }
        }
    }
    // OVERLOAD: circuit board with pulses running along the traces
    Component {
        id: circuitScene
        Item {
            id: board
            property var traces: []
            Canvas {
                id: pcb
                anchors.fill: parent
                opacity: 0.35
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    var seed = 3
                    function rnd() { seed = (seed * 9301 + 49297) % 233280; return seed / 233280 }
                    var paths = []
                    for (var k = 0; k < 18; ++k) {
                        var x = rnd() * width, y = rnd() * height, pts = [[x, y]]
                        for (var s = 0; s < 5; ++s) {
                            if (s % 2) x += (rnd() - 0.5) * width * 0.5; else y += (rnd() - 0.5) * height * 0.3
                            pts.push([x, y])
                        }
                        paths.push(pts)
                        ctx.strokeStyle = "rgba(248,255,58,0.5)"; ctx.lineWidth = 2
                        ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1])
                        for (var i = 1; i < pts.length; ++i) ctx.lineTo(pts[i][0], pts[i][1])
                        ctx.stroke()
                        ctx.fillStyle = "rgba(248,255,58,0.8)"
                        ctx.beginPath(); ctx.arc(pts[pts.length - 1][0], pts[pts.length - 1][1], 4, 0, Math.PI * 2); ctx.fill()
                    }
                    board.traces = paths
                }
            }
            Repeater {
                model: 6
                Rectangle {
                    id: spark
                    width: 10; height: 10; radius: 5
                    color: "white"
                    border { width: 3; color: Neon.yellow }
                    property var path: board.traces.length ? board.traces[(index * 3) % board.traces.length] : [[0, 0], [0, 0]]
                    property real t: 0
                    x: pos()[0] - 5; y: pos()[1] - 5
                    function pos() {
                        var n = path.length - 1, f = t * n, i = Math.min(n - 1, Math.floor(f)), u = f - i
                        return [path[i][0] + (path[i + 1][0] - path[i][0]) * u, path[i][1] + (path[i + 1][1] - path[i][1]) * u]
                    }
                    NumberAnimation on t { running: root.animate; loops: Animation.Infinite; from: 0; to: 1; duration: 2500 + index * 700 }
                }
            }
        }
    }
}
