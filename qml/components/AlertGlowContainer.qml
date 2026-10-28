import QtQuick
import "."

// An alert halo for a card, in the theme's own shape (ThemeShapeContainer),
// drawn just outside its bounds so the layout never moves: the widget's
// common/AlertGlowContainer.qml on the monitor's Theme. Warning (1): a
// steady amber outline. Critical (2): a crimson outline and glow that
// breathes (opacity 0.2 <-> 0.9, 600 ms each way, sine) while `animate` is
// on. Nominal (0): nothing. Content placed inside sits above the halo.
Item {
    id: root

    property string role: "card"          // card | pill
    property int alertLevel: 0            // 0 nominal, 1 warning, 2 critical
    property bool animate: Alerts.motion  // the owner folds in whether it is on screen
    property real spread: 3               // px outside the bounds
    default property alias content: innerContent.data

    readonly property color tone: alertLevel === 2 ? Theme.critColor : Theme.warnColor

    property real breath: 0.9
    SequentialAnimation on breath {
        running: root.alertLevel === 2 && root.animate
        loops: Animation.Infinite
        onRunningChanged: if (!running) root.breath = 0.9
        NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.9; duration: 600; easing.type: Easing.InOutSine }
    }

    ThemeShapeContainer {
        visible: root.alertLevel > 0
        anchors { fill: parent; margins: -root.spread }
        role: root.role
        fillColor: "transparent"
        strokeColor: root.tone
        strokeWidth: 2
        borderStyle: "solid"
        cornerBrackets: false
        shadowType: root.alertLevel === 2 ? "glow" : "none"
        shadowColor: root.tone
        shadowBlur: 8
        opacity: root.alertLevel === 2 ? root.breath : 0.75
    }

    Item {
        id: innerContent
        anchors.fill: parent
    }
}
