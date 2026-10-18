pragma Singleton
import QtQuick 2.6
import QtFeedback 5.0

// Vibration through the Harbour-allowed ThemeEffect presses only; patterns are
// built from repeated strong presses.
QtObject {
    id: h
    property bool enabled: true
    property ThemeEffect weak: ThemeEffect { effect: ThemeEffect.PressWeak }
    property ThemeEffect medium: ThemeEffect { effect: ThemeEffect.Press }
    property ThemeEffect strong: ThemeEffect { effect: ThemeEffect.PressStrong }
    property int left: 0
    property Timer pulser: Timer {
        interval: 120; repeat: true
        onTriggered: { h.strong.play(); if (--h.left <= 0) stop() }
    }

    function ok() { return enabled && Qt.application.active }
    function tick() { if (ok()) weak.play() }
    function tap() { if (ok()) medium.play() }
    function win(big) {
        if (!ok()) return
        if (big) rumble(4)
        else medium.play()
    }
    function rumble(n) {
        if (!ok()) return
        strong.play()
        left = n - 1
        if (left > 0) pulser.restart()
    }
}
