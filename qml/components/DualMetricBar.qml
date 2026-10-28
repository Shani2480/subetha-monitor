import QtQuick
import "."

// Load and temperature on one segmented track: the widget's
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
    readonly property color restingLoad: load >= 85 ? Theme.low : load >= 50 ? Theme.mid : Theme.high
    // critical load: full brightness <-> hazard amber
    readonly property color bright: Qt.lighter(restingLoad, 1.25)
    readonly property color loadColor: loadLevel !== 2 ? restingLoad
        : Qt.rgba(bright.r + (Theme.warnColor.r - bright.r) * hazard, bright.g + (Theme.warnColor.g - bright.g) * hazard,
                  bright.b + (Theme.warnColor.b - bright.b) * hazard, 1)
    readonly property color tempColor: hot ? Theme.critColor : warm ? "#FF8A1A" : Theme.dark ? Theme.amber : Theme.mustard

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

    readonly property real spacing: 2
    implicitWidth: 160
    implicitHeight: segmentHeight

    Rectangle {   // critical temperature: the glow around the track, in step with the strobe
        visible: bar.hot
        anchors { fill: parent; margins: -2 }
        radius: Theme.dark ? 0 : 4
        color: "transparent"
        border { width: 2; color: Theme.critColor }
        opacity: 0.55 * bar.strobe
    }

    Row {
        spacing: bar.spacing
        Repeater {
            model: bar.segments
            Rectangle {   // one block: outline, temperature wash, load fill
                required property int index
                readonly property bool loaded: index < bar.loadFilled
                width: (bar.width - bar.spacing * (bar.segments - 1)) / bar.segments
                height: bar.segmentHeight
                radius: Theme.dark ? 0 : Math.min(2, height / 2)
                color: "transparent"
                border.width: 1
                border.color: loaded ? bar.loadColor : Theme.tint(Theme.dark ? 0.3 : 0.45)
                Rectangle {   // temperature, behind
                    visible: index < bar.tempFilled
                    anchors.fill: parent
                    radius: parent.radius
                    color: bar.tempColor
                    opacity: bar.tempOpacity
                }
                Rectangle {   // load, in front
                    visible: parent.loaded
                    anchors { fill: parent; margins: parent.height >= 7 ? 2 : 1 }
                    radius: Theme.dark ? 0 : 1
                    color: bar.loadColor
                }
            }
        }
    }
}
