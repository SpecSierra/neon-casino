.pragma library
// Punto banco: 8-deck shoe, standard third-card tableau.
// Returns per bet (stake included): Player 2×, Banker 1.95× (5% commission), Tie 9× (8:1),
// a tie returns Player/Banker stakes; pairs 12× (11:1).
function value(card) {
    if (card.rank === "A") return 1
    if (card.rank === "10" || card.rank === "J" || card.rank === "Q" || card.rank === "K") return 0
    return parseInt(card.rank, 10)
}
function total(hand) { var t = 0; for (var i = 0; i < hand.length; ++i) t += value(hand[i]); return t % 10 }
function newShoe() {
    var suits = ["spades", "hearts", "diamonds", "clubs"], ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"], s = []
    for (var d = 0; d < 8; ++d) for (var i = 0; i < 4; ++i) for (var j = 0; j < 13; ++j) s.push({ rank: ranks[j], suit: suits[i] })
    for (var k = s.length - 1; k > 0; --k) { var r = Math.floor(Math.random() * (k + 1)), t = s[k]; s[k] = s[r]; s[r] = t }
    return s
}
// Deal one coup from the shoe (pops from the end). { player, banker, pv, bv, winner: "P"|"B"|"T", ppair, bpair }
function coup(shoe) {
    var p = [shoe.pop()], b = [shoe.pop()]
    p.push(shoe.pop()); b.push(shoe.pop())
    var pv = total(p), bv = total(b)
    if (pv < 8 && bv < 8) {
        var p3 = null
        if (pv <= 5) { p3 = shoe.pop(); p.push(p3) }
        var x = p3 ? value(p3) : -1
        var draw
        if (p3 === null) draw = bv <= 5
        else if (bv <= 2) draw = true
        else if (bv === 3) draw = x !== 8
        else if (bv === 4) draw = x >= 2 && x <= 7
        else if (bv === 5) draw = x >= 4 && x <= 7
        else if (bv === 6) draw = x === 6 || x === 7
        else draw = false
        if (draw) b.push(shoe.pop())
        pv = total(p); bv = total(b)
    }
    return { player: p, banker: b, pv: pv, bv: bv, winner: pv > bv ? "P" : bv > pv ? "B" : "T",
             ppair: p[0].rank === p[1].rank, bpair: b[0].rank === b[1].rank }
}
function payout(key, amount, c, perks) {
    var commission = perks && perks.indexOf("commission") >= 0 ? 0.025 : 0.05
    switch (key) {
    case "player": return c.winner === "P" ? amount * 2 : c.winner === "T" ? amount : 0
    case "banker": return c.winner === "B" ? amount * (2 - commission) : c.winner === "T" ? amount : 0
    case "tie": return c.winner === "T" ? amount * 9 : 0
    case "ppair": return c.ppair ? amount * 12 : 0
    case "bpair": return c.bpair ? amount * 12 : 0
    }
    return 0
}
