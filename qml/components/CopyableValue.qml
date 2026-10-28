import QtQuick
import QtQuick.Layouts
import "."

// "WAN IP  203.0.113.7  [COPY]": a click copies the value to the clipboard
// through the telemetry backend and flashes COPIED.
RowLayout {
    id: row

    property string label: ""
    property string value: ""
    property bool copyable: value !== "" && /^[0-9a-fA-F:.\/]+$/.test(value)
    property bool flashing: false

    spacing: 8
    Text {
        Layout.preferredWidth: 64
        text: row.label
        color: Theme.tint(0.55)
        font { family: Theme.mono; pixelSize: 10; bold: true; letterSpacing: 1 }
    }
    Text {
        Layout.fillWidth: true
        text: row.value || "--"
        color: area.containsMouse && row.copyable ? Theme.accent : Theme.ink
        elide: Text.ElideMiddle
        font { family: Theme.mono; pixelSize: 13; bold: true }
        MouseArea {
            id: area
            anchors.fill: parent
            enabled: row.copyable
            hoverEnabled: true
            cursorShape: row.copyable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: row.copy()
        }
    }
    Text {
        visible: row.copyable
        text: row.flashing ? "COPIED" : "[COPY]"
        color: row.flashing ? Theme.cool : (copyArea.containsMouse ? Theme.accent : Theme.tint(0.6))
        font { family: Theme.mono; pixelSize: 10; bold: true }
        MouseArea {
            id: copyArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.copy()
        }
    }
    Timer { id: flash; interval: 1200; onTriggered: row.flashing = false }
    function copy() {
        telemetry.copyText(value)
        flashing = true
        flash.restart()
    }
}
