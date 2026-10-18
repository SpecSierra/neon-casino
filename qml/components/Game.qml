pragma Singleton
import QtQuick 2.6
import "../js/Storage.js" as Storage
import "../js/Money.js" as Money
import "../js/Perks.js" as Perks
import "../js/SlotThemes.js" as SlotThemes
import "."

// The whole save: one run in progress, the vault, the session, and lifetime progress.
QtObject {
    id: game

    // ---- run ----
    property real balance: 100          // chips you can bet
    property real vault: 0              // set aside: can't be bet, survives going broke
    readonly property real netWorth: round2(balance + vault)
    property real peak: 100             // of netWorth
    property int tier: 0
    property var perks: []
    property int pendingDrafts: 0
    property int bets: 0
    property real runBiggestWin: 0
    property bool secondWindUsed: false
    property bool firewallCharged: true
    property bool runOver: false
    // REBOOT mini-game: one attempt per bust; each success makes the next one longer
    property int reboots: 0
    property bool rebootAvailable: false
    readonly property int rebootGates: 8 + 3 * reboots
    readonly property real rebootAmount: Math.max(startAmount, minBet * 5)
    // Free spins in progress: { bet, spins, level, won, played }. The trigger stake is only
    // settled when the bonus ends, so a bonus can't bust you halfway.
    property var slotBonus: null
    // Per-machine base-game feature state that carries between spins: { hacker: { combo }, sunset: { fuel, turbo } }
    property var slotState: ({})
    // A round whose result is already decided but not yet shown: { game, staked, returned, … }.
    // Saved before any animation, settled on the next launch if the app was closed mid-round.
    property var pending: null
    // Several decided-but-not-shown rounds at once (Plinko balls in flight): [{ id, game, staked, returned }]
    property var pendingList: []
    // Snapshot of an open blackjack round (shoe included), saved after every card.
    property var blackjack: null
    // Open video-poker hand: { phase, deck, hand, held, stake, win, double }
    property var poker: null
    // Open Mines round: { mines, bombs: [cells], picked: [cells], stake }
    property var mines: null
    // Open Hi-Lo round: { stake, mult, card, next (already drawn), steps }
    property var hilo: null
    // Open Tower climb: { stake, risk, traps: [[cols] per floor], floor, picks: [col per floor] }
    property var tower: null
    // Open PIXEL ARCADE card (js/Arcade.js state), decided in full at purchase
    property var arcade: null
    // Open Balloon round: { stake, pops (safe pumps before it bursts), pumps }
    property var balloon: null
    // Craps table: { point, table: { bet: stake } }; stakes on it are already off the balance
    property var craps: null
    readonly property real crapsOnTable: {
        var t = 0
        if (craps && craps.table) for (var k in craps.table) t += craps.table[k]
        return t
    }
    property var runStats: emptyStats()
    property var trace: [100]           // net worth after each bet, for the run chart

    // ---- session (since the app was opened, or since "new session") ----
    property real sessionStart: 100     // net worth when the session began
    property real sessionStartTime: Date.now()
    property int sessionBets: 0
    property real sessionWagered: 0
    readonly property real sessionNet: round2(netWorth - sessionStart)
    property bool goalAnnounced: false

    // ---- settings (persist) ----
    property int autoVault: 0           // % of each net win swept into the vault
    property real lossLimit: 0          // 0 = off
    property real winGoal: 0            // 0 = off
    property bool sound: true
    property bool vibration: true
    property string starterPerk: ""     // remembered starter pick: granted at the start of each run
    property bool music: true
    property real musicVolume: 0.9      // Settings sliders, 0..1
    property real sfxVolume: 1.0
    property bool introSeen: false      // the first-launch intro has been shown
    // Visual effects: "auto" picks light mode when the startup frame-rate probe finds a slow
    // phone (slowDevice); "full" / "low" force it. lowFx stills the backdrops, drops the text
    // ghosts and trims the win bursts.
    property string fxMode: "auto"
    property bool slowDevice: false
    property int measuredFps: 0
    readonly property bool lowFx: fxMode === "low" || (fxMode === "auto" && slowDevice)
    readonly property bool sessionLocked: lossLimit > 0 && sessionNet <= -lossLimit

    // ---- lifetime ----
    property real lifetimeWagered: 0
    property real bestPeak: 100
    property int runs: 0
    property int totalBets: 0
    property real biggestWin: 0
    property var stats: emptyStats()
    property var history: []            // finished runs, newest first: { run, peak, tier, bets, wagered, end }

    // custom runs start with any amount; tiers and minimum bets scale with it
    property real startAmount: 100
    readonly property bool custom: startAmount !== 100
    readonly property real scale: startAmount / 100
    readonly property real minBet: Money.minBet(tier, scale)
    readonly property real nextTierAt: Money.tierThreshold(tier + 1, scale)
    readonly property var nextUnlock: {
        var w = lifetimeWagered
        var locked = Perks.all.filter(function (p) { return p.unlock > w })
        return locked.length ? locked[0] : null
    }

    signal tierUp(int tier)
    signal jackpot(string name, real amount)

    // ---- progressive jackpots ----
    // Three pools, seeded from the minimum bet and grown by every bet (house-funded). A bet of
    // `amount` drops a pool with chance edge × amount / pool, so each pool adds `edge` to the
    // return of every game whatever its size (≈ +1.9% in all). Rolled inside stake(), i.e.
    // decided and saved before any round animates.
    readonly property var jackpotTiers: [
        { id: "grand", name: "GRAND", seed: 2500, grow: 0.010, edge: 0.004, color: "#FF3355" },
        { id: "major", name: "MAJOR", seed: 250, grow: 0.006, edge: 0.005, color: "#F8FF3A" },
        { id: "mini", name: "MINI", seed: 15, grow: 0.004, edge: 0.010, color: "#00F0FF" }
    ]
    property var jackpots: ({})
    function jackpotSeed(t) { return round2(t.seed * minBet) }
    function jackpotValue(id) {
        for (var i = 0; i < jackpotTiers.length; ++i) if (jackpotTiers[i].id === id) return Math.max(jackpots[id] || 0, jackpotSeed(jackpotTiers[i]))
        return 0
    }
    function rollJackpot(amount) {
        var j = {}, hit = null, i, t
        for (i = 0; i < jackpotTiers.length; ++i) { t = jackpotTiers[i]; j[t.id] = Math.max(jackpots[t.id] || 0, jackpotSeed(t)) }
        for (i = 0; i < jackpotTiers.length && !hit; ++i) {
            t = jackpotTiers[i]
            if (Math.random() < Math.min(0.5, t.edge * amount / j[t.id])) hit = { tier: t, amount: j[t.id] }
        }
        for (i = 0; i < jackpotTiers.length; ++i) { t = jackpotTiers[i]; j[t.id] = round2(j[t.id] + amount * t.grow) }
        if (hit) j[hit.tier.id] = jackpotSeed(hit.tier)
        jackpots = j
        return hit
    }
    signal busted()
    signal gameOverRequested()             // the player has seen the losing round and taps on
    property var lastRound: null           // { game, staked, returned } of the latest settled round
    signal note(string text, color color)   // short toast for perk / vault events

    onSoundChanged: Sound.enabled = sound
    onVibrationChanged: Haptics.enabled = vibration
    onMusicChanged: Music.enabled = music
    onMusicVolumeChanged: Music.level = musicVolume
    onSfxVolumeChanged: Sound.master = sfxVolume

    function emptyStats() {
        function g() { return { bets: 0, wagered: 0, returned: 0, wins: 0, biggest: 0 } }
        return { slots: g(), blackjack: g(), roulette: g(), overload: g(), poker: g(), baccarat: g(), craps: g(), keno: g(), mines: g(), plinko: g(), sicbo: g(), hilo: g(), wheel: g(), scratch: g(), coinflip: g(), dice: g(), tower: g(), rps: g(), war: g(), race: g(), penalty: g(), reddog: g(), balloon: g(), darts: g(), claw: g(), chests: g(), extra: {} }
    }
    // saves from older versions lack the newer games
    function withAllGames(s) {
        var e = emptyStats(), out = copyStats(s)
        for (var k in e) if (out[k] === undefined) out[k] = e[k]
        return out
    }
    function hasPerk(id) { return perks.indexOf(id) >= 0 }
    function canBet(amount) {
        return canBetMulti(amount) && pendingList.length === 0
    }
    // for games that run several rounds at once (Plinko): other pending balls don't block
    function canBetMulti(amount) {
        return !runOver && !sessionLocked && !pending && !blackjack && !poker && !mines && !hilo && !tower && !arcade && !balloon && !slotBonus && crapsOnTable === 0
               && amount >= minBet && amount <= balance + 1e-9
    }

    function load() {
        var m = Storage.load("meta", null)
        if (m) {
            lifetimeWagered = m.lifetimeWagered; bestPeak = m.bestPeak; runs = m.runs
            totalBets = m.totalBets; biggestWin = m.biggestWin
            sound = m.sound !== false
            vibration = m.vibration !== false
            music = m.music !== false
            starterPerk = m.starterPerk || ""
            musicVolume = m.musicVolume !== undefined ? m.musicVolume : 0.9
            sfxVolume = m.sfxVolume !== undefined ? m.sfxVolume : 1.0
            introSeen = !!m.introSeen
            fxMode = m.fxMode || "auto"
            autoVault = m.autoVault || 0; lossLimit = m.lossLimit || 0; winGoal = m.winGoal || 0
            stats = m.stats || emptyStats()
            stats = withAllGames(stats)
            history = m.history || []
        }
        var r = Storage.load("run", null)
        if (r && (!r.runOver || r.rebootAvailable)) {     // a bust with an unused REBOOT comes back too
            startAmount = r.startAmount || 100
            balance = r.balance; vault = r.vault || 0; peak = r.peak; tier = r.tier; perks = r.perks
            pendingDrafts = r.pendingDrafts; bets = r.bets; runBiggestWin = r.runBiggestWin
            secondWindUsed = r.secondWindUsed; firewallCharged = r.firewallCharged
            runOver = !!r.runOver
            rebootAvailable = !!r.rebootAvailable
            reboots = r.reboots || 0
            slotBonus = r.slotBonus || null
            slotState = r.slotState || {}
            pending = r.pending || null
            pendingList = r.pendingList || []
            blackjack = r.blackjack || null
            poker = r.poker || null
            craps = r.craps || null
            mines = r.mines || null
            hilo = r.hilo || null
            tower = r.tower || null
            arcade = r.arcade || null
            balloon = r.balloon || null
            jackpots = r.jackpots || {}
            runStats = r.runStats || emptyStats()
            runStats = withAllGames(runStats)
            trace = r.trace || [netWorth]
        } else {
            newRun()
        }
        newSession()
        Sound.enabled = sound
        Haptics.enabled = vibration
        Music.enabled = music
        Music.level = musicVolume
        Sound.master = sfxVolume
        resolvePending()
    }
    // App was closed while a spin was animating: apply the result it already had.
    function addPending(round) { var l = pendingList.slice(); l.push(round); pendingList = l; save() }
    function takePending(id) {
        var l = pendingList.slice(), hit = null
        for (var i = 0; i < l.length; ++i) if (l[i].id === id) { hit = l.splice(i, 1)[0]; break }
        pendingList = l
        return hit
    }
    function resolvePending() {
        while (pendingList.length) {          // balls that were still falling when the app closed
            var b = takePending(pendingList[0].id)
            settle(b.staked, b.returned, b.game)
        }
        var p = pending
        if (!p) return
        if (p.game === "slots" && p.scatter) { startSlotBonus(); note("FREE SPINS WAITING", "#FF9F14"); return }
        note("UNFINISHED " + p.game.toUpperCase() + " ROUND " + (p.returned > p.staked ? "+" + Money.fmt(p.returned - p.staked)
                                                                   : "−" + Money.fmt(p.staked - p.returned)), Neon.violet)
        settle(p.staked, p.returned, p.game)
    }
    function slotStateFor(id) {
        var s = slotState[id] || { combo: 1, fuel: 0, turbo: false }
        return JSON.parse(JSON.stringify(s))
    }
    function setSlotState(id, st) {
        var all = JSON.parse(JSON.stringify(slotState)); all[id] = st; slotState = all
    }
    function startSlotBonus() {
        var p = pending
        // bet = total bet per spin; free spins replay the same lines
        var tb = SlotThemes.byId(p.theme || "classic").bonus
        slotBonus = { bet: p.staked, lines: p.lines || 5, theme: p.theme || "classic", spins: tb.spins, level: 0,
                      played: 0, won: p.returned + p.staked * tb.scatterPay }
        pending = null
        count("bonuses")
        save()
    }

    function save() {
        Storage.save("meta", { lifetimeWagered: lifetimeWagered, bestPeak: bestPeak, runs: runs,
                               totalBets: totalBets, biggestWin: biggestWin, sound: sound, vibration: vibration, music: music, starterPerk: starterPerk,
                               musicVolume: musicVolume, sfxVolume: sfxVolume, introSeen: introSeen, fxMode: fxMode,
                               autoVault: autoVault, lossLimit: lossLimit, winGoal: winGoal,
                               stats: stats, history: history })
        Storage.save("run", { startAmount: startAmount, reboots: reboots, rebootAvailable: rebootAvailable, balance: balance, vault: vault, peak: peak, tier: tier, perks: perks,
                              pendingDrafts: pendingDrafts, bets: bets, runBiggestWin: runBiggestWin,
                              secondWindUsed: secondWindUsed, firewallCharged: firewallCharged,
                              runOver: runOver, slotBonus: slotBonus, slotState: slotState, pending: pending, pendingList: pendingList, blackjack: blackjack, poker: poker, craps: craps, mines: mines, hilo: hilo, tower: tower, arcade: arcade, balloon: balloon, jackpots: jackpots,
                              runStats: runStats, trace: trace })
    }

    function newRun(amount) {
        startAmount = amount && amount > 0 ? Math.round(amount) : 100
        balance = startAmount; vault = 0; peak = startAmount; tier = 0; perks = []
        pendingDrafts = 1                // every run opens with a starter perk …
        var fav = starterPerk ? Perks.byId(starterPerk) : null
        if (fav && fav.unlock <= lifetimeWagered) {      // … unless one is remembered
            perks = [fav.id]
            pendingDrafts = 0
            note("STARTER PERK · " + fav.name.toUpperCase(), fav.color)
        }
        bets = 0; runBiggestWin = 0; secondWindUsed = false; firewallCharged = true; runOver = false
        reboots = 0; rebootAvailable = false
        slotBonus = null; pending = null; pendingList = []; blackjack = null; poker = null; craps = null; mines = null; hilo = null; tower = null; arcade = null; balloon = null; jackpots = ({}); slotState = {}
        runStats = emptyStats()
        trace = [startAmount]
        runs += 1
        newSession()
        save()
    }
    function newSession() {
        sessionStart = netWorth; sessionStartTime = Date.now()
        sessionBets = 0; sessionWagered = 0; goalAnnounced = false
    }
    function endRun(quiet) {
        runOver = true
        rebootAvailable = !quiet            // a bust (not a cash-out) earns one REBOOT attempt
        var h = history.slice()
        h.unshift({ run: runs, peak: peak, tier: tier, bets: bets, start: startAmount,
                    wagered: runStats.slots.wagered + runStats.blackjack.wagered + runStats.roulette.wagered
                             + (runStats.overload ? runStats.overload.wagered : 0)
                             + (runStats.poker ? runStats.poker.wagered : 0) + (runStats.baccarat ? runStats.baccarat.wagered : 0)
                             + (runStats.craps ? runStats.craps.wagered : 0) + (runStats.keno ? runStats.keno.wagered : 0)
                             + (runStats.mines ? runStats.mines.wagered : 0) + (runStats.plinko ? runStats.plinko.wagered : 0)
                             + (runStats.sicbo ? runStats.sicbo.wagered : 0) + (runStats.hilo ? runStats.hilo.wagered : 0)
                             + (runStats.wheel ? runStats.wheel.wagered : 0) + (runStats.scratch ? runStats.scratch.wagered : 0)
                             + (runStats.coinflip ? runStats.coinflip.wagered : 0) + (runStats.dice ? runStats.dice.wagered : 0)
                             + (runStats.tower ? runStats.tower.wagered : 0) + (runStats.rps ? runStats.rps.wagered : 0)
                             + (runStats.war ? runStats.war.wagered : 0) + (runStats.race ? runStats.race.wagered : 0)
                             + (runStats.penalty ? runStats.penalty.wagered : 0) + (runStats.reddog ? runStats.reddog.wagered : 0)
                             + (runStats.balloon ? runStats.balloon.wagered : 0) + (runStats.darts ? runStats.darts.wagered : 0)
                             + (runStats.claw ? runStats.claw.wagered : 0) + (runStats.chests ? runStats.chests.wagered : 0),
                    end: Date.now() })
        history = h.slice(0, 30)
        save()
        if (!quiet) busted()
    }

    // ---- vault ----
    function deposit(amount) {
        amount = round2(Math.min(amount, balance))
        if (amount <= 0 || slotBonus) return 0
        balance = round2(balance - amount); vault = round2(vault + amount)
        save()
        return amount
    }
    function withdraw(amount) {
        amount = round2(Math.min(amount, vault))
        if (amount <= 0) return 0
        vault = round2(vault - amount); balance = round2(balance + amount)
        save()
        return amount
    }

    // ---- betting ----
    // Take money off the table when a bet (or a double-down) is placed. Saved at once,
    // so quitting mid-hand can't undo a loss.
    function stake(amount) {
        if (amount > balance + 1e-9) return false
        balance = round2(balance - amount)
        lifetimeWagered += amount / scale          // custom runs unlock things at the normal pace
        sessionWagered += amount
        var jp = rollJackpot(amount)
        if (jp) {
            balance = round2(balance + jp.amount)
            peak = Math.max(peak, netWorth)
            count("jackpots")
            best("biggestJackpot", jp.amount)
        }
        save()
        if (jp) jackpot(jp.tier.name, jp.amount)
        return true
    }

    // Count a table event for the stats page (blackjacks, splits, bonuses …).
    function count(key, by) {
        function bump(s) { var e = {}; for (var k in s.extra) e[k] = s.extra[k]; e[key] = (e[key] || 0) + (by === undefined ? 1 : by); s.extra = e }
        var a = copyStats(stats), b = copyStats(runStats)
        bump(a); bump(b)
        stats = a; runStats = b
    }
    function best(key, value) {
        function upd(s) { var e = {}; for (var k in s.extra) e[k] = s.extra[k]; e[key] = Math.max(e[key] || 0, value); s.extra = e }
        var a = copyStats(stats), b = copyStats(runStats)
        upd(a); upd(b)
        stats = a; runStats = b
    }
    function copyStats(s) { return JSON.parse(JSON.stringify(s)) }
    function record(s, gameName, staked, returned) {
        var g = s[gameName]
        if (!g) return
        g.bets += 1; g.wagered = round2(g.wagered + staked); g.returned = round2(g.returned + returned)
        if (returned > staked) { g.wins += 1; g.biggest = Math.max(g.biggest, round2(returned - staked)) }
    }

    // Close a round: `staked` was already taken by stake(), `returned` is what the table pays
    // back (stake included). Applies perks, auto-vault, tiers and the bust check.
    function continueToGameOver() { gameOverRequested() }

    // REBOOT: the attempt is spent the moment it starts, so quitting mid-run counts as a crash
    function startReboot() {
        if (!rebootAvailable) return false
        rebootAvailable = false
        save()
        return true
    }
    // REBOOT overtime: every gate past the minimum pays more than the one before, saved at once
    function rebootBonusFor(extra) { return round2(rebootAmount * 0.1 * extra) }
    function rebootGate(extra) {
        var b = rebootBonusFor(extra)
        balance = round2(balance + b)
        peak = Math.max(peak, netWorth)
        save()
        return b
    }
    function rebootWon() {
        runOver = false
        reboots += 1
        balance = round2(balance + rebootAmount)
        if (history.length && history[0].run === runs) history = history.slice(1)   // the run isn't over after all
        trace = trace.concat([netWorth])
        newSession()
        note("REBOOTED · +" + Money.fmt(rebootAmount), Neon.green)
        save()
        save()
    }

    function settle(staked, returned, gameName) {
        pending = null
        lastRound = { game: gameName, staked: staked, returned: returned }
        var preRound = balance + staked
        var net = returned - staked
        balance = round2(balance + returned)
        var a = copyStats(stats), b = copyStats(runStats)
        record(a, gameName, staked, returned); record(b, gameName, staked, returned)
        stats = a; runStats = b
        if (net < 0) {
            var loss = -net
            if (hasPerk("firewall") && firewallCharged && loss >= preRound * 0.5) {
                firewallCharged = false
                balance = round2(balance + loss)
                note("FIREWALL  +" + Money.fmt(loss), Neon.violet)
            } else if (hasPerk("rebate")) {
                var back = round2(loss * 0.05)
                if (back > 0) { balance = round2(balance + back); note("REBATE  +" + Money.fmt(back), Neon.green) }
            }
        } else if (net > 0) {
            runBiggestWin = Math.max(runBiggestWin, net)
            biggestWin = Math.max(biggestWin, net)
            if (autoVault > 0) {
                var sweep = round2(net * autoVault / 100)
                if (sweep > 0 && balance - sweep >= minBet) {
                    balance = round2(balance - sweep); vault = round2(vault + sweep)
                    note("VAULT  +" + Money.fmt(sweep), Neon.cyan)
                }
            }
        }
        bets += 1; totalBets += 1; sessionBets += 1
        if (hasPerk("staking") && bets % 10 === 0) {
            var interest = round2(balance * 0.01)
            if (interest > 0) { balance = round2(balance + interest); note("STAKING  +" + Money.fmt(interest), Neon.yellow) }
        }
        var tr = trace.concat([netWorth])
        if (tr.length > 240) tr = tr.filter(function (v, i) { return i % 2 === 0 || i === tr.length - 1 })
        trace = tr
        peak = Math.max(peak, netWorth)
        if (!custom) bestPeak = Math.max(bestPeak, peak)
        var t = Money.tierFor(peak, scale)
        if (t > tier) {
            pendingDrafts += t - tier
            tier = t
            firewallCharged = true
            tierUp(t)
        }
        if (winGoal > 0 && !goalAnnounced && sessionNet >= winGoal) {
            goalAnnounced = true
            note("SESSION GOAL HIT · VAULT IT?", Neon.yellow)
        }
        if (lossLimit > 0 && sessionLocked) note("LOSS LIMIT HIT · TABLES LOCKED", Neon.red)
        if (balance < minBet) {
            if (pendingList.length > 0) {
                // more balls still falling: judge the bust once they have all landed
            } else if (crapsOnTable > 0) {
                note("BETS STILL RIDING ON THE CRAPS TABLE", Neon.green)
            } else if (netWorth >= minBet) {
                note("OUT OF CHIPS · WITHDRAW FROM THE VAULT", Neon.cyan)
            } else if (hasPerk("secondwind") && !secondWindUsed) {
                secondWindUsed = true
                balance = minBet * 20
                note("SECOND WIND", Neon.green)
            } else {
                endRun()
                return
            }
        }
        save()
    }

    function takePerk(id) {
        if (!hasPerk(id)) { var p = perks.slice(); p.push(id); perks = p }
        pendingDrafts = Math.max(0, pendingDrafts - 1)
        save()
    }
    // Every perk already owned: the draft pays out cash instead.
    function takeCashDraft() {
        var bonus = round2(Math.max(minBet * 10, balance * 0.1))
        balance = round2(balance + bonus)
        peak = Math.max(peak, netWorth)
        pendingDrafts = Math.max(0, pendingDrafts - 1)
        save()
        return bonus
    }

    function round2(v) { return Math.round(v * 100) / 100 }
}
