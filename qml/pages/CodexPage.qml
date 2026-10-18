import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money
import "../js/Perks.js" as Perks

Page {
    Backdrop { accent: Neon.violet }
    SilicaListView {
        anchors.fill: parent
        header: Column {
            width: parent.width
            NeonHeader { title: "Perk codex"; code: "UNLOCKED BY LIFETIME WAGERS · " + Money.fmt(Game.lifetimeWagered); color: Neon.violet }
        }
        model: Perks.all
        spacing: Theme.paddingMedium
        delegate: Item {
            readonly property bool open: modelData.unlock <= Game.lifetimeWagered
            x: Theme.horizontalPageMargin
            width: ListView.view.width - 2 * x
            height: inner.height + 2 * Theme.paddingLarge
            NeonPanel {
                anchors.fill: parent
                glowColor: open ? modelData.color : Theme.secondaryColor
                glowStrength: open ? (Game.hasPerk(modelData.id) ? 0.8 : 0.35) : 0.1
            }
            Column {
                id: inner
                anchors { left: parent.left; right: parent.right; margins: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
                spacing: Theme.paddingSmall / 2
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (open ? modelData.name.toUpperCase() : "LOCKED · " + Money.fmt(modelData.unlock) + " WAGERED")
                          + (Game.hasPerk(modelData.id) ? "  ✓" : "")
                    color: open ? Qt.lighter(modelData.color, 1.2) : Theme.secondaryColor
                    font { pixelSize: Theme.fontSizeSmall; bold: true; letterSpacing: 1; family: Neon.display }
                }
                Label {
                    width: parent.width; wrapMode: Text.Wrap
                    text: open ? modelData.desc : "Keep playing to decrypt this perk."
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: open ? Theme.primaryColor : Theme.secondaryColor
                }
            }
        }
        VerticalScrollDecorator {}
    }
}
