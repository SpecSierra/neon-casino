import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/SlotThemes.js" as Themes
import "../js/CascadeConfig.js" as CascadeConfig
import "../js/WaysConfig.js" as WaysConfig
import "../js/HeistConfig.js" as HeistConfig
import "../js/AbyssConfig.js" as AbyssConfig
import "../js/VoidConfig.js" as VoidConfig
import "../js/ArcadeConfig.js" as ArcadeConfig
import "../js/Slots.js" as Slots
import "../js/Money.js" as Money

// Pick a machine. New machines unlock with lifetime wagers, like perks.
Page {
    id: page
    Backdrop { accent: Neon.pink }
    onStatusChanged: if (status === PageStatus.Active) Music.track = "slots"
    property bool settled: false
    Timer { running: true; interval: 500; onTriggered: page.settled = true }

    SilicaListView {
        anchors.fill: parent
        header: Column {
            width: parent.width
            NeonHeader { title: "Slot machines"; code: "ALL ~95% RTP · BARS = RISK"; color: Neon.pink }
        }
        model: Themes.themes.concat([CascadeConfig.machine, WaysConfig.machine, HeistConfig.machine,
                                     VoidConfig.machine, ArcadeConfig.machine, AbyssConfig.machine])
                   .sort(function (a, b) { return a.unlock - b.unlock })
        spacing: Theme.paddingLarge
        cacheBuffer: height * 3              // build every card up front: no pop-in while scrolling
        delegate: MouseArea {
            id: card
            readonly property var t: modelData
            readonly property bool open: t.unlock <= Game.lifetimeWagered
            x: Theme.horizontalPageMargin
            width: ListView.view.width - 2 * x
            height: col.height + 2 * Theme.paddingLarge
            enabled: open
            onClicked: {
                Sound.play("click"); Haptics.tap()
                var pages = { cascade: "CascadePage.qml", ways: "WaysPage.qml", heist: "HeistPage.qml",
                              void: "VoidPage.qml", arcade: "ArcadePage.qml", abyss: "AbyssPage.qml" }
                if (pages[t.type]) pageStack.push(Qt.resolvedUrl(pages[t.type]))
                else pageStack.push(Qt.resolvedUrl("SlotsPage.qml"), { themeId: t.id })
            }
            opacity: 0
            transform: Translate { id: slide; x: card.width }
            // only the first screenful slides in (briefly staggered); cards created later while
            // scrolling show up at once instead of waiting index × delay
            Component.onCompleted: { if (page.settled) { opacity = card.open ? 1 : 0.55; slide.x = 0 } else tileIn.start() }
            SequentialAnimation {
                id: tileIn
                PauseAnimation { duration: 40 + Math.min(index, 4) * 60 }
                ParallelAnimation {
                    NumberAnimation { target: card; property: "opacity"; to: card.open ? 1 : 0.55; duration: 300 }
                    NumberAnimation { target: slide; property: "x"; to: 0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                }
            }

            NeonPanel {
                anchors.fill: parent
                glowColor: card.t.color
                glowStrength: card.pressed ? 0.95 : (card.open ? 0.5 : 0.15)
                strong: true
            }
            Column {
                id: col
                anchors { left: parent.left; right: parent.right; margins: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
                spacing: Theme.paddingSmall
                Item {
                    width: parent.width; height: title.height
                    NeonText { id: title; text: card.t.name; color: card.t.color; glow: 8 }
                    Row {      // volatility pips
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Repeater {
                            model: 5
                            Rectangle {
                                width: Theme.paddingMedium; height: Theme.paddingMedium * (0.8 + index * 0.25)
                                anchors.bottom: parent.bottom
                                radius: 2
                                color: index < card.t.volatility ? card.t.color : Neon.alpha(card.t.color, 0.2)
                            }
                        }
                    }
                }
                Row {
                    spacing: Theme.paddingSmall
                    Repeater {
                        model: card.t.type === "cascade" ? card.t.gems.slice(0, 5).concat(["core"])
                               : card.t.type === "ways" ? card.t.symbols.slice().reverse().slice(0, 4).concat(["wild", "scatter"])
                               : card.t.type === "heist" ? card.t.symbols.slice().reverse().slice(0, 5).concat(["chip"])
                               : card.t.type === "void" ? card.t.symbols.slice().reverse().slice(0, 4).concat(["wild", "portal"])
                               : card.t.type === "arcade" ? ["coin", "ghost", "invader", "joystick", "crown", "wild"]
                               : card.t.type === "abyss" ? card.t.symbols.slice().reverse().slice(0, 4).concat(["wild", "pearl"])
                               : card.t.symbols.slice().reverse().concat(["wild", "scatter"]).slice(0, 6)
                        Image {
                            width: (col.width - 5 * Theme.paddingSmall) / 6; height: width
                            source: Slots.image(card.t, modelData)
                        }
                    }
                }
                Label {
                    width: parent.width; wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeTiny
                    text: card.open ? card.t.tagline
                                    : "LOCKED · unlocks at " + Money.fmt(card.t.unlock) + " wagered (you: " + Money.fmt(Game.lifetimeWagered) + ")"
                    color: card.open ? Theme.primaryColor : Theme.secondaryColor
                }
                Text {
                    visible: card.open
                    text: card.t.type === "cascade" ? "CHAIN ×2 PER DROP · FREE DROPS WITH A MULTIPLIER THAT NEVER RESETS"
                          : card.t.type === "ways" ? "UP TO 117,649 WAYS · FREE SPINS +1× PER WIN · MAX " + card.t.maxWin + "×"
                          : card.t.type === "heist" ? "HOLD & WIN RESPINS · MINI · MINOR · MAJOR · GRAND " + card.t.grand + "×"
                          : card.t.type === "void" ? "INFINITY REELS · UP TO " + card.t.maxReels + " · +1× PER REEL · MAX " + card.t.bonus.maxWin + "×"
                          : card.t.type === "arcade" ? (Game.arcade ? "CARD IN PLAY · TAP TO CONTINUE" : "5×5 CARD · 10 SPINS · JOKERS · TOP " + card.t.ladder[12] + "×")
                          : card.t.type === "abyss" ? "FRUIT MACHINE · HOLDS · NUDGES · TOP " + card.t.pay3.wild + "×"
                          : card.t.bonus.spins + " FREE SPINS" + (card.t.feature.type === "stack" ? " · STACKING ×" : " · LADDER TO ×" + card.t.bonus.ladders[card.t.bonus.ladders.length - 1][3])
                          + " · MAX " + card.t.bonus.maxWin + "×"
                    width: parent.width; wrapMode: Text.Wrap       // never wider than the card
                    color: Neon.alpha(card.t.color, 0.85)
                    font { pixelSize: Theme.fontSizeTiny * 0.85; family: Neon.mono }
                }
            }
        }
        VerticalScrollDecorator {}
    }
}
