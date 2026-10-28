import QtQuick
import "."

// A segmented meter in the gauges' block style. `fill` defaults to the
// load colour of the level.
Item {
    id: bar

    property real fraction: 0            // 0..1
    property int segments: 24
    property real segmentHeight: 8
    property color fill: Theme.load(fraction * 100)

    readonly property int filled: Math.round(Math.max(0, Math.min(1, fraction)) * segments)
    implicitWidth: 160
    implicitHeight: segmentHeight

    Row {
        spacing: 2
        Repeater {
            model: bar.segments
            Rectangle {
                required property int index
                readonly property bool on: index < bar.filled
                width: (bar.width - 2 * (bar.segments - 1)) / bar.segments
                height: bar.segmentHeight
                radius: Theme.dark ? 0 : Math.min(2, height / 2)
                color: on ? bar.fill : "transparent"
                border.width: 1
                border.color: on ? bar.fill : Theme.tint(Theme.dark ? 0.3 : 0.45)
            }
        }
    }
}
