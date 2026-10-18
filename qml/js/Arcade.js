.pragma library
// PIXEL ARCADE engine (slots meets bingo). Mirrors tools/arcadesim.py; machine in ArcadeConfig.js.
// A game is decided in full when the card is bought (card + every spin); the player only decides
// where jokers go. State (saved as Game.arcade):
//   { stake, card: [r][c], spins: [[5 symbols] × SPINS], idx, marked: [r][c], coins, queue: [{ type, col }] }

var LINES = (function () {
    var l = [], r, c
    for (r = 0; r < 5; ++r) { var row = []; for (c = 0; c < 5; ++c) row.push([r, c]); l.push(row) }
    for (c = 0; c < 5; ++c) { var col = []; for (r = 0; r < 5; ++r) col.push([r, c]); l.push(col) }
    var d1 = [], d2 = []
    for (var i = 0; i < 5; ++i) { d1.push([i, i]); d2.push([i, 4 - i]) }
    l.push(d1); l.push(d2)
    return l
})()

function sample(lo, n) {      // n distinct numbers from lo .. lo+14
    var pool = []; for (var i = 0; i < 15; ++i) pool.push(lo + i)
    for (i = pool.length - 1; i > 0; --i) { var j = Math.floor(Math.random() * (i + 1)), t = pool[i]; pool[i] = pool[j]; pool[j] = t }
    return pool.slice(0, n)
}
function reel(m, c) {
    var x = Math.random()
    for (var k in m.p) { x -= m.p[k]; if (x < 0) return k === "number" ? 15 * c + 1 + Math.floor(Math.random() * 15) : k }
    return "ghost"
}
function newGame(m, stake) {
    var cols = [], c, r, card = [], marked = [], spins = []
    for (c = 0; c < 5; ++c) cols.push(sample(15 * c + 1, 5))
    for (r = 0; r < 5; ++r) { var row = [], mk = []; for (c = 0; c < 5; ++c) { row.push(cols[c][r]); mk.push(false) } card.push(row); marked.push(mk) }
    for (var s = 0; s < m.spins; ++s) { var sp = []; for (c = 0; c < 5; ++c) sp.push(reel(m, c)); spins.push(sp) }
    return { stake: stake, card: card, spins: spins, idx: 0, marked: marked, coins: 0, queue: [] }
}
function copy(st) { return JSON.parse(JSON.stringify(st)) }
function freeIn(st, cols) {
    for (var i = 0; i < cols.length; ++i) for (var r = 0; r < 5; ++r) if (!st.marked[r][cols[i]]) return true
    return false
}
// Play the next spin: mark numbers, bank coins, queue jokers (column ones first, then supers).
function applySpin(m, st) {
    var row = st.spins[st.idx], c, r
    for (c = 0; c < 5; ++c) {
        var s = row[c]
        if (typeof s === "number") { for (r = 0; r < 5; ++r) if (st.card[r][c] === s) st.marked[r][c] = true }
        else if (s === "coin") st.coins += m.coin
    }
    for (c = 0; c < 5; ++c) if (row[c] === "joker") st.queue.push({ type: "joker", col: c })
    for (c = 0; c < 5; ++c) if (row[c] === "super") st.queue.push({ type: "super", col: -1 })
    st.idx += 1
    dropDead(st)
}
// jokers with nowhere to go are skipped
function dropDead(st) {
    while (st.queue.length && !freeIn(st, st.queue[0].col < 0 ? [0, 1, 2, 3, 4] : [st.queue[0].col])) st.queue.shift()
}
function canPlace(st, r, c) {
    if (!st.queue.length || st.marked[r][c]) return false
    var q = st.queue[0]
    return q.col < 0 || q.col === c
}
function place(st, r, c) {
    if (!canPlace(st, r, c)) return false
    st.marked[r][c] = true
    st.queue.shift()
    dropDead(st)
    return true
}
function cellLines(r, c) {
    var out = []
    for (var i = 0; i < LINES.length; ++i) for (var k = 0; k < 5; ++k) if (LINES[i][k][0] === r && LINES[i][k][1] === c) { out.push(i); break }
    return out
}
// the hint: the cell that pushes lines furthest (same greedy as the tuning bot)
function bestCell(st) {
    if (!st.queue.length) return null
    var q = st.queue[0], cols = q.col < 0 ? [0, 1, 2, 3, 4] : [q.col], best = null, bv = -1
    for (var i = 0; i < cols.length; ++i) for (var r = 0; r < 5; ++r) {
        var c = cols[i]
        if (st.marked[r][c]) continue
        var v = 0, ls = cellLines(r, c)
        for (var k = 0; k < ls.length; ++k) {
            var n = 0; for (var j = 0; j < 5; ++j) if (st.marked[LINES[ls[k]][j][0]][LINES[ls[k]][j][1]]) n++
            v += Math.pow(n + 1, 3)
        }
        if (v > bv) { bv = v; best = [r, c] }
    }
    return best
}
function linesDone(st) {
    var out = []
    for (var i = 0; i < LINES.length; ++i) {
        var ok = true
        for (var k = 0; k < 5; ++k) if (!st.marked[LINES[i][k][0]][LINES[i][k][1]]) { ok = false; break }
        if (ok) out.push(i)
    }
    return out
}
function inLine(st, r, c) {
    var d = linesDone(st)
    for (var i = 0; i < d.length; ++i) for (var k = 0; k < 5; ++k) if (LINES[d[i]][k][0] === r && LINES[d[i]][k][1] === c) return true
    return false
}
function finished(m, st) { return st.idx >= m.spins && !st.queue.length }
function payout(m, st) { return Math.round((m.ladder[linesDone(st).length] + st.coins) * st.stake * 100) / 100 }
