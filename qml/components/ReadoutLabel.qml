import QtQuick
import QtQuick.Layouts
import "."

// A small caption over a mono reading: "TEMP" / "64°C".
ColumnLayout {
    id: readout

    property string label: ""
    property string value: ""
    property color valueColor: Theme.ink
    property int valueSize: 14

    spacing: 1
    Text {
        text: readout.label
        color: Theme.tint(0.55)
        font { family: Theme.mono; pixelSize: 9; bold: true; letterSpacing: 1 }
    }
    Text {
        Layout.fillWidth: true
        text: readout.value
        color: readout.valueColor
        elide: Text.ElideRight
        font { family: Theme.mono; pixelSize: readout.valueSize; bold: true }
    }
}
