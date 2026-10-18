import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money

// Vault + session manager: put winnings aside, sweep wins automatically, set a loss
// limit and a win goal for this session.
Page {
    id: page
    Backdrop { accent: Neon.cyan }

    property real now: Date.now()
    Timer { interval: 1000; repeat: true; running: Qt.application.active; onTriggered: page.now = Date.now() }
    function duration(ms) {
        var m = Math.floor(ms / 60000), h = Math.floor(m / 60)
        return h > 0 ? h + " h " + (m % 60) + " min" : m + " min"
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height + Theme.paddingLarge
        Column {
            id: col
            width: parent.width
            spacing: Theme.paddingLarge
            NeonHeader { title: "Vault"; code: "SET CREDITS ASIDE · SESSION LIMITS"; color: Neon.cyan }

            // vault + chips
            NeonPanel {
                x: Theme.horizontalPageMargin
                width: col.width - 2 * x
                height: vaultCol.height + 2 * Theme.paddingLarge
                glowColor: Neon.cyan; strong: true
                Column {
                    id: vaultCol
                    anchors { left: parent.left; right: parent.right; margins: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
                    spacing: Theme.paddingMedium
                    Row {
                        width: parent.width
                        Column {
                            width: parent.width / 2
                            Text { text: "VAULT"; color: Neon.alpha(Neon.cyan, 0.7); font { pixelSize: Theme.fontSizeTiny; letterSpacing: 3; family: Neon.display } }
                            NeonText { text: Money.fmt(Game.vault); color: Neon.cyan; font.pixelSize: Theme.fontSizeExtraLarge; glow: 10 }
                        }
                        Column {
                            width: parent.width / 2
                            Text { anchors.right: parent.right; text: "CHIPS"; color: Neon.alpha(Neon.yellow, 0.7); font { pixelSize: Theme.fontSizeTiny; letterSpacing: 3; family: Neon.display } }
                            NeonText { anchors.right: parent.right; text: Money.fmt(Game.balance); color: Neon.yellow; font.pixelSize: Theme.fontSizeExtraLarge; glow: 10 }
                        }
                    }
                    // split bar: vault vs chips
                    Rectangle {
                        width: parent.width; height: Theme.paddingSmall; radius: height / 2
                        color: Neon.alpha(Neon.yellow, 0.6)
                        Rectangle {
                            height: parent.height; radius: parent.radius; color: Neon.cyan
                            width: parent.width * (Game.netWorth > 0 ? Game.vault / Game.netWorth : 0)
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }
                    Text {
                        text: "NET WORTH " + Money.fmt(Game.netWorth) + "  ·  vault money can't be bet and keeps your run alive"
                        width: parent.width; wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                    }
                }
            }

            SectionHeader { text: "Deposit chips" }
            Row {
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                property real w: (col.width - 2 * Theme.horizontalPageMargin - 3 * spacing) / 4
                Repeater {
                    model: [[10, "10%"], [25, "25%"], [50, "50%"], [100, "ALL"]]
                    NeonButton {
                        width: parent.w; height: Theme.itemSizeSmall
                        text: modelData[1]; color: Neon.cyan; fontSize: Theme.fontSizeSmall
                        enabled: Game.balance > 0 && !Game.slotBonus
                        onClicked: {
                            var got = Game.deposit(Math.floor(Game.balance * modelData[0]) / 100)
                            if (got > 0) Sound.play("perk")
                        }
                    }
                }
            }
            SectionHeader { text: "Withdraw to chips" }
            Row {
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                property real w: (col.width - 2 * Theme.horizontalPageMargin - 3 * spacing) / 4
                Repeater {
                    model: [[0, "MIN×10"], [25, "25%"], [50, "50%"], [100, "ALL"]]
                    NeonButton {
                        width: parent.w; height: Theme.itemSizeSmall
                        text: modelData[1]; color: Neon.yellow; fontSize: Theme.fontSizeSmall
                        enabled: Game.vault > 0
                        onClicked: {
                            var amt = modelData[0] === 0 ? Game.minBet * 10 : Math.floor(Game.vault * modelData[0]) / 100
                            if (Game.withdraw(amt) > 0) Sound.play("click")
                        }
                    }
                }
            }

            SectionHeader { text: "Auto-vault" }
            Label {
                x: Theme.horizontalPageMargin; width: col.width - 2 * x
                wrapMode: Text.Wrap; font.pixelSize: Theme.fontSizeExtraSmall; color: Theme.secondaryColor
                text: "Sweep part of every win straight into the vault."
            }
            Segmented {
                x: Theme.horizontalPageMargin; width: col.width - 2 * x
                labels: ["OFF", "10%", "25%", "50%"]
                current: [0, 10, 25, 50].indexOf(Game.autoVault)
                onPicked: { Game.autoVault = [0, 10, 25, 50][index]; Game.save() }
            }

            SectionHeader { text: "This session" }
            NeonPanel {
                x: Theme.horizontalPageMargin
                width: col.width - 2 * x
                height: sessCol.height + 2 * Theme.paddingLarge
                glowColor: Game.sessionNet >= 0 ? Neon.green : Neon.red
                Column {
                    id: sessCol
                    anchors { left: parent.left; right: parent.right; margins: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                    NeonText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (Game.sessionNet >= 0 ? "+" : "") + Money.fmt(Game.sessionNet)
                        color: Game.sessionNet >= 0 ? Neon.green : Neon.red
                        font.pixelSize: Theme.fontSizeExtraLarge
                    }
                    NeonDetail { label: "Started at"; value: Money.fmt(Game.sessionStart) }
                    NeonDetail { label: "Playing for"; value: page.duration(page.now - Game.sessionStartTime) }
                    NeonDetail { label: "Bets"; value: Game.sessionBets }
                    NeonDetail { label: "Wagered"; value: Money.fmt(Game.sessionWagered) }
                }
            }

            SectionHeader { text: "Loss limit" }
            Label {
                x: Theme.horizontalPageMargin; width: col.width - 2 * x
                wrapMode: Text.Wrap; font.pixelSize: Theme.fontSizeExtraSmall; color: Theme.secondaryColor
                text: Game.lossLimit > 0 ? "Tables lock once this session is down " + Money.fmt(Game.lossLimit) + "."
                                         : "Lock the tables when this session is down by a share of what you started with."
            }
            Segmented {
                x: Theme.horizontalPageMargin; width: col.width - 2 * x
                color: Neon.red
                labels: ["OFF", "10%", "25%", "50%"]
                property var fracs: [0, 0.1, 0.25, 0.5]
                current: Game.lossLimit > 0 ? Math.max(1, fracs.indexOf(Math.round(Game.lossLimit / Math.max(1, Game.sessionStart) * 100) / 100)) : 0
                onPicked: { Game.lossLimit = Math.round(Game.sessionStart * fracs[index] * 100) / 100; Game.save() }
            }

            SectionHeader { text: "Win goal" }
            Label {
                x: Theme.horizontalPageMargin; width: col.width - 2 * x
                wrapMode: Text.Wrap; font.pixelSize: Theme.fontSizeExtraSmall; color: Theme.secondaryColor
                text: Game.winGoal > 0 ? "You'll get a nudge to vault your winnings at +" + Money.fmt(Game.winGoal) + "."
                                       : "Get a nudge to vault your winnings once the session is up by this much."
            }
            Segmented {
                x: Theme.horizontalPageMargin; width: col.width - 2 * x
                color: Neon.green
                labels: ["OFF", "+25%", "+50%", "+100%"]
                property var fracs: [0, 0.25, 0.5, 1]
                current: Game.winGoal > 0 ? Math.max(1, fracs.indexOf(Math.round(Game.winGoal / Math.max(1, Game.sessionStart) * 100) / 100)) : 0
                onPicked: { Game.winGoal = Math.round(Game.sessionStart * fracs[index] * 100) / 100; Game.goalAnnounced = false; Game.save() }
            }

            NeonButton {
                x: Theme.horizontalPageMargin; width: col.width - 2 * x
                text: "Start a new session"
                color: Neon.violet
                onClicked: {
                    Game.newSession()
                    if (Game.lossLimit > 0 || Game.winGoal > 0) Game.note("NEW SESSION · LIMITS KEPT", Neon.violet)
                }
            }
        }
        VerticalScrollDecorator {}
    }
}
