import QtQuick
import QtQuick.Controls.Basic
import "."

// A search prompt: "> " and a blinking block cursor on the terminal, an
// inset slab on the film pages.
TextField {
    id: field

    implicitWidth: 260
    leftPadding: 26
    color: Theme.ink
    selectionColor: Theme.accent
    selectedTextColor: Theme.bg
    placeholderTextColor: Theme.tint(0.4)
    font { family: Theme.mono; pixelSize: 13 }
    background: Rectangle {
        radius: Theme.pillRadius
        ThemeShapeContainer {   // a skin's pill shape
            visible: Theme.skinned
            anchors.fill: parent
            role: "pill"
            fillColor: Theme.card
            strokeColor: field.activeFocus ? Theme.accent : Theme.border
            cornerBrackets: false
            shadowType: "none"
        }
        color: Theme.skinned ? "transparent" : Theme.dark ? Theme.withAlpha(Theme.phosphor, 0.04) : Theme.cream
        border.width: Theme.skinned ? 0 : field.activeFocus ? 2 : (Theme.dark ? 1 : 2)
        border.color: field.activeFocus ? Theme.accent : (Theme.dark ? Theme.tint(0.5) : Theme.charcoal)
        Text {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            text: ">"
            color: Theme.accent
            font { family: Theme.mono; pixelSize: 13; bold: true }
        }
    }
    cursorDelegate: Rectangle {
        width: Theme.dark ? 8 : 2
        color: Theme.dark ? Theme.withAlpha(Theme.phosphor, 0.7) : Theme.charcoal
        visible: field.activeFocus && blink.on
        QtObject { id: blink; property bool on: true }
        Timer { interval: 530; repeat: true; running: field.activeFocus; onTriggered: blink.on = !blink.on }
    }
}
