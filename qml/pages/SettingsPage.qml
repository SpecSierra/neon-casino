import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Perks.js" as Perks
import "../js/Money.js" as Money

// Settings: audio, the remembered starter perk, run controls, and the info pages.
Page {
    id: page
    objectName: "settings"
    Backdrop { accent: Neon.violet; scene: "circuit" }

    readonly property var starter: Game.starterPerk ? Perks.byId(Game.starterPerk) : null

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height + Theme.paddingLarge * 2
        Column {
            id: col
            width: parent.width
            spacing: Theme.paddingMedium
            NeonHeader { title: "Settings"; code: "AUDIO · RUNS · ABOUT"; color: Neon.violet }

            SectionHeader { text: "Audio" }
            NeonToggle { label: "Music"; description: "CC0 chiptunes, one per game"; checked: Game.music; color: Neon.violet; onToggled: { Game.music = checked; Game.save() } }
            NeonSlider { label: "Music volume"; value: Game.musicVolume; color: Neon.violet; opacity: Game.music ? 1 : 0.4; onMoved: { Game.musicVolume = value; Game.save() } }
            NeonToggle { label: "Sound effects"; description: "Reels, cards, chips and wins"; checked: Game.sound; color: Neon.cyan; onToggled: { Game.sound = checked; Game.save() } }
            NeonSlider { label: "Effects volume"; value: Game.sfxVolume; color: Neon.cyan; opacity: Game.sound ? 1 : 0.4; onMoved: { Game.sfxVolume = value; Game.save(); Sound.play("win") } }
            NeonToggle { label: "Vibration"; description: "Haptic taps on spins, wins and busts"; checked: Game.vibration; color: Neon.pink; onToggled: { Game.vibration = checked; Game.save(); Haptics.tap() } }

            SectionHeader { text: "Display" }
            Text {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                text: "Effects"
                color: "white"; font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeSmall }
            }
            Segmented {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                color: Neon.green
                labels: ["AUTO", "FULL", "LIGHT"]
                current: Game.fxMode === "full" ? 1 : Game.fxMode === "low" ? 2 : 0
                onPicked: { Game.fxMode = ["auto", "full", "low"][index]; Game.save() }
            }
            Text {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                wrapMode: Text.Wrap
                text: "Light holds the animated backgrounds still and trims the glow and sparks, for smoother play on slower phones. "
                      + (Game.measuredFps ? "This phone measured " + Game.measuredFps + " fps at start-up" + (Game.fxMode === "auto" ? ", so Auto uses " + (Game.slowDevice ? "Light." : "Full.") : ".") : "")
                color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeExtraSmall
            }

            SectionHeader { text: "Runs" }
            Item {
                width: parent.width; height: starterCol.height + Theme.paddingMedium
                Column {
                    id: starterCol
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x - (forget.visible ? forget.width + Theme.paddingMedium : 0)
                    Text { text: "Starter perk"; color: "white"; font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeSmall } }
                    Text {
                        width: parent.width; wrapMode: Text.Wrap
                        text: page.starter ? page.starter.name + " is granted at the start of every run." : "None remembered. Pick one with “remember” in a perk draft."
                        color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
                NeonButton {
                    id: forget
                    visible: !!page.starter
                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: starterCol.verticalCenter }
                    width: Theme.itemSizeExtraLarge; height: Theme.itemSizeExtraSmall
                    text: "Forget"; color: Neon.violet; fontSize: Theme.fontSizeExtraSmall
                    onClicked: { Game.starterPerk = ""; Game.save(); Game.note("STARTER PERK FORGOTTEN", Neon.violet) }
                }
            }
            NeonButton {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                visible: !Game.rebootAvailable
                text: "New run…"; color: Neon.yellow
                onClicked: pageStack.push(Qt.resolvedUrl("NewRunPage.qml"))
            }
            Text {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                visible: Game.rebootAvailable
                wrapMode: Text.Wrap
                text: "New runs are locked until you've played your REBOOT."
                color: Neon.yellow; font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall }
            }

            SectionHeader { text: "Info" }
            Grid {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                columns: 2; spacing: Theme.paddingMedium
                Repeater {
                    model: [{ t: "How to play", p: "IntroPage.qml", c: Neon.cyan }, { t: "Perk codex", p: "CodexPage.qml", c: Neon.pink },
                            { t: "Music credits", p: "CreditsPage.qml", c: Neon.violet }, { t: "About", p: "AboutPage.qml", c: Neon.green }]
                    NeonButton {
                        width: (parent.width - Theme.paddingMedium) / 2
                        text: modelData.t; color: modelData.c; fontSize: Theme.fontSizeSmall
                        onClicked: pageStack.push(Qt.resolvedUrl(modelData.p))
                    }
                }
            }
        }
        VerticalScrollDecorator {}
    }
}
