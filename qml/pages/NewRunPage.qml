import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// Start a run: the normal ¤100 climb, or a custom bankroll. Tiers and minimum bets scale
// with the start, custom runs don't touch your best-ever record, and their wagers count
// toward unlocks at the normal-run rate.
Page {
    id: page
    property real amount: 1000
    readonly property bool ending: !Game.runOver        // starting here ends the current run
    Backdrop { accent: Neon.yellow }

    function start(v) {
        if (Game.rebootAvailable) { Game.note("PLAY YOUR REBOOT FIRST", Neon.yellow); return }
        if (ending) Game.endRun(true)
        Game.newRun(v)
        Sound.play("perk"); Haptics.rumble(2)
        pageStack.pop(pageStack.find(function (p) { return p.objectName === "hub" }))
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height + Theme.paddingLarge
        Column {
            id: col
            width: parent.width
            spacing: Theme.paddingLarge
            NeonHeader { title: "New run"; code: "NORMAL ¤100 OR CUSTOM BANKROLL"; color: Neon.yellow }

            Label {
                visible: page.ending
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Neon.red
                text: "Your current run (" + Money.fmt(Game.netWorth) + ", tier " + Game.tier + ") ends when you start a new one."
            }

            NeonButton {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                height: Theme.itemSizeLarge
                text: "Normal run · " + Money.fmt(100)
                color: Neon.cyan; primary: true
                fontSize: Theme.fontSizeLarge
                onClicked: page.start(100)
            }
            Label {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: "The real climb. Counts for your best-ever record."
            }

            SectionHeader { text: "Custom run" }
            Label {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: "Start with any bankroll. Tiers and table minimums scale with it, so the climb feels the same. "
                      + "Custom runs don't set records, and their bets count toward unlocks at the normal rate."
            }
            Grid {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                columns: 3
                spacing: Theme.paddingSmall
                Repeater {
                    model: [500, 1000, 10000, 100000, 1000000, 1000000000]
                    NeonButton {
                        width: (col.width - 2 * Theme.horizontalPageMargin - 2 * Theme.paddingSmall) / 3
                        height: Theme.itemSizeSmall
                        text: Money.fmt(modelData)
                        color: Neon.yellow
                        primary: page.amount === modelData
                        fontSize: Theme.fontSizeSmall
                        onClicked: { page.amount = modelData; field.text = String(modelData) }
                    }
                }
            }
            TextField {
                id: field
                x: Theme.horizontalPageMargin - Theme.paddingLarge
                width: parent.width - 2 * Theme.horizontalPageMargin + 2 * Theme.paddingLarge
                label: "Starting amount (¤ neon credits)"
                placeholderText: "Any amount, e.g. 2500"
                text: "1000"
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1; top: 2000000000 }
                onTextChanged: { var v = parseInt(text, 10); if (v > 0) page.amount = v }
            }
            NeonButton {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                height: Theme.itemSizeLarge
                text: "Start custom · " + Money.fmt(page.amount)
                color: Neon.yellow; primary: true
                fontSize: Theme.fontSizeLarge
                enabled: page.amount >= 1
                onClicked: page.start(page.amount)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "MIN BET " + Money.fmt(Money.minBet(0, page.amount / 100)) + " · TIER 1 AT " + Money.fmt(Money.tierThreshold(1, page.amount / 100))
                color: Neon.alpha(Neon.yellow, 0.7)
                font { pixelSize: Theme.fontSizeTiny; letterSpacing: 2; family: Neon.display }
            }
        }
        VerticalScrollDecorator {}
    }
}
