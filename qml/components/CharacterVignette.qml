import QtQuick
import QtQuick.Shapes
import "."

// A skin's character (narrative.vignettes) standing in a corner, about 56px
// tall, with a comic speech bubble to its left: white, an ink outline, the
// tail pointing at the character.
Item {
    id: vig

    property var vignette: null                 // { at, art, text }
    property real size: 56

    visible: !!vignette
    implicitWidth: visible ? figure.width + (bubble.visible ? bubble.width + 6 : 0) : 0
    implicitHeight: visible ? Math.max(size, bubble.height) : 0
    width: implicitWidth
    height: implicitHeight

    Image {
        id: figure
        anchors { right: parent.right; bottom: parent.bottom }
        height: vig.size
        width: vig.size * implicitWidth / Math.max(1, implicitHeight)
        source: vig.vignette ? vig.vignette.art : ""
        sourceSize.height: vig.size * 2
        fillMode: Image.PreserveAspectFit
    }

    Rectangle {
        id: bubble
        visible: !!vig.vignette && vig.vignette.text !== ""
        anchors { right: figure.left; rightMargin: 8; top: parent.top }
        width: Math.min(170, line.implicitWidth + 16)
        height: line.implicitHeight + 10
        radius: 9
        color: "#FFFFFF"
        border { width: 2; color: "#111111" }
        Text {
            id: line
            anchors.centerIn: parent
            width: Math.min(154, implicitWidth)
            text: vig.vignette ? vig.vignette.text : ""
            wrapMode: Text.WordWrap
            color: "#111111"
            font { family: Theme.sans; pixelSize: 10; bold: true }
        }
        Shape {   // the tail, toward the character
            x: parent.width - 3; y: parent.height * 0.55
            width: 12; height: 10
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#111111"; strokeWidth: 2; fillColor: "#FFFFFF"
                startX: 0; startY: 0
                PathLine { x: 11; y: 7 }
                PathLine { x: 0; y: 8 }
            }
        }
    }
}
