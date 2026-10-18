import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money
import "../js/Perks.js" as Perks

// The lobby. Everything fits on one screen: the game grid takes whatever height is left
// after the title, the credits bar and (when there is one) the perk banner.
Page {
    id: page
    objectName: "hub"
    function open(target) {
        Sound.play("click")
        if (target === "SlotsLobbyPage.qml" && Game.arcade) {             // straight back to the open card
            pageStack.push(Qt.resolvedUrl("ArcadePage.qml"))
        } else if (target === "SlotsLobbyPage.qml" && Game.slotBonus) {          // straight back into the bonus
            var special = { cascade: "CascadePage.qml", ways: "WaysPage.qml", void: "VoidPage.qml" }[Game.slotBonus.theme]
            if (special) pageStack.push(Qt.resolvedUrl(special))
            else pageStack.push(Qt.resolvedUrl("SlotsPage.qml"), { themeId: Game.slotBonus.theme || "classic" })
        } else {
            pageStack.push(Qt.resolvedUrl(target))
        }
    }
    onStatusChanged: if (status === PageStatus.Active) Music.track = "lobby"

    Backdrop { accent: Neon.cyan }

    readonly property var games: [
        { page: "SlotsLobbyPage.qml", title: "SLOTS", sub: Game.slotBonus ? "FREE SPINS WAITING" : Game.arcade ? "CARD IN PLAY" : "10 MACHINES", icon: "sym-seven", color: Neon.pink, wide: true },
        { page: "BlackjackPage.qml", title: "BLACKJACK", sub: Game.blackjack ? "HAND OPEN" : "3:2", icon: "suit-spades", color: Neon.cyan },
        { page: "RoulettePage.qml", title: "ROULETTE", sub: "SINGLE ZERO", icon: "sym-chip", color: Neon.red },
        { page: "PokerPage.qml", title: "POKER", sub: Game.poker ? "HAND OPEN" : "JACKS+", icon: "sym-poker", color: Neon.violet },
        { page: "BaccaratPage.qml", title: "BACCARAT", sub: "PUNTO BANCO", icon: "sym-baccarat", color: "#FFC828" },
        { page: "CrapsPage.qml", title: "CRAPS", sub: Game.crapsOnTable > 0 ? "BETS RIDING" : "FLICK", icon: "sym-craps", color: Neon.green },
        { page: "SicBoPage.qml", title: "SIC BO", sub: "3 DICE", icon: "sym-sicbo", color: "#FF9F14" },
        { page: "KenoPage.qml", title: "KENO", sub: "10 OF 80", icon: "sym-keno", color: Neon.pink },
        { page: "MinesPage.qml", title: "MINES", sub: Game.mines ? "ROUND OPEN" : "25 TILES", icon: "sym-mines", color: Neon.red },
        { page: "PlinkoPage.qml", title: "PLINKO", sub: "12 ROWS", icon: "sym-plinko", color: Neon.cyan },
        { page: "OverloadPage.qml", title: "OVERLOAD", sub: "CRASH", icon: "sym-overload", color: Neon.yellow },
        { page: "MiniGamesPage.qml", title: "MINI GAMES", sub: Game.hilo || Game.tower || Game.balloon ? "ROUND OPEN" : "15 GAMES · TOWER · BALLOON · DARTS · CLAW …",
          icon: "sym-tower", color: Neon.violet, span: 3 }
    ]

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: height            // never scrolls; the pull-down menu still works

        // quick audio switches only; everything else lives on the Settings page
        PullDownMenu {
            MenuItem { text: Game.music ? "Music off" : "Music on"; onClicked: { Game.music = !Game.music; Game.save() } }
            MenuItem { text: Game.sound ? "Sound off" : "Sound on"; onClicked: { Game.sound = !Game.sound; Game.save() } }
            MenuItem { text: Game.vibration ? "Vibration off" : "Vibration on"; onClicked: { Game.vibration = !Game.vibration; Game.save() } }
        }

        Column {
            id: top
            width: parent.width
            spacing: Theme.paddingMedium
            Item { width: 1; height: Theme.paddingLarge }
            // title block + Vault / Stats keys
            Item {
                x: Theme.horizontalPageMargin
                width: page.width - 2 * x
                height: wordmark.height
                Rectangle {
                    id: hz
                    width: Theme.paddingMedium; height: parent.height
                    color: "transparent"; clip: true
                    Image { anchors.fill: parent; source: "../images/ui/hazard-yellow.png"; fillMode: Image.Tile }
                }
                Column {
                    id: wordmark
                    anchors { left: hz.right; leftMargin: Theme.paddingMedium }
                    NeonText {
                        text: "NEON"
                        color: Neon.pink
                        font.pixelSize: Math.min(Theme.fontSizeHuge * 1.2, page.width / 5.5)
                        font.letterSpacing: 3
                        glow: 12
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite; running: Qt.application.active
                            NumberAnimation { to: 0.7; duration: 90 } NumberAnimation { to: 1; duration: 60 }
                            PauseAnimation { duration: 3400 }
                            NumberAnimation { to: 0.45; duration: 50 } NumberAnimation { to: 1; duration: 80 }
                            PauseAnimation { duration: 5200 }
                        }
                    }
                    Text {
                        text: "CASINO"
                        color: "transparent"
                        style: Text.Outline; styleColor: Neon.cyan
                        font { family: Neon.display; bold: true; pixelSize: Math.min(Theme.fontSizeExtraLarge, page.width / 10); letterSpacing: 8 }
                    }
                    Text {
                        text: "RUN #" + Game.runs + (Game.custom ? " // CUSTOM" : "") + " // " + Game.perks.length + " PERK" + (Game.perks.length === 1 ? "" : "S")
                        color: Neon.alpha(Neon.yellow, 0.85)
                        font { family: Neon.mono; pixelSize: Theme.fontSizeTiny; letterSpacing: 1 }
                    }
                }
                Column {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.paddingSmall
                    NeonButton { width: Theme.itemSizeExtraLarge * 1.05; height: Theme.itemSizeExtraSmall * 0.78; text: "Vault"; color: Neon.cyan; fontSize: Theme.fontSizeExtraSmall; onClicked: pageStack.push(Qt.resolvedUrl("VaultPage.qml")) }
                    NeonButton { width: Theme.itemSizeExtraLarge * 1.05; height: Theme.itemSizeExtraSmall * 0.78; text: "Stats"; color: Neon.green; fontSize: Theme.fontSizeExtraSmall; onClicked: pageStack.push(Qt.resolvedUrl("StatsPage.qml")) }
                    NeonButton { width: Theme.itemSizeExtraLarge * 1.05; height: Theme.itemSizeExtraSmall * 0.78; text: "Settings"; color: Neon.violet; fontSize: Theme.fontSizeExtraSmall; onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml")) }
                }
            }
            Hud { x: Theme.horizontalPageMargin; width: page.width - 2 * x }
            NeonButton {
                visible: Game.pendingDrafts > 0 || Game.sessionLocked
                x: Theme.horizontalPageMargin
                width: page.width - 2 * x
                height: visible ? Theme.itemSizeSmall : 0
                text: Game.sessionLocked ? "Loss limit hit · open the Vault" : Game.pendingDrafts > 1 ? "Choose perks (" + Game.pendingDrafts + ")" : "Choose a perk"
                color: Game.sessionLocked ? Neon.red : Neon.yellow; primary: true
                onClicked: pageStack.push(Qt.resolvedUrl(Game.sessionLocked ? "VaultPage.qml" : "PerkDraftPage.qml"))
            }
        }

        // the game grid: 3 columns, 5 rows (slots spans two), sized to the space that's left
        Flow {
            id: grid
            anchors { left: parent.left; right: parent.right; top: top.bottom; bottom: parent.bottom
                      leftMargin: Theme.horizontalPageMargin; rightMargin: Theme.horizontalPageMargin
                      topMargin: Theme.paddingMedium; bottomMargin: Theme.paddingLarge }
            spacing: Theme.paddingSmall
            readonly property real cw: (width - 2 * spacing) / 3
            readonly property real ch: (height - 4 * spacing) / 5
            Repeater {
                model: page.games
                MouseArea {
                    id: card
                    width: modelData.span === 3 ? grid.width : modelData.wide ? grid.cw * 2 + grid.spacing : grid.cw
                    height: grid.ch
                    enabled: !Game.runOver
                    onClicked: page.open(modelData.page)
                    opacity: 0
                    Component.onCompleted: cardIn.start()
                    SequentialAnimation {
                        id: cardIn
                        PauseAnimation { duration: 60 + index * 45 }
                        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 240 }
                    }
                    readonly property bool alert: modelData.sub.indexOf("OPEN") >= 0 || modelData.sub.indexOf("WAITING") >= 0 || modelData.sub.indexOf("RIDING") >= 0
                    NeonPanel { anchors.fill: parent; glowColor: modelData.color; glowStrength: card.pressed ? 0.9 : card.alert ? 0.6 : 0.2; strong: modelData.wide || modelData.span === 3 }
                    Image {
                        anchors { left: parent.left; top: parent.top; leftMargin: Theme.paddingMedium; topMargin: Theme.paddingMedium }
                        width: Math.min(parent.height * 0.48, parent.width * 0.5); height: width
                        source: "../images/" + modelData.icon + ".png"
                    }
                    Text {
                        anchors { right: parent.right; top: parent.top; margins: Theme.paddingMedium }
                        text: (index + 1 < 10 ? "0" : "") + (index + 1)
                        color: Neon.alpha(modelData.color, 0.7)
                        font { family: Neon.mono; pixelSize: Theme.fontSizeTiny }
                    }
                    Column {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.paddingMedium }
                        Text {
                            width: parent.width
                            text: modelData.title
                            color: Qt.lighter(modelData.color, 1.15)
                            font { family: Neon.display; bold: true; pixelSize: modelData.wide || modelData.span === 3 ? Theme.fontSizeExtraLarge : Theme.fontSizeSmall }
                            fontSizeMode: Text.HorizontalFit; minimumPixelSize: Theme.fontSizeTiny
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: modelData.sub
                            color: card.alert ? Neon.yellow : Theme.secondaryColor
                            font { family: Neon.mono; pixelSize: Theme.fontSizeTiny * 0.9 }
                        }
                    }
                }
            }
        }
    }
}
