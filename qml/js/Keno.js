.pragma library
// Keno: pick 1-10 of 80 numbers, 20 are drawn. Pays (stake included) come from KenoConfig.js,
// tuned exactly by tools/kenosim.py to ~93% for every number of picks.
function draw(m) {
    var all = []
    for (var i = 1; i <= m.numbers; ++i) all.push(i)
    for (var k = all.length - 1; k > 0; --k) { var j = Math.floor(Math.random() * (k + 1)), t = all[k]; all[k] = all[j]; all[j] = t }
    return all.slice(0, m.drawn)
}
function hits(picks, drawn) {
    var n = 0
    for (var i = 0; i < picks.length; ++i) if (drawn.indexOf(picks[i]) >= 0) ++n
    return n
}
function pay(m, picks, h) {
    var row = m.pay[String(picks)]
    return row && row[String(h)] ? row[String(h)] : 0
}
function quickPick(m, count) {
    var d = draw(m)
    return d.slice(0, count).sort(function (a, b) { return a - b })
}
