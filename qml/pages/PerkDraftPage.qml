import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money
import "../js/Perks.js" as Perks

Page {
    id: page
    objectName: "draft"
    backNavigation: false
    property var offers: []

    function roll() { offers = Perks.draft(Game.lifetimeWagered, Game.perks, 3) }
    Component.onCompleted: { roll(); Sound.play("perk"); Haptics.rumble(2) }

    property bool remember: Game.starterPerk !== ""
    function choose(id) {
        if (Game.tier === 0 && id) { Game.starterPerk = remember ? id : ""; Game.save() }
        if (id) Game.takePerk(id)
        else page.cashText = "+" + Money.fmt(Game.takeCashDraft())
        Sound.play("perk")
        if (Game.pendingDrafts > 0) roll()
        else pageStack.pop()
    }
    property string cashText

    Backdrop { accent: Neon.yellow }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height + Theme.paddingLarge
        Column {
            id: col
            width: parent.width
            spacing: Theme.paddingLarge
            Item { width: 1; height: Theme.paddingLarge * 2 }
            NeonText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Game.tier === 0 ? "STARTER PERK" : "TIER " + Game.tier + " REACHED"
                color: Neon.yellow; font.pixelSize: Theme.fontSizeExtraLarge; glow: 14
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "PICK ONE · MIN BET NOW " + Money.fmt(Game.minBet)
                color: Neon.alpha(Neon.yellow, 0.75)
                font { pixelSize: Theme.fontSizeExtraSmall; letterSpacing: 3; family: Neon.display }
            }
            Repeater {
                model: page.offers
                MouseArea {
                    id: card
                    x: Theme.horizontalPageMargin
                    width: col.width - 2 * x
                    height: inner.height + 2 * Theme.paddingLarge
                    onClicked: page.choose(modelData.id)
                    NeonPanel { anchors.fill: parent; glowColor: modelData.color; glowStrength: card.pressed ? 1 : 0.55; strong: true }
                    Column {
                        id: inner
                        anchors { left: parent.left; right: parent.right; margins: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
                        spacing: Theme.paddingSmall
                        NeonText { text: modelData.name.toUpperCase(); color: modelData.color; glow: 8 }
                        Text {
                            text: (modelData.game === "any" ? "ANY TABLE" : modelData.game.toUpperCase())
                            color: Neon.alpha(modelData.color, 0.7)
                            font { pixelSize: Theme.fontSizeTiny; letterSpacing: 3; family: Neon.display }
                        }
                        Label { width: parent.width; wrapMode: Text.Wrap; text: modelData.desc; font.pixelSize: Theme.fontSizeSmall }
                    }
                    opacity: 0
                    Component.onCompleted: appear.start()
                    SequentialAnimation {
                        id: appear
                        PauseAnimation { duration: index * 140 }
                        ParallelAnimation {
                            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 250 }
                            NumberAnimation { target: card; property: "scale"; from: 0.85; to: 1; duration: 300; easing.type: Easing.OutBack }
                        }
                    }
                }
            }
            // starter only: remember the pick for future runs
            MouseArea {
                visible: Game.tier === 0 && page.offers.length > 0
                x: Theme.horizontalPageMargin
                width: col.width - 2 * x
                height: Theme.itemSizeSmall
                onClicked: { page.remember = !page.remember; Sound.play("click"); Haptics.tick() }
                Rectangle {
                    id: box
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSizeSmall; height: width; radius: 4
                    color: page.remember ? Neon.alpha(Neon.yellow, 0.35) : "transparent"
                    border { width: 2; color: Neon.yellow }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.5; height: width; radius: 2
                        color: Neon.yellow
                        scale: page.remember ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                    }
                }
                Label {
                    anchors { left: box.right; leftMargin: Theme.paddingMedium; right: parent.right; verticalCenter: parent.verticalCenter }
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Neon.yellow
                    text: "Remember my pick and start every run with it"
                }
            }
            NeonButton {
                visible: page.offers.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "All perks owned · take cash"
                color: Neon.green; primary: true
                onClicked: page.choose(null)
            }
            Label {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: Game.nextUnlock ? "Keep wagering to unlock more perks. Next: " + Game.nextUnlock.name
                                         + " at " + Money.fmt(Game.nextUnlock.unlock) + " lifetime." : ""
            }
        }
    }
}
