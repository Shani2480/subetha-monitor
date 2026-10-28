import QtQuick
import "."

// "[x] USER ONLY": a terminal-style checkbox.
Item {
    id: check

    property string text: ""
    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight + 8

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: (check.checked ? "[x] " : "[ ] ") + check.text
        color: area.containsMouse ? Theme.accent : Theme.ink
        font { family: Theme.mono; features: Theme.figures; pixelSize: 12; bold: true; letterSpacing: 0.6 }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { check.checked = !check.checked; check.toggled(check.checked) }
    }
}
