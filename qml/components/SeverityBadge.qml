import QtQuick
import "."

// A card's alert level beside its title: a static accent dot when nominal,
// an amber [WARN] at a warning, a crimson [CRITICAL: figure] blinking every
// 300 ms when critical (steady with alert motion off or off screen).
Item {
    id: pip

    property int level: 0                 // 0 nominal, 1 warning, 2 critical
    property string figure: ""            // the reading in [CRITICAL: ...]
    property bool live: true

    implicitWidth: level === 0 ? 7 : tag.width
    implicitHeight: level === 0 ? 7 : tag.height

    property bool blinkOn: true
    Timer {
        interval: 300
        repeat: true
        running: pip.level === 2 && pip.live && Alerts.motion
        onTriggered: pip.blinkOn = !pip.blinkOn
        onRunningChanged: if (!running) pip.blinkOn = true
    }

    Rectangle {
        visible: pip.level === 0
        anchors.fill: parent
        radius: width / 2
        color: Theme.accent
    }
    Rectangle {
        id: tag
        visible: pip.level > 0
        width: label.implicitWidth + 10
        height: label.implicitHeight + 3
        radius: Theme.skinned || !Theme.dark ? height / 2 : 0
        color: pip.level === 2 ? Theme.critColor : Theme.warnColor
        opacity: pip.blinkOn ? 1 : 0.12
        Text {
            id: label
            anchors.centerIn: parent
            text: pip.level === 1 ? "[WARN]" : pip.figure ? "[CRITICAL: " + pip.figure + "]" : "[CRITICAL]"
            color: Theme.dark ? Theme.bg : "#FFFFFF"
            font { family: Theme.mono; features: Theme.figures; pixelSize: 10; bold: true; letterSpacing: 0.4 }
        }
    }
}
