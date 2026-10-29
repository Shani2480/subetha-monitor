import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "."

// A skeuomorphic round meter (a skin's geometry.gaugeShape "analog-dial"),
// beside the CPU and GPU figures: a brushed bezel (the skin's controls.dialRim
// art, or drawn), a dark face with white ticks, a glowing needle on a centre
// cap that eases to the reading, a convex glass highlight over it all, and
// the figure and its caption under the cap. A red zone marks the danger range.
Item {
    id: dial

    property real value: 0                      // in [0, max]
    property real max: 100
    property real dangerFrom: -1                // the red zone's start; < 0: none
    property color needle: Theme.ctl("needleUsage", Theme.gaugeUsage.a > 0 ? Theme.gaugeUsage : Theme.accent)
    property string figure: ""                  // the reading under the cap, "68°C"
    property string caption: ""                 // "Temperature"
    property bool live: true

    readonly property real sweep: 270           // degrees, from -135° to +135°
    readonly property real at: Math.max(0, Math.min(1, value / Math.max(1e-9, max)))
    readonly property color face: Theme.ctl("dialFace", "#15191E")
    readonly property color ticks: Theme.ctl("dialTicks", "#F2F2F2")
    readonly property color danger: Theme.ctl("dialDanger", "#E5352B")
    readonly property real r: Math.min(width, height) / 2

    implicitWidth: 72
    implicitHeight: 72

    // ---- bezel ----
    Image {
        visible: source != ""
        anchors.fill: parent
        source: Theme.controls.dialRim || ""
        sourceSize: Qt.size(width * 2, height * 2)
    }
    Rectangle {   // drawn: brushed chrome
        visible: !Theme.controls.dialRim
        anchors.fill: parent
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: "#F4F5F6" }
            GradientStop { position: 0.45; color: "#9EA3A8" }
            GradientStop { position: 0.55; color: "#C9CDD1" }
            GradientStop { position: 1; color: "#5F6368" }
        }
        border { width: 1; color: "#3A3D40" }
    }

    // ---- face ----
    Rectangle {
        id: faceDisc
        anchors.centerIn: parent
        width: dial.r * 2 * 0.84; height: width; radius: width / 2
        color: dial.face
        border { width: 1; color: Qt.darker(dial.face, 1.6) }
    }
    Shape {   // the danger zone along the rim
        visible: dial.dangerFrom >= 0 && dial.dangerFrom < dial.max
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: dial.danger
            strokeWidth: dial.r * 0.09
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: dial.r; centerY: dial.r
                radiusX: dial.r * 0.7; radiusY: dial.r * 0.7
                startAngle: -225 + dial.sweep * Math.max(0, dial.dangerFrom / dial.max)
                sweepAngle: dial.sweep * (1 - Math.max(0, dial.dangerFrom / dial.max))
            }
        }
    }
    Repeater {   // ticks: 0..100 in tens, the fives short
        model: 21
        Rectangle {
            id: tick
            required property int index
            readonly property bool major: index % 2 === 0
            readonly property real angle: -135 + dial.sweep * index / 20
            width: major ? 1.6 : 1
            height: dial.r * (major ? 0.14 : 0.08)
            color: dial.ticks
            antialiasing: true
            x: dial.r - width / 2
            y: dial.r - dial.r * 0.8
            transform: Rotation { origin.x: tick.width / 2; origin.y: dial.r * 0.8; angle: tick.angle }
        }
    }

    // ---- figure ----
    Column {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.verticalCenter; topMargin: dial.r * 0.2 }
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.figure
            color: dial.ticks
            font { family: Theme.sans; features: Theme.figures; pixelSize: Math.max(8, dial.r * 0.3); bold: true }
        }
        Text {
            visible: dial.caption !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.caption
            color: Qt.rgba(dial.ticks.r, dial.ticks.g, dial.ticks.b, 0.7)
            font { family: Theme.sans; pixelSize: Math.max(6, dial.r * 0.17) }
        }
    }

    // ---- needle ----
    Item {
        id: needleArm
        anchors.fill: parent
        rotation: -135 + dial.sweep * dial.at
        Behavior on rotation { enabled: dial.live; NumberAnimation { duration: 420; easing.type: Easing.OutBack } }
        Rectangle {
            id: needleBar
            width: Math.max(2, dial.r * 0.06)
            height: dial.r * 0.78
            radius: width / 2
            x: dial.r - width / 2
            y: dial.r - height + dial.r * 0.1
            color: dial.needle
            antialiasing: true
        }
        layer.enabled: true
        layer.effect: MultiEffect {   // its glow
            shadowEnabled: true
            shadowColor: dial.needle
            shadowBlur: 0.6
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowOpacity: 0.9
        }
    }
    Rectangle {   // centre cap
        anchors.centerIn: parent
        width: dial.r * 0.22; height: width; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: "#E6E8EA" }
            GradientStop { position: 1; color: "#4A4E52" }
        }
        border { width: 1; color: "#2A2C2E" }
    }

    // ---- the convex glass lens ----
    Rectangle {
        anchors.centerIn: faceDisc
        width: faceDisc.width; height: width; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.ctl("dialLens", Qt.rgba(1, 1, 1, 0.35)) }
            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.04) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
}
