import QtQuick
import QtQuick.Shapes
import "."

// A cartoon semicircular meter (a skin's controls.dialStyle "semicircle"):
// wedges shading green to yellow to red across the half disc, a black
// needle on a red cap easing to the reading, the caption under it.
Item {
    id: semi

    property real value: 0                      // 0..1
    property string caption: ""
    property string figure: ""
    property bool live: true

    readonly property real r: Math.min(width / 2, height - captionText.height - 2)
    readonly property real at: Math.max(0, Math.min(1, value))
    readonly property real outline: Theme.cartoon ? 3 : 1.5
    readonly property var wedges: ["#3DBE4B", "#9BD13A", "#F2D231", "#F59A2B", "#E5352B"]

    implicitWidth: 76
    implicitHeight: 58

    Item {
        id: face
        width: semi.r * 2; height: semi.r
        anchors.horizontalCenter: parent.horizontalCenter
        Repeater {   // the wedges, left to right
            model: semi.wedges.length
            Shape {
                id: wedge
                required property int index
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.border
                    strokeWidth: semi.outline
                    joinStyle: ShapePath.RoundJoin
                    fillColor: semi.wedges[wedge.index]
                    startX: semi.r; startY: semi.r
                    PathAngleArc {
                        centerX: semi.r; centerY: semi.r
                        radiusX: semi.r - semi.outline / 2; radiusY: semi.r - semi.outline / 2
                        startAngle: 180 + 180 * wedge.index / semi.wedges.length
                        sweepAngle: 180 / semi.wedges.length
                    }
                    PathLine { x: semi.r; y: semi.r }
                }
            }
        }
    }
    Item {   // the needle
        x: face.x; y: face.y
        width: face.width; height: face.height
        rotation: -90 + 180 * semi.at
        transformOrigin: Item.Bottom
        Behavior on rotation { enabled: semi.live; NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
        Rectangle {
            width: 3; height: semi.r * 0.86
            radius: 1.5
            x: semi.r - width / 2
            y: semi.r - height
            color: "#111111"
            antialiasing: true
        }
    }
    Rectangle {   // the cap
        x: face.x + semi.r - width / 2; y: face.y + semi.r - height / 2
        width: semi.r * 0.26; height: width; radius: width / 2
        color: "#E5352B"
        border { width: semi.outline > 2 ? 2 : 1; color: "#111111" }
    }
    Text {
        id: captionText
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        text: semi.figure ? semi.caption + " " + semi.figure : semi.caption
        color: Theme.ink
        font { family: Theme.sans; features: Theme.figures; pixelSize: 9; bold: true }
    }
}
