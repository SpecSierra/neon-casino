.pragma library
var suits = ["spades", "hearts", "diamonds", "clubs"]
var ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

function newShoe(decks) {
    var s = []
    for (var d = 0; d < decks; ++d)
        for (var i = 0; i < 4; ++i)
            for (var j = 0; j < 13; ++j) s.push({ rank: ranks[j], suit: suits[i] })
    for (var k = s.length - 1; k > 0; --k) {
        var r = Math.floor(Math.random() * (k + 1)), t = s[k]; s[k] = s[r]; s[r] = t
    }
    return s
}
function value(card) {
    if (card.rank === "A") return 11
    if (card.rank === "J" || card.rank === "Q" || card.rank === "K") return 10
    return parseInt(card.rank, 10)
}
// { total, soft }
function score(hand) {
    var t = 0, aces = 0
    for (var i = 0; i < hand.length; ++i) { t += value(hand[i]); if (hand[i].rank === "A") ++aces }
    while (t > 21 && aces > 0) { t -= 10; --aces }
    return { total: t, soft: aces > 0 }
}
function isBlackjack(hand) { return hand.length === 2 && score(hand).total === 21 }
