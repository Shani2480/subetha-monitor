import QtQuick
import "."

// Load and temperature on one track, in the look's gauge shape (DynamicMetricGauge): the widget's
// contents/ui/common/DualMetricBar.qml on the monitor's Theme singleton.
// Each block lights in two layers: behind, a translucent wash for the
// temperature on a 30-100 °C scale (amber on the CRT, mustard on the
// movie pages), steady orange at a temperature warning (`tempLevel` 1) and a
// glowing crimson strobe when critical (2); in front, a solid inset fill for
// the load, coloured like every load gauge (good / busy / hot), that pulses
// between full brightness and hazard amber when the load is critical
// (`loadLevel` 2). The levels come from Alerts; with alert motion off they
// keep their colours without the motion.
Item {
    id: bar

    property real usageFraction: 0        // 0..1
    property real tempValue: 0            // °C; 0 or less: no temperature layer
    property real minTemp: 30
    property real maxTemp: 100
    property int tempLevel: 0             // 0 nominal, 1 warning, 2 critical
    property int loadLevel: 0             // 0 nominal, 2 critical
    property bool live: false             // gates the pulses
    property int segments: 24
    property real segmentHeight: 9

    readonly property real tempFraction: tempValue > 0 ? Math.max(0, Math.min(1, (tempValue - minTemp) / (maxTemp - minTemp))) : 0
    readonly property bool warm: tempValue > 0 && tempLevel === 1
    readonly property bool hot: tempValue > 0 && tempLevel === 2
    readonly property int loadFilled: Math.round(Math.max(0, Math.min(1, usageFraction)) * segments)
    readonly property int tempFilled: Math.round(tempFraction * segments)
    readonly property real load: usageFraction * 100
    readonly property color restingLoad: Theme.gaugeLoad(load)
    // critical load: full brightness <-> hazard amber
    readonly property color bright: Qt.lighter(restingLoad, 1.25)
    readonly property color loadColor: loadLevel !== 2 ? restingLoad
        : Qt.rgba(bright.r + (Theme.warnColor.r - bright.r) * hazard, bright.g + (Theme.warnColor.g - bright.g) * hazard,
                  bright.b + (Theme.warnColor.b - bright.b) * hazard, 1)
    readonly property color tempColor: hot ? Theme.critColor : warm ? Theme.gaugeHot : Theme.skinned ? Theme.gaugeTemp : Theme.mid

    readonly property bool moving: Alerts.motion && live
    // critical temperature: a hard strobe, dim <-> glowing
    property real strobe: 1
    SequentialAnimation on strobe {
        running: bar.hot && bar.moving
        loops: Animation.Infinite
        onRunningChanged: if (!running) bar.strobe = 1
        NumberAnimation { to: 0.25; duration: 90 }
        PauseAnimation { duration: 160 }
        NumberAnimation { to: 1; duration: 90 }
        PauseAnimation { duration: 160 }
    }
    property real hazard: 0
    SequentialAnimation on hazard {
        running: bar.loadLevel === 2 && bar.moving
        loops: Animation.Infinite
        onRunningChanged: if (!running) bar.hazard = 0
        NumberAnimation { to: 1; duration: 450; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 450; easing.type: Easing.InOutSine }
    }
    readonly property real tempOpacity: hot ? 0.95 * strobe : warm ? 0.5 : Theme.dark ? 0.35 : 0.3

    property string metric: ""          // the skin's meter colour for it (DynamicMetricGauge.metric)
    implicitWidth: 160
    implicitHeight: segmentHeight

    DynamicMetricGauge {
        anchors.fill: parent
        value: bar.usageFraction
        secondary: bar.tempValue > 0 ? bar.tempFraction : -1
        fillColor: bar.loadColor
        metric: bar.metric
        secondaryColor: bar.tempColor
        secondaryOpacity: bar.tempOpacity
        segments: bar.segments
        glow: bar.hot
        glowOpacity: bar.strobe
        live: bar.live
    }
}
