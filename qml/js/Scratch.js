.pragma library
// Scratch tickets: 9 panels of prize values (× the ticket price). Three of the same value win
// that value. The outcome is drawn first from `table` (exact RTP ≈ 92%), then a grid is dealt
// that shows exactly that outcome (no other value appears three times).
var values = [1, 2, 5, 10, 50, 500]
var table = [{ v: 1, p: 0.19 }, { v: 2, p: 0.095 }, { v: 5, p: 0.035 }, { v: 10, p: 0.016 }, { v: 50, p: 0.0024 }, { v: 500, p: 0.00018 }]
function rtp() { var r = 0; for (var i = 0; i < table.length; ++i) r += table[i].p * table[i].v; return r }
function draw() {
    var r = Math.random()
    for (var i = 0; i < table.length; ++i) { r -= table[i].p; if (r < 0) return table[i].v }
    return 0
}
function shuffle(a) { for (var k = a.length - 1; k > 0; --k) { var j = Math.floor(Math.random() * (k + 1)), t = a[k]; a[k] = a[j]; a[j] = t } return a }
// returns { prize, cells: [9 values] }
function ticket() {
    var prize = draw(), cells = []
    if (prize) { cells = [prize, prize, prize] }
    var others = values.filter(function (v) { return v !== prize })
    var used = {}
    while (cells.length < 9) {
        var v = others[Math.floor(Math.random() * others.length)]
        if ((used[v] || 0) >= 2) continue
        used[v] = (used[v] || 0) + 1
        cells.push(v)
    }
    return { prize: prize, cells: shuffle(cells) }
}
