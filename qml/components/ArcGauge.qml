import QtQuick
import QtQuick.Shapes
import "."

// A 240° dial for a transfer rate, on a log scale from 0.1 MB/s to `maxMBps`
// so idle trickles and full-speed bursts both read. The needle eases between
// samples.
Item {
    id: gauge

    property real bytesPerSec: 0
    property real maxMBps: 4000
    property string label: "READ"
    property color tone: Theme.ink

    readonly property real mbps: bytesPerSec / 1048576
    readonly property real fraction: mbps <= 0.1 ? Math.max(0, mbps / 0.1) * 0.02
        : Math.min(1, 0.02 + 0.98 * Math.log(mbps / 0.1) / Math.log(maxMBps / 0.1))
    property real shown: fraction
    Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    readonly property real startAngle: 150              // degrees, clockwise from 3 o'clock
    readonly property real sweep: 240
    readonly property real r: Math.min(width, height / 0.85) / 2 - 4
    readonly property point c: Qt.point(width / 2, r + 4)
    implicitWidth: 120
    implicitHeight: 104

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {   // track
            strokeColor: Theme.tint(Theme.dark ? 0.25 : 0.3)
            strokeWidth: 6
            fillColor: "transparent"
            capStyle: Theme.roundCaps ? ShapePath.RoundCap : ShapePath.FlatCap
            PathAngleArc { centerX: gauge.c.x; centerY: gauge.c.y; radiusX: gauge.r - 3; radiusY: gauge.r - 3
                           startAngle: gauge.startAngle; sweepAngle: gauge.sweep }
        }
        ShapePath {   // value
            strokeColor: gauge.tone
            strokeWidth: 6
            fillColor: "transparent"
            capStyle: Theme.roundCaps ? ShapePath.RoundCap : ShapePath.FlatCap
            PathAngleArc { centerX: gauge.c.x; centerY: gauge.c.y; radiusX: gauge.r - 3; radiusY: gauge.r - 3
                           startAngle: gauge.startAngle; sweepAngle: Math.max(0.5, gauge.sweep * gauge.shown) }
        }
    }
    Repeater {   // ticks at 1, 10, 100, 1000 MB/s
        model: [1, 10, 100, 1000]
        Rectangle {
            required property var modelData
            readonly property real f: 0.02 + 0.98 * Math.log(modelData / 0.1) / Math.log(gauge.maxMBps / 0.1)
            readonly property real a: (gauge.startAngle + gauge.sweep * f) * Math.PI / 180
            width: 2; height: 6
            color: Theme.tint(0.5)
            x: gauge.c.x + Math.cos(a) * (gauge.r - 14) - width / 2
            y: gauge.c.y + Math.sin(a) * (gauge.r - 14) - height / 2
            rotation: (gauge.startAngle + gauge.sweep * f) + 90
        }
    }
    Column {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: gauge.c.y - 14 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: gauge.mbps >= 100 ? gauge.mbps.toFixed(0) : gauge.mbps.toFixed(1)
            color: Theme.ink
            font { family: Theme.mono; features: Theme.figures; pixelSize: 18; bold: true }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: gauge.label + " MB/s"
            color: gauge.tone
            font { family: Theme.mono; features: Theme.figures; pixelSize: 9; bold: true; letterSpacing: 1 }
        }
    }
}
