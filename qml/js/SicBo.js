.pragma library
// Sic Bo with three dice. Returns per bet (stake included).
// small 4-10 / big 11-17 1:1 (lose on any triple) · any triple 30:1 · total N (4..17) at the
// usual table · single number 1-6: 1:1 per die showing it (2:1 for two, 3:1 for three).
var totalPays = { 4: 60, 5: 30, 6: 17, 7: 12, 8: 8, 9: 6, 10: 6, 11: 6, 12: 6, 13: 8, 14: 12, 15: 17, 16: 30, 17: 60 }
function roll() { return [1 + Math.floor(Math.random() * 6), 1 + Math.floor(Math.random() * 6), 1 + Math.floor(Math.random() * 6)] }
function payout(key, amount, d) {
    var t = d[0] + d[1] + d[2], triple = d[0] === d[1] && d[1] === d[2]
    if (key === "small") return !triple && t >= 4 && t <= 10 ? amount * 2 : 0
    if (key === "big") return !triple && t >= 11 && t <= 17 ? amount * 2 : 0
    if (key === "triple") return triple ? amount * 31 : 0
    if (key.indexOf("t:") === 0) { var n = parseInt(key.slice(2), 10); return t === n ? amount * (totalPays[n] + 1) : 0 }
    if (key.indexOf("n:") === 0) {
        var face = parseInt(key.slice(2), 10), c = 0
        for (var i = 0; i < 3; ++i) if (d[i] === face) ++c
        return c ? amount * (c + 1) : 0
    }
    return 0
}
