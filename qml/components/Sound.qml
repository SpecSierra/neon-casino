pragma Singleton
import QtQuick 2.6
import QtMultimedia 5.6

QtObject {
    property bool enabled: true
    property real master: 1.0            // effects volume from Settings (0..1)
    // each effect's own level, scaled by `master` when it plays
    readonly property var base: ({ click: 0.6, card: 1, tick: 0.6, reel: 1, win: 1, bigwin: 1, lose: 0.7, perk: 1, bust: 1, clack: 0.7, pocket: 1 })
    property SoundEffect click: SoundEffect { source: "../sounds/click.wav"; volume: 0.6 }
    property SoundEffect card: SoundEffect { source: "../sounds/card.wav" }
    property SoundEffect tick: SoundEffect { source: "../sounds/tick.wav"; volume: 0.6 }
    property SoundEffect reel: SoundEffect { source: "../sounds/reel.wav" }
    property SoundEffect win: SoundEffect { source: "../sounds/win.wav" }
    property SoundEffect bigwin: SoundEffect { source: "../sounds/bigwin.wav" }
    property SoundEffect lose: SoundEffect { source: "../sounds/lose.wav"; volume: 0.7 }
    property SoundEffect perk: SoundEffect { source: "../sounds/perk.wav" }
    property SoundEffect bust: SoundEffect { source: "../sounds/bust.wav" }
    property SoundEffect clack: SoundEffect { source: "../sounds/clack.wav"; volume: 0.7 }
    property SoundEffect pocket: SoundEffect { source: "../sounds/pocket.wav" }
    property SoundEffect ballroll: SoundEffect { source: "../sounds/ballroll.wav"; loops: SoundEffect.Infinite; volume: 0.5 }
    // looping effects: start/stop and level
    function loop(name, on, level) {
        var fx = name === "ballroll" ? ballroll : null
        if (!fx) return
        if (on && enabled && Qt.application.active) { fx.volume = (level === undefined ? 0.5 : level) * master; if (!fx.playing) fx.play() }
        else fx.stop()
    }

    function play(name) {
        if (!enabled || !Qt.application.active) return
        var fx = { click: click, card: card, tick: tick, reel: reel, win: win, bigwin: bigwin,
                   lose: lose, perk: perk, bust: bust, clack: clack, pocket: pocket }[name]
        if (fx) { fx.volume = base[name] * master; fx.play() }
    }
}
