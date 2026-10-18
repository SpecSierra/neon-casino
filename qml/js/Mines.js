.pragma library
// Mines: 25 tiles, `mines` of them hidden. After k safe picks the pay is 0.97 × C(25,k) / C(25-mines,k)
// (0.97 × the fair odds of surviving k picks), so any cash-out strategy returns 97%.
var size = 25
function comb(n, k) { if (k < 0 || k > n) return 0; var r = 1; for (var i = 1; i <= k; ++i) r = r * (n - k + i) / i; return r }
function multiplier(mines, picks) { return picks <= 0 ? 1 : Math.floor(0.97 * comb(size, picks) / comb(size - mines, picks) * 100) / 100 }
function layout(mines) {
    var cells = []; for (var i = 0; i < size; ++i) cells.push(i)
    for (var k = cells.length - 1; k > 0; --k) { var j = Math.floor(Math.random() * (k + 1)), t = cells[k]; cells[k] = cells[j]; cells[j] = t }
    return cells.slice(0, mines).sort(function (a, b) { return a - b })
}
