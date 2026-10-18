import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/Money.js" as Money
import "../js/Perks.js" as Perks

Page {
    id: page
    property bool lifetime: false
    readonly property var s: lifetime ? Game.stats : Game.runStats
    readonly property var games: [
        { key: "slots", name: "NEON SLOTS", color: Neon.pink, icon: "sym-seven" },
        { key: "blackjack", name: "BLACKJACK", color: Neon.cyan, icon: "suit-spades" },
        { key: "roulette", name: "ROULETTE", color: Neon.red, icon: "sym-chip" },
        { key: "overload", name: "OVERLOAD", color: Neon.yellow, icon: "sym-overload" },
        { key: "poker", name: "VIDEO POKER", color: Neon.violet, icon: "sym-poker" },
        { key: "baccarat", name: "BACCARAT", color: "#FFC828", icon: "sym-baccarat" },
        { key: "craps", name: "CRAPS", color: Neon.green, icon: "sym-craps" },
        { key: "keno", name: "KENO", color: Neon.pink, icon: "sym-keno" },
        { key: "mines", name: "MINES", color: Neon.red, icon: "sym-mines" },
        { key: "plinko", name: "PLINKO", color: Neon.cyan, icon: "sym-plinko" },
        { key: "sicbo", name: "SIC BO", color: "#FF9F14", icon: "sym-sicbo" },
        { key: "hilo", name: "HI-LO", color: Neon.green, icon: "sym-hilo" },
        { key: "wheel", name: "MONEY WHEEL", color: Neon.yellow, icon: "sym-wheel" },
        { key: "scratch", name: "SCRATCH", color: "#FF9F14", icon: "sym-scratch" },
        { key: "coinflip", name: "COIN FLIP", color: Neon.yellow, icon: "sym-coinflip" },
        { key: "dice", name: "DICE", color: Neon.cyan, icon: "sym-dice" },
        { key: "tower", name: "TOWER", color: Neon.violet, icon: "sym-tower" },
        { key: "rps", name: "ROCK PAPER SCISSORS", color: Neon.pink, icon: "sym-rps" },
        { key: "war", name: "CARD WAR", color: Neon.red, icon: "sym-war" },
        { key: "race", name: "DRONE RACE", color: Neon.green, icon: "sym-race" },
        { key: "penalty", name: "PENALTY", color: Neon.green, icon: "sym-penalty" },
        { key: "reddog", name: "RED DOG", color: Neon.red, icon: "sym-reddog" },
        { key: "balloon", name: "BALLOON", color: Neon.pink, icon: "sym-balloon" },
        { key: "darts", name: "DARTS", color: Neon.cyan, icon: "sym-darts" },
        { key: "claw", name: "CLAW MACHINE", color: Neon.yellow, icon: "sym-claw" },
        { key: "chests", name: "TREASURE CHESTS", color: "#FF9F14", icon: "sym-chest" }
    ]
    function total(field) {
        var t = 0
        for (var i = 0; i < games.length; ++i) if (s[games[i].key]) t += s[games[i].key][field]
        return t
    }
    function pct(a, b) { return b > 0 ? (100 * a / b).toFixed(1) + "%" : "—" }
    function signed(v) { return (v >= 0 ? "+" : "−") + Money.fmt(Math.abs(v)) }
    function ex(k) { return s.extra[k] || 0 }

    Backdrop { accent: Neon.green }
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height + Theme.paddingLarge
        Column {
            id: col
            width: parent.width
            spacing: Theme.paddingMedium
            NeonHeader { title: "Stats"; code: page.lifetime ? "ALL RUNS" : "RUN #" + Game.runs; color: Neon.green }

            Segmented {
                x: Theme.horizontalPageMargin; width: col.width - 2 * x
                color: Neon.green
                labels: ["THIS RUN", "LIFETIME"]
                current: page.lifetime ? 1 : 0
                onPicked: page.lifetime = index === 1
            }

            // headline numbers
            Grid {
                x: Theme.horizontalPageMargin
                width: col.width - 2 * x
                columns: 2
                spacing: Theme.paddingMedium
                Repeater {
                    model: [
                        ["WAGERED", Money.fmt(page.total("wagered")), Neon.yellow],
                        ["NET", page.signed(page.total("returned") - page.total("wagered")),
                            page.total("returned") >= page.total("wagered") ? Neon.green : Neon.red],
                        ["PAYBACK", page.pct(page.total("returned"), page.total("wagered")), Neon.cyan],
                        ["WIN RATE", page.pct(page.total("wins"), page.total("bets")), Neon.violet],
                        [page.lifetime ? "BEST PEAK" : "PEAK", Money.fmt(page.lifetime ? Game.bestPeak : Game.peak), Neon.pink],
                        ["BIGGEST WIN", Money.fmt(page.lifetime ? Game.biggestWin : Game.runBiggestWin), Neon.green]
                    ]
                    NeonPanel {
                        width: (col.width - 2 * Theme.horizontalPageMargin - Theme.paddingMedium) / 2
                        height: Theme.itemSizeMedium
                        glowColor: modelData[2]; glowStrength: 0.3
                        Column {
                            anchors.centerIn: parent
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData[0]; color: Neon.alpha(modelData[2], 0.75)
                                font { pixelSize: Theme.fontSizeTiny; letterSpacing: 2; family: Neon.display }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData[1]; color: Qt.lighter(modelData[2], 1.2)
                                font { pixelSize: Theme.fontSizeMedium; bold: true; family: Neon.display }
                            }
                        }
                    }
                }
            }

            // run chart
            SectionHeader { text: "Net worth this run"; visible: !page.lifetime }
            NeonPanel {
                visible: !page.lifetime
                x: Theme.horizontalPageMargin
                width: col.width - 2 * x
                height: Theme.itemSizeExtraLarge * 1.4
                glowColor: Neon.cyan; glowStrength: 0.3
                TraceChart {
                    anchors { fill: parent; margins: Theme.paddingSmall }
                    values: Game.trace
                }
                Text {
                    anchors { right: parent.right; top: parent.top; margins: Theme.paddingMedium }
                    text: Game.bets + " BETS · NOW " + Money.fmt(Game.netWorth)
                    color: Neon.alpha(Neon.cyan, 0.8)
                    font { pixelSize: Theme.fontSizeTiny; letterSpacing: 1; family: Neon.display }
                }
            }

            // per game
            SectionHeader { text: "By table" }
            Repeater {
                model: page.games
                NeonPanel {
                    id: gp
                    readonly property var g: page.s[modelData.key] || { bets: 0, wagered: 0, returned: 0, wins: 0, biggest: 0 }
                    x: Theme.horizontalPageMargin
                    width: col.width - 2 * x
                    height: gcol.height + 2 * Theme.paddingMedium
                    glowColor: modelData.color; glowStrength: 0.35
                    Image {
                        anchors { right: parent.right; top: parent.top; margins: Theme.paddingMedium }
                        width: Theme.iconSizeMedium; height: width; opacity: 0.8
                        source: "../images/" + modelData.icon + ".png"
                    }
                    Column {
                        id: gcol
                        anchors { left: parent.left; right: parent.right; margins: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
                        Text {
                            text: modelData.name; color: Qt.lighter(modelData.color, 1.2)
                            font { pixelSize: Theme.fontSizeMedium; bold: true; letterSpacing: 2; family: Neon.display }
                        }
                        Text {
                            text: gp.g.bets + " bets · " + page.pct(gp.g.wins, gp.g.bets) + " won"
                            color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeExtraSmall
                        }
                        Item { width: 1; height: Theme.paddingSmall }
                        Row {
                            width: parent.width
                            Repeater {
                                model: [
                                    ["WAGERED", Money.fmt(gp.g.wagered)],
                                    ["PAID", Money.fmt(gp.g.returned)],
                                    ["NET", page.signed(gp.g.returned - gp.g.wagered)],
                                    ["PAYBACK", page.pct(gp.g.returned, gp.g.wagered)]
                                ]
                                Column {
                                    width: parent.width / 4
                                    Text {
                                        text: modelData[0]; color: Neon.alpha(Neon.cyan, 0.6)
                                        font { pixelSize: Theme.fontSizeTiny; letterSpacing: 1; family: Neon.display }
                                    }
                                    Text {
                                        width: parent.width; elide: Text.ElideRight
                                        text: modelData[1]
                                        color: index === 2 ? (gp.g.returned >= gp.g.wagered ? Neon.green : Neon.red) : "white"
                                        font { pixelSize: Theme.fontSizeSmall; bold: true; family: Neon.display }
                                    }
                                }
                            }
                        }
                        Text {
                            visible: gp.g.biggest > 0
                            text: "Biggest win " + Money.fmt(gp.g.biggest)
                            color: Theme.secondaryHighlightColor; font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }

            SectionHeader { text: "Highlights" }
            Column {
                width: parent.width
                NeonDetail { label: "Free-spin bonuses"; value: page.ex("bonuses") }
                NeonDetail { label: "Retriggers"; value: page.ex("retriggers") }
                NeonDetail { label: "Best multiplier"; value: page.ex("bestMultiplier") ? "×" + page.ex("bestMultiplier") : "—" }
                NeonDetail { label: "Best bonus"; value: page.ex("bestBonusX") ? page.ex("bestBonusX") + "× bet" : "—" }
                NeonDetail { label: "Max wins"; value: page.ex("maxWins") }
                NeonDetail { label: "Blackjack hands"; value: page.ex("hands") }
                NeonDetail { label: "Blackjacks"; value: page.ex("blackjacks") }
                NeonDetail { label: "Splits · doubles"; value: page.ex("splits") + " · " + page.ex("doubles") }
                NeonDetail { label: "Insurance taken"; value: page.ex("insurance") }
                NeonDetail { label: "Straight-up hits"; value: page.ex("straightHits") }
                NeonDetail { label: "Zeros seen"; value: page.ex("zeros") }
                NeonDetail { label: "Longest chain"; value: page.ex("longestChain") || "—" }
                NeonDetail { label: "Best Overload cash-out"; value: page.ex("bestCashout") ? page.ex("bestCashout").toFixed(2) + "×" : "—" }
                NeonDetail { label: "Overloads"; value: page.ex("overloads") }
                NeonDetail { label: "Bonuses bought"; value: page.ex("bonusBuys") }
            }

            SectionHeader { text: "Lifetime"; visible: page.lifetime }
            Column {
                visible: page.lifetime
                width: parent.width
                NeonDetail { label: "Runs"; value: Game.runs }
                NeonDetail { label: "Bets"; value: Game.totalBets }
                NeonDetail { label: "Perks unlocked"; value: Perks.unlocked(Game.lifetimeWagered).length + " / " + Perks.all.length }
            }

            SectionHeader { text: "Past runs"; visible: page.lifetime && Game.history.length > 0 }
            Repeater {
                model: page.lifetime ? Game.history : []
                Item {
                    x: Theme.horizontalPageMargin
                    width: col.width - 2 * x
                    height: Theme.itemSizeExtraSmall
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "#" + modelData.run + (modelData.start && modelData.start !== 100 ? " (custom " + Money.fmt(modelData.start) + ")" : "")
                              + "  ·  tier " + modelData.tier + "  ·  " + modelData.bets + " bets"
                        color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeExtraSmall
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: Money.fmt(modelData.peak)
                        color: modelData.peak >= Game.bestPeak ? Neon.yellow : Neon.pink
                        font { pixelSize: Theme.fontSizeSmall; bold: true; family: Neon.display }
                    }
                }
            }
            Label {
                x: Theme.horizontalPageMargin; width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: "\nPlay money only. Neon Casino counts in neon credits (¤): no real-money gambling and nothing to buy."
            }
        }
        VerticalScrollDecorator {}
    }
}
