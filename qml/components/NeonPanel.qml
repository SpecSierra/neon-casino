import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

// Cut-steel panel: a 9-patch frame (cut corners, top tab, inner rule, ticks) over a translucent
// ink fill, with a soft glow behind it. Art from tools/gen-ui.py, drawn at 2x.
Item {
    id: panel
    property color glowColor: Neon.cyan
    property real glowStrength: 0.35
    property bool strong: false
    property real radius: 0                 // kept for old callers; the frame has cut corners
    default property alias content: inner.data
    property alias contentItem: inner
    property real padding: 0
    readonly property string key: Neon.key(glowColor)
    readonly property real k: Math.max(0.5, Theme.pixelRatio || 1) / 2      // asset px → screen px

    BorderImage {
        x: -48 * panel.k; y: -48 * panel.k
        width: (panel.width + 96 * panel.k) / panel.k; height: (panel.height + 96 * panel.k) / panel.k
        scale: panel.k; transformOrigin: Item.TopLeft
        source: "../images/ui/glow-" + panel.key + ".png"
        border { left: 88; right: 88; top: 88; bottom: 88 }
        opacity: Math.min(1, panel.glowStrength * 1.3)
        visible: panel.glowStrength > 0.05
    }
    BorderImage {
        width: panel.width / panel.k; height: panel.height / panel.k
        scale: panel.k; transformOrigin: Item.TopLeft
        source: "../images/ui/frame-" + panel.key + (panel.strong ? "-strong" : "") + ".png"
        border { left: 40; right: 40; top: 40; bottom: 40 }
    }
    Item {
        id: inner
        anchors { fill: parent; margins: panel.padding }
    }
}
