import QtQuick
import "."

// Ooze hanging from an edge (features.slimeDrips): a few rounded drips in the
// frame's slime colour that slowly stretch and recover, each on its own beat.
// Lay it along the edge's bottom; it draws downwards from its top.
Item {
    id: drips

    property int count: 3 + Math.min(3, Math.floor(width / 160))     // 3 to 6
    property color colour: Theme.frame && Theme.frame.slime ? Theme.frame.slime : Theme.accent

    visible: Theme.slimeDrips
    height: 18
    z: 5

    Repeater {
        model: drips.visible ? drips.count : 0
        Item {
            id: drip
            required property int index
            // spread unevenly along the edge, each a little different
            readonly property real at: (index + 0.5) / drips.count + (index % 2 ? 0.06 : -0.04)
            readonly property real w: 7 + (index * 37 % 5)
            property real stretch: 0.5
            x: drips.width * Math.min(0.95, Math.max(0.02, at)) - w / 2
            width: w
            height: drips.height
            Rectangle {   // the strand
                width: drip.w * 0.7; x: (drip.w - width) / 2
                height: drip.height * drip.stretch
                radius: width / 2
                color: drips.colour
            }
            Rectangle {   // the bulb at its end
                width: drip.w; height: drip.w
                radius: width / 2
                y: drip.height * drip.stretch - height * 0.6
                color: drips.colour
                Rectangle { x: parent.width * 0.25; y: parent.height * 0.2; width: parent.width * 0.25; height: width; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.45) }
            }
            SequentialAnimation on stretch {
                running: drips.visible
                loops: Animation.Infinite
                PauseAnimation { duration: 600 + drip.index * 420 }
                NumberAnimation { to: 0.95; duration: 2200 + drip.index * 300; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.45; duration: 1400; easing.type: Easing.OutBack }
            }
        }
    }
}
