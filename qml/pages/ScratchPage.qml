import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Scratch.js" as Scratch
import "../js/Money.js" as Money

// Scratch cards: buy a ticket, rub the nine foil panels with your finger. Three matching
// amounts win that amount. The ticket is printed (and saved as Game.pending) when you buy it.
TablePage {
    id: page
    title: "Scratch"
    accent: "#FF9F14"
    scene: "circuit"
    musicTrack: "scratch"
    code: "MATCH 3 · TOP PRIZE 500× · 92% RTP"
    info: "Buy a ticket at your bet. Rub the foil off the nine panels. Three panels showing the same amount win "
          + "that amount (a ticket has at most one winning amount). Top prize is 500× the ticket. "
          + "Reveal opens the rest at once."
    footerHeight: footerCol.height + Theme.paddingLarge

    property var cells: []                    // prize values (× price) on the ticket
    property var foil: [1, 1, 1, 1, 1, 1, 1, 1, 1]   // how much foil is left per panel
    property real price: 0
    property int prize: 0
    readonly property bool live: cells.length === 9 && !done
    property bool done: false
    busy: live

    function buy() {
        if (live || !Game.canBet(bet.bet)) return
        var p = bet.bet
        Game.stake(p)
        var t = Scratch.ticket()
        Game.pending = { game: "scratch", staked: p, returned: Math.round(p * t.prize * 100) / 100 }
        Game.save()
        price = p; prize = t.prize; cells = t.cells; foil = [1, 1, 1, 1, 1, 1, 1, 1, 1]; done = false
        Sound.play("card"); Haptics.tap()
    }
    function rub(i, amount) {
        if (!live || foil[i] <= 0) return
        var f = foil.slice()
        f[i] = Math.max(0, f[i] - amount)
        if (f[i] < 0.35) f[i] = 0
        if (f[i] === 0 && foil[i] > 0) { Sound.play("tick"); Haptics.tick() }
        foil = f
        if (allOff()) finish()
    }
    function allOff() { for (var i = 0; i < 9; ++i) if (foil[i] > 0) return false; return true }
    function revealAll() { if (!live) return; foil = [0, 0, 0, 0, 0, 0, 0, 0, 0]; finish() }
    function finish() {
        if (done) return
        done = true
        var p = Game.pending
        if (!p) return
        if (p.returned > p.staked) page.burst.show(p.returned - p.staked, prize >= 50)
        else if (p.returned < p.staked) Sound.play("lose")
        if (prize) Game.note("MATCH 3 · " + prize + "×", Neon.yellow)
        Game.settle(p.staked, p.returned, "scratch")
    }
    function winning(i) { return done && prize > 0 && cells[i] === prize }

    NeonPanel {
        id: ticket
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: width * 1.08
        glowColor: page.done && page.prize ? Neon.yellow : "#FF9F14"
        glowStrength: page.live ? 0.6 : 0.3
        Column {
            anchors { fill: parent; margins: Theme.paddingLarge }
            spacing: Theme.paddingMedium
            Item {
                width: parent.width; height: brand.height
                NeonText { id: brand; text: "LUCKY CIRCUIT"; color: "#FF9F14"; font.pixelSize: Theme.fontSizeLarge }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: page.cells.length ? "TICKET " + Money.fmt(page.price) : "NO TICKET"
                    color: Theme.secondaryColor; font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall }
                }
            }
            Grid {
                id: panels
                columns: 3; spacing: Theme.paddingMedium
                width: parent.width
                readonly property real cell: (width - 2 * spacing) / 3
                Repeater {
                    model: 9
                    Item {
                        width: panels.cell; height: panels.cell * 0.82
                        Rectangle {
                            anchors.fill: parent
                            color: page.winning(index) ? Neon.alpha(Neon.yellow, 0.25) : Neon.alpha("#0A0418", 0.85)
                            border { width: page.winning(index) ? 3 : 1; color: page.winning(index) ? Neon.yellow : Neon.alpha("#FF9F14", 0.5) }
                        }
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - Theme.paddingSmall * 2
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.HorizontalFit; minimumPixelSize: Theme.fontSizeTiny
                            visible: page.cells.length === 9
                            text: page.cells.length === 9 ? Money.fmt(page.cells[index] * page.price) : ""
                            color: page.winning(index) ? Neon.yellow : "white"
                            font { family: Neon.mono; bold: true; pixelSize: Theme.fontSizeMedium }
                        }
                        // the foil
                        Rectangle {
                            anchors.fill: parent
                            visible: page.foil[index] > 0
                            opacity: page.cells.length ? Math.min(1, 0.25 + page.foil[index]) : 1
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#C9C3D6" }
                                GradientStop { position: 0.5; color: "#8E879E" }
                                GradientStop { position: 1; color: "#B8B1C8" }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "¤"
                                color: Neon.alpha("#2A2238", 0.6)
                                font { family: Neon.display; bold: true; pixelSize: Theme.fontSizeLarge }
                            }
                        }
                    }
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: !page.cells.length ? "BUY A TICKET, THEN RUB THE FOIL"
                      : page.live ? "RUB THE FOIL · MATCH 3 TO WIN"
                      : page.prize ? "WINNER · " + Money.fmt(page.prize * page.price) : "NO MATCH · TRY ANOTHER"
                color: page.done && page.prize ? Neon.yellow : Theme.secondaryColor
                font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall; letterSpacing: 1 }
            }
        }
        // rubbing: every bit of finger travel over a panel wipes some foil
        MouseArea {
            anchors.fill: parent
            enabled: page.live
            preventStealing: true
            property real lx; property real ly
            onPressed: { lx = mouse.x; ly = mouse.y }
            onPositionChanged: {
                var d = Math.sqrt((mouse.x - lx) * (mouse.x - lx) + (mouse.y - ly) * (mouse.y - ly))
                lx = mouse.x; ly = mouse.y
                var p = mapToItem(panels, mouse.x, mouse.y)
                var c = Math.floor(p.x / (panels.cell + panels.spacing)), r = Math.floor(p.y / (panels.cell * 0.82 + panels.spacing))
                if (c < 0 || c > 2 || r < 0 || r > 2) return
                page.rub(r * 3 + c, d / (panels.cell * 2.2))
            }
        }
    }

    footer: Column {
        id: footerCol
        width: parent.width
        spacing: Theme.paddingMedium
        BetSelector { id: bet; width: parent.width; locked: page.busy; color: Neon.yellow }
        NeonButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            height: Theme.itemSizeMedium
            text: page.live ? "Reveal all" : "Buy ticket " + Money.fmt(bet.bet)
            color: "#FF9F14"; primary: true
            fontSize: Theme.fontSizeLarge
            enabled: page.live || Game.canBet(bet.bet)
            onClicked: page.live ? page.revealAll() : page.buy()
        }
    }
}
