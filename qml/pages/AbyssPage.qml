import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/AbyssConfig.js" as Config
import "../js/Abyss.js" as Abyss
import "../js/Money.js" as Money

// ABYSS: a fruit machine. Only the centre line pays. Some spins hand you NUDGES (step a reel
// down so the symbol above drops onto the line); some losing spins let you HOLD up to two reels
// for the next spin. Your calls decide the pay; the glowing keys show the best call.
// Every spin (positions + feature) is decided and saved before the reels move; while you nudge,
// Game.pending always holds the current line's pay, so quitting just collects it.
TablePage {
    id: page
    title: "Abyss"
    accent: m.color
    scene: "abyss"
    musicTrack: "abyss"
    code: "CENTRE LINE · HOLDS · NUDGES · UP TO 97% WITH BEST PLAY"
    info: "Only the centre line pays: three of a kind (the trident is wild): shell " + m.pay3.shell + "×, fish " + m.pay3.fish
          + "×, jelly " + m.pay3.jelly + "×, anchor " + m.pay3.anchor + "×, shark " + m.pay3.shark + "×, kraken " + m.pay3.kraken
          + "×, three tridents " + m.pay3.wild + "×. Pearls anywhere on the line: two " + m.pearls["2"] + "×, three " + m.pearls["3"]
          + "×. A shell on reel 1 returns your bet, two from the left pay " + m.shell2 + "×.<br><br>"
          + "NUDGES: when a nudge or two would turn a losing spin into a win, you may get them. Tap ▼ under a reel to drop the symbol above onto the line, then Collect.<br>"
          + "HOLD: after some losing spins you may hold up to two reels; they stay put on the next spin.<br>"
          + "The glowing keys show the best move. Play them all and the machine returns about 97%; ignore them and about 82%."
    footerHeight: footerCol.height + Theme.paddingLarge

    readonly property var m: Config.machine
    readonly property var reelTheme: ({ prefix: m.prefix, symbols: m.symbols, weights: { shell: 5, fish: 4, jelly: 3, anchor: 3, shark: 2, kraken: 1, wild: 1, pearl: 1 },
                                        bonus: { scatter: 0, bonusScatter: 0 } })
    property var pos: [0, 0, 0]
    property string phase: "idle"            // idle | spinning | nudge
    property int nudges: 0
    property var held: [false, false, false]
    readonly property var holdFrom: { var st = Game.slotStateFor("abyss"); return st.hold || null }
    readonly property bool holdOffer: phase === "idle" && !!holdFrom
    readonly property var holdHint: holdFrom ? Abyss.bestHold(m, holdFrom).held : [false, false, false]
    readonly property var nudgeHint: phase === "nudge" ? Abyss.bestNudge(m, pos, nudges).steps : [0, 0, 0]
    readonly property real linePay: Abyss.payAt(m, pos)
    property real stakeNow: 0
    property int reelsDone: 0
    property bool lastWin: false
    busy: phase !== "idle"

    Component.onCompleted: {
        if (holdFrom) pos = holdFrom
        for (var r = 0; r < 3; ++r) reels.itemAt(r).strip = Abyss.column(m, r, pos[r])
    }

    function spin() {
        if (phase !== "idle" || !Game.canBet(bet.bet)) return
        var stake = bet.bet
        var useHold = holdOffer && (held[0] || held[1] || held[2])
        Game.stake(stake)
        var s = Abyss.spin(m, useHold ? held : null, holdFrom)
        var p = Abyss.payAt(m, s.pos)
        var st = {}
        if (!p && s.feature.type === "hold") st.hold = s.pos          // next spin may hold
        Game.setSlotState("abyss", st)
        Game.pending = { game: "slots", staked: stake, returned: Math.round(stake * p * 100) / 100, abyss: s.pos }
        Game.save()
        stakeNow = stake
        // nudges only show up when they can make a win (a useless nudge is worth 0 anyway)
        nudges = !p && s.feature.nudges && Abyss.bestNudge(m, s.pos, s.feature.nudges).pay > 0 ? s.feature.nudges : 0
        var wasHeld = useHold ? held.slice() : [false, false, false]
        held = [false, false, false]
        pos = s.pos
        phase = "spinning"
        reelsDone = 0
        Sound.play("reel")
        for (var r = 0; r < 3; ++r) {
            if (wasHeld[r]) { reelsDone++; continue }
            reels.itemAt(r).spin(Abyss.column(m, r, s.pos[r]), 700 + r * 330)
        }
        if (reelsDone === 3) stopped()
    }
    function stopped() {
        if (phase !== "spinning") return
        if (nudges > 0) {
            phase = "nudge"
            Game.note(nudges + (nudges === 1 ? " NUDGE" : " NUDGES") + " · TAP ▼", m.color)
            Sound.play("perk"); Haptics.rumble(3)
            guard.start()
            return
        }
        finish()
    }
    function nudge(r) {
        if (phase !== "nudge" || nudges <= 0) return
        var p = pos.slice(); p[r] += 1
        pos = p
        nudges -= 1
        var pd = Game.pending                    // keep the saved result equal to what's on the line
        pd.returned = Math.round(stakeNow * Abyss.payAt(m, p) * 100) / 100
        pd.abyss = p
        Game.pending = pd
        Game.save()
        reels.itemAt(r).spin(Abyss.column(m, r, p[r]), 220)
        Sound.play("tick"); Haptics.tick()
        if (nudges === 0) collectTimer.restart()
    }
    Timer { id: collectTimer; interval: 450; onTriggered: page.finish() }
    // a hold just came up: lock Spin for 2 s so a quick tap can't spin straight past it
    property int guardLeft: 0
    Timer {
        id: guard; interval: 100; repeat: true
        onRunningChanged: if (running) page.guardLeft = 20
        onTriggered: { if (--page.guardLeft <= 0) stop() }
    }
    function finish() {
        var p = Game.pending
        if (!p) { phase = "idle"; return }
        phase = "idle"
        lastWin = p.returned > 0
        if (p.returned > p.staked) page.burst.show(p.returned - p.staked, p.returned >= p.staked * 30)
        else if (p.returned === 0) Sound.play("lose")
        if (holdFrom) { Game.note("HOLD AVAILABLE", m.color); Haptics.rumble(1); guard.start() }
        Game.settle(p.staked, p.returned, "slots")
    }

    // ---- the cabinet ----
    NeonPanel {
        id: cabinet
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: reelRow.height + 2 * Theme.paddingLarge
        glowColor: page.lastWin && page.phase === "idle" ? Neon.green : m.color
        glowStrength: page.phase === "nudge" ? 0.9 : 0.5
        strong: true
        Row {
            id: reelRow
            anchors.centerIn: parent
            spacing: Theme.paddingSmall
            Repeater {
                id: reels
                model: 3
                Reel {
                    width: (cabinet.width - 2 * Theme.paddingLarge - 2 * Theme.paddingSmall) / 3
                    cell: width
                    theme: page.reelTheme
                    onStopped: { page.reelsDone += 1; Sound.play("tick"); if (page.reelsDone === 3 && page.phase === "spinning") page.stopped() }
                    Rectangle {      // held: a frame round the reel
                        anchors.fill: parent
                        color: "transparent"
                        border { width: 4; color: Neon.yellow }
                        visible: page.held[index]
                    }
                }
            }
        }
        Rectangle {          // the pay line
            anchors.verticalCenter: reelRow.verticalCenter
            x: Theme.paddingSmall; width: parent.width - 2 * x; height: 3
            color: page.linePay > 0 && page.phase !== "spinning" ? Neon.green : Neon.alpha(m.color, 0.7)
        }
    }
    // ---- HOLD / NUDGE keys, one per reel ----
    Row {
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall
        Repeater {
            model: 3
            NeonButton {
                width: (page.width - 2 * Theme.horizontalPageMargin - 2 * Theme.paddingSmall) / 3
                height: Theme.itemSizeMedium
                readonly property bool hint: page.phase === "nudge" ? page.nudgeHint[index] > 0 : page.holdOffer && page.holdHint[index]
                visible: page.phase === "nudge" || page.holdOffer
                text: page.phase === "nudge" ? "▼ Nudge" : page.held[index] ? "Held" : "Hold"
                color: hint ? Neon.yellow : m.color
                primary: page.held[index] || hint
                fontSize: Theme.fontSizeSmall
                enabled: page.phase === "nudge" ? page.nudges > 0 : page.holdOffer && (page.held[index] || page.held.filter(function (h) { return h }).length < 2)
                onClicked: {
                    if (page.phase === "nudge") { page.nudge(index); return }
                    var h = page.held.slice(); h[index] = !h[index]; page.held = h
                    Haptics.tick()
                }
                SequentialAnimation on opacity {
                    running: parent.hint && parent.visible; loops: Animation.Infinite
                    NumberAnimation { to: 0.6; duration: 420 } NumberAnimation { to: 1; duration: 420 }
                }
            }
        }
    }
    Text {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: page.phase === "nudge" ? page.nudges + " NUDGE" + (page.nudges === 1 ? "" : "S") + " LEFT · LINE PAYS " + Money.fmt(page.stakeNow * page.linePay)
              : page.holdOffer ? "HOLD UP TO TWO REELS FOR THIS SPIN · GLOW = BEST"
              : "CENTRE LINE PAYS · WATCH FOR NUDGES AND HOLDS"
        color: page.phase === "nudge" || page.holdOffer ? Neon.yellow : Theme.secondaryColor
        font { family: Neon.mono; pixelSize: Theme.fontSizeExtraSmall; letterSpacing: 1 }
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
            text: page.guardLeft > 0 ? (page.phase === "nudge" ? "Nudge! tap ▼ under a reel · " : "Hold? choose reels · ") + Math.ceil(page.guardLeft / 10) + "…"
                  : page.phase === "nudge" ? "Collect " + Money.fmt(page.stakeNow * page.linePay)
                  : page.phase === "spinning" ? "Spinning…"
                  : (page.holdOffer && (page.held[0] || page.held[1] || page.held[2]) ? "Spin held · " : "Spin · ") + Money.fmt(bet.bet)
            color: m.color; primary: true
            fontSize: Theme.fontSizeMedium
            enabled: page.guardLeft <= 0 && (page.phase === "nudge" || (page.phase === "idle" && Game.canBet(bet.bet)))
            onClicked: page.phase === "nudge" ? page.finish() : page.spin()
        }
    }
}
