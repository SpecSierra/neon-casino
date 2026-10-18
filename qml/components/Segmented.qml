import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

// Row of neon toggle buttons; `current` is the selected index.
Row {
    id: seg
    property var labels: []
    property int current: 0
    property color color: Neon.cyan
    signal picked(int index)
    spacing: Theme.paddingSmall
    Repeater {
        model: seg.labels
        NeonButton {
            width: (seg.width - (seg.labels.length - 1) * seg.spacing) / seg.labels.length
            height: Theme.itemSizeExtraSmall
            text: modelData
            fontSize: Theme.fontSizeExtraSmall
            color: seg.color
            primary: index === seg.current
            opacity: index === seg.current ? 1 : 0.6
            onClicked: { seg.current = index; seg.picked(index) }
        }
    }
}
