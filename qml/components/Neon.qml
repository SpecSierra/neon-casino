pragma Singleton
import QtQuick 2.6

QtObject {
    readonly property color cyan: "#00F0FF"
    readonly property color pink: "#FF2BD6"
    readonly property color yellow: "#F8FF3A"
    readonly property color green: "#39FF88"
    readonly property color red: "#FF3355"
    readonly property color violet: "#A05AFF"
    readonly property color ink: "#0A0618"
    // Translucent panel fill: lets the blurred ambience show through.
    readonly property color glass: Qt.rgba(0.04, 0.02, 0.10, 0.55)
    readonly property color glassStrong: Qt.rgba(0.04, 0.02, 0.10, 0.78)

    // Accepts a color or a "#rrggbb" string.
    function alpha(c, a) { var q = Qt.lighter(c, 1.0); return Qt.rgba(q.r, q.g, q.b, a) }
    // ---- type: Chakra Petch for display, Share Tech Mono for numbers (both OFL, in qml/fonts) ----
    property FontLoader displayLoader: FontLoader { source: "../fonts/NeonDisplay.ttf" }
    property FontLoader monoLoader: FontLoader { source: "../fonts/NeonMono.ttf" }
    readonly property string display: displayLoader.status === FontLoader.Ready ? displayLoader.name : "sans-serif"
    readonly property string mono: monoLoader.status === FontLoader.Ready ? monoLoader.name : "monospace"

    // ---- UI chrome: tools/gen-ui.py draws frames/buttons per accent; pick the nearest one ----
    readonly property var palette: ({ cyan: [0, 240, 255], pink: [255, 43, 214], yellow: [248, 255, 58], green: [57, 255, 136],
                                      red: [255, 51, 85], violet: [160, 90, 255], orange: [255, 159, 20], gold: [255, 200, 40],
                                      white: [235, 235, 255], grey: [130, 130, 160] })
    function key(c) {
        var q = Qt.lighter(c, 1.0), best = "cyan", bd = 1e9
        for (var k in palette) {
            var p = palette[k], d = Math.pow(q.r * 255 - p[0], 2) + Math.pow(q.g * 255 - p[1], 2) + Math.pow(q.b * 255 - p[2], 2)
            if (d < bd) { bd = d; best = k }
        }
        return best
    }

    function gameColor(game) {
        return game === "slots" ? pink : game === "blackjack" ? cyan : game === "roulette" ? red : green
    }
}
