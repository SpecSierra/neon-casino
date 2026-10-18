.pragma library
// European single-zero wheel order, clockwise.
var wheel = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
var reds = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

function isRed(n) { return reds.indexOf(n) >= 0 }
function colorOf(n) { return n === 0 ? "green" : (isRed(n) ? "red" : "black") }

// Bet keys: "n:17", "red", "black", "odd", "even", "low", "high", "doz:1..3", "col:1..3", and
// inside bets on the lines, "m:<numbers>" (e.g. "m:1,2" split, "m:1,2,3" street, "m:1,2,4,5"
// corner, "m:1,2,3,4,5,6" six line), which pay 36 / count: 17:1, 11:1, 8:1, 5:1.
function numbersOf(key) { return key.slice(2).split(",").map(function (s) { return parseInt(s, 10) }) }
function multiName(key) {
    var k = numbersOf(key).length
    return ({ 2: "SPLIT", 3: "STREET", 4: "CORNER", 6: "SIX LINE" })[k] + " " + numbersOf(key)[0] + "-" + numbersOf(key)[k - 1] + " · " + (36 / k - 1) + ":1"
}
function covers(key, n) {
    if (key.indexOf("n:") === 0) return parseInt(key.slice(2), 10) === n
    if (key.indexOf("m:") === 0) return numbersOf(key).indexOf(n) >= 0
    if (n === 0) return false
    switch (key) {
    case "red": return isRed(n)
    case "black": return !isRed(n)
    case "odd": return n % 2 === 1
    case "even": return n % 2 === 0
    case "low": return n <= 18
    case "high": return n >= 19
    }
    if (key.indexOf("doz:") === 0) { var d = parseInt(key.slice(4), 10); return n > (d - 1) * 12 && n <= d * 12 }
    if (key.indexOf("col:") === 0) { var c = parseInt(key.slice(4), 10); return (n - c) % 3 === 0 }
    return false
}
function isEvenMoney(key) { return ["red", "black", "odd", "even", "low", "high"].indexOf(key) >= 0 }
// Total returned (stake included) for one bet.
function payout(key, amount, n, perks) {
    if (covers(key, n)) {
        if (key.indexOf("n:") === 0) return amount * (perks.indexOf("hotnumber") >= 0 ? 38 : 36)
        if (key.indexOf("m:") === 0) return amount * 36 / numbersOf(key).length
        if (isEvenMoney(key)) return amount * (perks.indexOf("redline") >= 0 ? 2.1 : 2)
        return amount * 3
    }
    if (n === 0 && isEvenMoney(key) && perks.indexOf("partage") >= 0) return amount / 2
    return 0
}
