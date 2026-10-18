import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

// Quick games: one screen, three by five.
Page {
    id: page
    Backdrop { accent: Neon.yellow; scene: "circuit" }
    onStatusChanged: if (status === PageStatus.Active) Music.track = "minis"

    readonly property var games: [
        { page: "HiLoPage.qml", title: "HI-LO", sub: Game.hilo ? "ROUND OPEN" : "SWIPE THE CARD", icon: "sym-hilo", color: Neon.green },
        { page: "TowerPage.qml", title: "TOWER", sub: Game.tower ? "CLIMB OPEN" : "8 FLOORS · DODGE TRAPS", icon: "sym-tower", color: Neon.violet },
        { page: "CoinFlipPage.qml", title: "COIN FLIP", sub: "CALL IT · 1.94×", icon: "sym-coinflip", color: Neon.yellow },
        { page: "DicePage.qml", title: "DICE", sub: "OVER / UNDER", icon: "sym-dice", color: Neon.cyan },
        { page: "MoneyWheelPage.qml", title: "MONEY WHEEL", sub: "51 STOPS · UP TO 50×", icon: "sym-wheel", color: Neon.yellow },
        { page: "ScratchPage.qml", title: "SCRATCH", sub: "MATCH 3 · 500×", icon: "sym-scratch", color: "#FF9F14" },
        { page: "RacePage.qml", title: "DRONE RACE", sub: "6 RUNNERS · UP TO 12×", icon: "sym-race", color: Neon.green },
        { page: "RpsPage.qml", title: "R·P·S", sub: "BEAT THE AI · 1.91×", icon: "sym-rps", color: Neon.pink },
        { page: "WarPage.qml", title: "CARD WAR", sub: "HIGH CARD 1:1", icon: "sym-war", color: Neon.red },
        { page: "PenaltyPage.qml", title: "PENALTY", sub: "SWIPE TO SHOOT", icon: "sym-penalty", color: Neon.green },
        { page: "RedDogPage.qml", title: "RED DOG", sub: "THIRD CARD BETWEEN", icon: "sym-reddog", color: Neon.red },
        { page: "BalloonPage.qml", title: "BALLOON", sub: Game.balloon ? "ROUND OPEN" : "PUMP · DON'T POP", icon: "sym-balloon", color: Neon.pink },
        { page: "DartsPage.qml", title: "DARTS", sub: "FLICK · BULL 8.3×", icon: "sym-darts", color: Neon.cyan },
        { page: "ClawPage.qml", title: "CLAW", sub: "DROP ON A PRIZE", icon: "sym-claw", color: Neon.yellow },
        { page: "ChestsPage.qml", title: "CHESTS", sub: "PICK ONE OF THREE", icon: "sym-chest", color: "#FF9F14" }
    ]

    NeonHeader { id: hdr; title: "Mini games"; code: "QUICK ROUNDS · 92-97% RTP"; color: Neon.yellow }
    Flow {
        id: grid
        anchors { left: parent.left; right: parent.right; top: hdr.bottom; bottom: parent.bottom
                  leftMargin: Theme.horizontalPageMargin; rightMargin: Theme.horizontalPageMargin
                  topMargin: Theme.paddingMedium; bottomMargin: Theme.paddingLarge }
        spacing: Theme.paddingMedium
        readonly property real cw: (width - 2 * spacing) / 3
        readonly property real ch: (height - 4 * spacing) / 5
        Repeater {
            model: page.games
            MouseArea {
                id: card
                width: grid.cw; height: grid.ch
                enabled: !Game.runOver
                onClicked: { Sound.play("click"); Haptics.tap(); pageStack.push(Qt.resolvedUrl(modelData.page)) }
                opacity: 0
                Component.onCompleted: cardIn.start()
                SequentialAnimation {
                    id: cardIn
                    PauseAnimation { duration: 60 + index * 60 }
                    NumberAnimation { target: card; property: "opacity"; to: 1; duration: 260 }
                }
                readonly property bool alert: modelData.sub.indexOf("OPEN") >= 0
                NeonPanel { anchors.fill: parent; glowColor: modelData.color; glowStrength: card.pressed ? 0.9 : card.alert ? 0.6 : 0.3; strong: true }
                Image {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.paddingLarge }
                    width: Math.min(parent.width * 0.5, parent.height * 0.48); height: width
                    source: "../images/" + modelData.icon + ".png"
                }
                Column {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.paddingMedium }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.title
                        color: Qt.lighter(modelData.color, 1.15)
                        font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeMedium }
                        fontSizeMode: Text.HorizontalFit; minimumPixelSize: Theme.fontSizeTiny
                    }
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.sub
                        color: card.alert ? Neon.yellow : Theme.secondaryColor
                        font { family: Neon.mono; pixelSize: Theme.fontSizeTiny }
                    }
                }
            }
        }
    }
}
