import QtQuick

// The widget's common/SustainedLevel.qml: an alert level that changes only
// once the raw reading has held its new level for `interval` ms, so a
// one-sample spike never trips an alert and a reading hovering on a
// threshold doesn't flicker in and out of it. Any change of `raw` restarts
// the wait; back at the current level it cancels. interval 0: `level`
// follows `raw` at once.
Timer {
    id: hold

    property int raw: 0                   // 0 nominal, 1 warning, 2 critical, as judged this sample
    property int level: 0                 // the level that has held

    interval: 3000
    onRawChanged: {
        if (raw === level || interval <= 0) { stop(); level = raw; return }
        restart()
    }
    onTriggered: level = raw
    // already past a threshold when created: the first raw value fires no change
    Component.onCompleted: if (raw !== level) { if (interval > 0) restart(); else level = raw }
}
