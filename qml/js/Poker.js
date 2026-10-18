.pragma library
// Jacks or Better video poker, 9/6 "full pay" table (≈99.5% with perfect play).
var table = [
    { id: "royal", name: "ROYAL FLUSH", pay: 800 },
    { id: "sflush", name: "STRAIGHT FLUSH", pay: 50 },
    { id: "four", name: "FOUR OF A KIND", pay: 25 },
    { id: "full", name: "FULL HOUSE", pay: 9 },
    { id: "flush", name: "FLUSH", pay: 6 },
    { id: "straight", name: "STRAIGHT", pay: 4 },
    { id: "three", name: "THREE OF A KIND", pay: 3 },
    { id: "twopair", name: "TWO PAIR", pay: 2 },
    { id: "jacks", name: "JACKS OR BETTER", pay: 1 }
]
var order = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
function rv(card) { return order.indexOf(card.rank) + 2 }          // 2..14

function shuffled() {
    var suits = ["spades", "hearts", "diamonds", "clubs"], d = []
    for (var s = 0; s < 4; ++s) for (var r = 0; r < 13; ++r) d.push({ rank: order[r], suit: suits[s] })
    for (var k = d.length - 1; k > 0; --k) { var j = Math.floor(Math.random() * (k + 1)), t = d[k]; d[k] = d[j]; d[j] = t }
    return d
}
// best paying hand: { id, name, pay, cards: [indexes that make it] } or null
function evaluate(hand, perks) {
    var counts = {}, i, vals = hand.map(rv).sort(function (a, b) { return a - b })
    for (i = 0; i < 5; ++i) counts[rv(hand[i])] = (counts[rv(hand[i])] || 0) + 1
    var flush = hand.every(function (c) { return c.suit === hand[0].suit })
    var uniq = Object.keys(counts).length
    var straight = uniq === 5 && (vals[4] - vals[0] === 4 || vals.join() === "2,3,4,5,14")
    var groups = Object.keys(counts).map(function (k) { return { v: +k, n: counts[k] } }).sort(function (a, b) { return b.n - a.n || b.v - a.v })
    function res(id, idx) {
        for (var t = 0; t < table.length; ++t) if (table[t].id === id) {
            var pay = table[t].pay
            if (id === "full" && perks && perks.indexOf("fullhouse") >= 0) pay = 10
            return { id: id, name: table[t].name, pay: pay, cards: idx }
        }
    }
    function idxOf(v) { var o = []; for (var k = 0; k < 5; ++k) if (rv(hand[k]) === v) o.push(k); return o }
    var all = [0, 1, 2, 3, 4]
    if (straight && flush) return res(vals[0] === 10 ? "royal" : "sflush", all)
    if (groups[0].n === 4) return res("four", idxOf(groups[0].v))
    if (groups[0].n === 3 && groups[1].n === 2) return res("full", all)
    if (flush) return res("flush", all)
    if (straight) return res("straight", all)
    if (groups[0].n === 3) return res("three", idxOf(groups[0].v))
    if (groups[0].n === 2 && groups[1].n === 2) return res("twopair", idxOf(groups[0].v).concat(idxOf(groups[1].v)))
    if (groups[0].n === 2 && groups[0].v >= 11) return res("jacks", idxOf(groups[0].v))
    return null
}
