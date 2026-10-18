.pragma library
// Hi-Lo: guess whether the next card (2..A, infinite deck) is strictly higher or lower.
// A right guess multiplies the stake by 0.97 / P(guess), so every step returns 97%; a tie loses.
var ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
var suits = ["spades", "hearts", "diamonds", "clubs"]
function card() { return { rank: ranks[Math.floor(Math.random() * 13)], suit: suits[Math.floor(Math.random() * 4)] } }
function value(c) { return ranks.indexOf(c.rank) + 2 }
function pHigher(c) { return (14 - value(c)) / 13 }
function pLower(c) { return (value(c) - 2) / 13 }
function step(c, higher) { var p = higher ? pHigher(c) : pLower(c); return p > 0 ? Math.floor(0.97 / p * 100) / 100 : 0 }
function wins(c, next, higher) { return higher ? value(next) > value(c) : value(next) < value(c) }
