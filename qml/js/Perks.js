.pragma library

// unlock = lifetime amount wagered (across all runs) before the perk joins the draft pool.
var all = [
    { id: "rebate",     name: "Rebate Chip",      game: "any",       unlock: 0,      color: "#39FF88",
      desc: "5% of every losing bet flows back to you." },
    { id: "lucky7",     name: "Lucky Seven",      game: "slots",     unlock: 0,      color: "#FF3355",
      desc: "Three top symbols (7s, dragons, skulls, suns) pay double." },
    { id: "partage",    name: "La Partage",       game: "roulette",  unlock: 0,      color: "#00F0FF",
      desc: "When zero hits, even-money bets return half." },
    { id: "natural",    name: "Natural High",     game: "blackjack", unlock: 500,    color: "#F8FF3A",
      desc: "Blackjack pays 2:1 instead of 3:2." },
    { id: "nudge",      name: "Reel Nudge",       game: "slots",     unlock: 500,    color: "#FF2BD6",
      desc: "Two matching reels on the centre line can nudge the third into place." },
    { id: "secondwind", name: "Second Wind",      game: "any",       unlock: 1500,   color: "#39FF88",
      desc: "Once per run, going broke refills you to 20× the minimum bet." },
    { id: "ghost",      name: "Ghost Protocol",   game: "blackjack", unlock: 1500,   color: "#A05AFF",
      desc: "Unlocks Surrender: fold your first two cards and keep half the bet." },
    { id: "optic",      name: "Optic Implant",    game: "blackjack", unlock: 4000,   color: "#00F0FF",
      desc: "25% chance each hand to see the dealer's hole card." },
    { id: "wild",       name: "Wild Circuit",     game: "slots",     unlock: 4000,   color: "#FFFFFF",
      desc: "WILD symbols join the reels and stand in for anything." },
    { id: "hotnumber",  name: "Hot Number",       game: "roulette",  unlock: 10000,  color: "#FF3355",
      desc: "Straight-up number bets pay 37:1 instead of 35:1." },
    { id: "overdrive",  name: "Overdrive",        game: "slots",     unlock: 10000,  color: "#FF9F14",
      desc: "Free-spin multipliers are doubled." },
    { id: "fullhouse",  name: "Full House 10",    game: "poker",     unlock: 8000,   color: "#A05AFF",
      desc: "Video poker: a full house pays 10 instead of 9." },
    { id: "commission", name: "Commission Hack",  game: "baccarat",  unlock: 8000,   color: "#F8FF3A",
      desc: "Baccarat: the Banker bet's commission drops from 5% to 2.5%." },
    { id: "staking",    name: "Crypto Staking",   game: "any",       unlock: 10000,  color: "#F8FF3A",
      desc: "Every 10 bets, earn 1% interest on your balance." },
    { id: "charlie",    name: "Five-Card Charlie", game: "blackjack", unlock: 25000, color: "#FF2BD6",
      desc: "Five cards without busting wins 2:1 on the spot." },
    { id: "overclock",  name: "Overclock",        game: "slots",     unlock: 25000,  color: "#00F0FF",
      desc: "All slot wins pay 25% more." },
    { id: "firewall",   name: "Firewall",         game: "any",       unlock: 60000,  color: "#A05AFF",
      desc: "Once per tier, a loss of half your balance or more is refunded." },
    { id: "redline",    name: "Redline",          game: "roulette",  unlock: 150000, color: "#FF3355",
      desc: "Even-money roulette bets pay 1.1:1." },
    { id: "jackpot",    name: "Neon Jackpot",     game: "slots",     unlock: 400000, color: "#F8FF3A",
      desc: "Three top symbols on a slot line pay triple." }
]

function byId(id) {
    for (var i = 0; i < all.length; ++i) if (all[i].id === id) return all[i]
    return null
}
function unlocked(lifetimeWagered) {
    return all.filter(function (p) { return p.unlock <= lifetimeWagered })
}
// Up to n random unlocked perks the run doesn't own yet.
function draft(lifetimeWagered, owned, n) {
    var pool = unlocked(lifetimeWagered).filter(function (p) { return owned.indexOf(p.id) < 0 })
    var out = []
    while (out.length < n && pool.length) out.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0])
    return out
}
