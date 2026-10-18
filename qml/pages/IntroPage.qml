import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

// First-launch intro (also under Settings > How to play): six swipeable cards.
Page {
    id: page
    objectName: "intro"
    backNavigation: Game.introSeen          // the first time, finish (or skip) it with the buttons
    Backdrop { accent: Neon.cyan; scene: "lobby" }
    onStatusChanged: if (status === PageStatus.Active) Music.track = "lobby"

    readonly property var slides: [
        { title: "Welcome to Neon Casino", icon: "sym-seven", color: Neon.pink,
          text: "A casino roguelike. Every run starts with ¤100 neon credits. Play anything you like and see how high you can climb before the money runs out." },
        { title: "Climb the tiers", icon: "sym-chip", color: Neon.yellow,
          text: "Each tier you reach (¤250, ¤500, ¤1,000 …) raises the minimum bet and lets you draft a perk for this run. Wager more over all your runs to unlock new perks and machines." },
        { title: "35 games", icon: "sym-wheel", color: Neon.cyan,
          text: "10 slot machines, 10 table games and 15 mini games, plus three progressive jackpots that can drop on any bet. Tap ? on any game for its rules and odds." },
        { title: "Bank your wins", icon: "sym-heist-vault", color: Neon.green,
          text: "The Vault keeps credits out of play. Set a loss limit or a win goal for a session, and check Stats to see how every game is treating you." },
        { title: "Broke? Reboot", icon: "sym-overload", color: Neon.red,
          text: "Drop below the minimum bet and the run ends, unless you beat a REBOOT mini-game: Drone or Firewall, one try. Clear it to keep going; fail and it's a new run." },
        { title: "Fair and final", icon: "sym-chest", color: "#FF9F14",
          text: "Every result is decided and saved before it's shown: quitting never undoes a loss. It's all play money: nothing to buy, nothing to cash out. Have fun!" }
    ]
    function finish() {
        if (!Game.introSeen) { Game.introSeen = true; Game.save() }
        Sound.play("perk")
        pageStack.pop()
    }

    ListView {
        id: deck
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: controls.top }
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        boundsBehavior: Flickable.StopAtBounds
        // Next slides one card in 300 ms (the default is 400 px/s: ~2.5 s per card on a phone)
        highlightMoveDuration: 300
        highlightMoveVelocity: -1
        cacheBuffer: width * 6                 // build every card up front: no hitch as one slides in
        model: page.slides
        clip: true
        delegate: Item {
            width: deck.width; height: deck.height
            Column {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.horizontalPageMargin * 1.5 }
                spacing: Theme.paddingLarge * 1.5
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Theme.itemSizeHuge * 1.4; height: width
                    source: "../images/" + modelData.icon + ".png"
                    sourceSize { width: 256; height: 256 }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: modelData.title.toUpperCase()
                    color: modelData.color
                    font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeExtraLarge }
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: modelData.text
                    font.pixelSize: Theme.fontSizeMedium
                    lineHeight: 1.15
                }
            }
        }
    }
    Column {
        id: controls
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: Theme.paddingLarge * 2 }
        spacing: Theme.paddingLarge
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingMedium
            Repeater {
                model: page.slides.length
                Rectangle {
                    width: index === deck.currentIndex ? Theme.paddingLarge * 2 : Theme.paddingMedium; height: Theme.paddingMedium
                    radius: height / 2
                    color: index === deck.currentIndex ? page.slides[deck.currentIndex].color : Neon.alpha("white", 0.3)
                    Behavior on width { NumberAnimation { duration: 160 } }
                }
            }
        }
        Row {
            x: Theme.horizontalPageMargin
            spacing: Theme.paddingMedium
            NeonButton {
                width: (page.width - 2 * Theme.horizontalPageMargin - Theme.paddingMedium) * 0.35
                height: Theme.itemSizeMedium
                text: "Skip"; color: Neon.violet
                visible: deck.currentIndex < page.slides.length - 1
                onClicked: page.finish()
            }
            NeonButton {
                width: (page.width - 2 * Theme.horizontalPageMargin - Theme.paddingMedium) * (deck.currentIndex < page.slides.length - 1 ? 0.65 : 1) + (deck.currentIndex < page.slides.length - 1 ? 0 : Theme.paddingMedium)
                height: Theme.itemSizeMedium
                text: deck.currentIndex < page.slides.length - 1 ? "Next" : "Start playing"
                color: page.slides[deck.currentIndex].color; primary: true
                fontSize: Theme.fontSizeLarge
                onClicked: deck.currentIndex < page.slides.length - 1 ? deck.incrementCurrentIndex() : page.finish()
            }
        }
    }
}
