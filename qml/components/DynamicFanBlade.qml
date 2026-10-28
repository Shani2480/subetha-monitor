import QtQuick
import QtQuick.Shapes

// A vector fan whose blades turn in proportion to the fan's duty (its share
// of full speed): still at 0, `maxTurns` revolutions a second at 100 %.
// Turning at the literal RPM cannot be drawn: at 60 frames a second a
// four-bladed fan looks the same every 90°, so anything past ~45° a frame
// (2.5 turns a second is 15°) aliases into a stutter or a backwards crawl.
// Rather than restarting a fixed-duration animation whenever the reading
// changes (a visible jump), a FrameAnimation integrates the angle every frame
// from a displayed speed that eases towards the reading, so a fan spins up
// and coasts down with some inertia. From half speed up, trailing ghost
// copies and a hub disc add a motion blur.
Item {
    id: root

    property real duty: 0                  // 0..1, the fan's share of full speed
    property real maxTurns: 2.5            // revolutions a second drawn at 100 %
    property color strokeColor: "#00FF66"
    property real inertia: 0.6             // seconds to close ~63% of a speed change
    implicitWidth: 32
    implicitHeight: 32

    readonly property real target: Math.max(0, Math.min(1, duty))
    property real shownDuty: 0                // eased duty actually drawn
    property real angle: 0
    // 0 below half speed, 1 at full: how much motion blur to draw.
    readonly property real blur: Math.max(0, Math.min(1, (shownDuty - 0.5) / 0.5))

    FrameAnimation {
        running: root.visible && (root.target > 0 || root.shownDuty > 0.001)
        onTriggered: {
            var dt = Math.min(0.1, frameTime)
            var k = 1 - Math.exp(-dt / Math.max(0.01, root.inertia))
            root.shownDuty += (root.target - root.shownDuty) * k
            if (root.target === 0 && root.shownDuty < 0.001) root.shownDuty = 0
            root.angle = (root.angle + root.shownDuty * root.maxTurns * 360 * dt) % 360
        }
    }

    // Four swept blades around a hub, in a 24-unit box.
    readonly property string bladePath:
          "M12 10.6 C11.8 7 12.8 4.2 15.6 3.6 C17.2 5.4 16 8.8 13.2 11 Z "
        + "M13.4 12 C17 11.8 19.8 12.8 20.4 15.6 C18.6 17.2 15.2 16 13 13.2 Z "
        + "M12 13.4 C12.2 17 11.2 19.8 8.4 20.4 C6.8 18.6 8 15.2 10.8 13 Z "
        + "M10.6 12 C7 12.2 4.2 11.2 3.6 8.4 C5.4 6.8 8.8 8 11 10.8 Z"

    Rectangle {   // blur disc swept by the blade tips
        anchors.centerIn: parent
        width: parent.width * 0.74; height: width
        radius: width / 2
        color: Qt.rgba(root.strokeColor.r, root.strokeColor.g, root.strokeColor.b, 0.16 * root.blur)
        border.width: 1
        border.color: Qt.rgba(root.strokeColor.r, root.strokeColor.g, root.strokeColor.b, 0.35 * root.blur)
        visible: root.blur > 0
    }

    Repeater {   // the blades, then ghosts trailing behind them
        model: 4
        Shape {
            required property int index
            anchors.fill: parent
            visible: index === 0 || root.blur > 0
            opacity: index === 0 ? 1 - 0.35 * root.blur : root.blur * (0.42 - index * 0.1)
            rotation: root.angle - index * 11 * root.blur
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                scale: Qt.size(root.width / 24, root.height / 24)
                strokeColor: root.strokeColor
                strokeWidth: 1
                fillColor: Qt.rgba(root.strokeColor.r, root.strokeColor.g, root.strokeColor.b, 0.55)
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: root.bladePath }
            }
        }
    }

    Rectangle {   // hub
        anchors.centerIn: parent
        width: Math.max(4, parent.width * 0.2); height: width
        radius: width / 2
        color: root.strokeColor
    }
}
