// Shared with the Sub-Etha Guide widget (contents/ui/common/ThemeShapeContainer.qml).
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "."

// One themed surface: a card, pill, button, badge or gauge track, drawn as a
// vector outline, filled and stroked inside its bounds.
//   shapeType   "rounded" (cornerRadius), "chamfer" (corners cut at 45° by
//               chamferSize: chamferCorners, by default top-right and
//               bottom-left), "sharp", or "stadium"
//               (capsule ends, as round as stadiumMax at most)
//   borderStyle "solid", "dashed", "double" (an inner hairline), or
//               "tech-brackets" (a faint outline under bold L brackets)
//   shadowType  "flat-2d" (a hard offset copy), "soft" (a blurred offset
//               copy), "glow" (a blurred copy behind it) or "none"
// Given a `theme` (the Theme singleton by default) and a `role` ("card", "pill" or "gauge"),
// every token follows the theme, so a skin switch reshapes it in the same
// frame; any of them can be set directly instead. Content goes inside,
// `padding` in from the outline. A flat or soft shadow's offset stays inside
// the bounds (the face shrinks by it); a glow spills out.
Item {
    id: root

    property QtObject theme: Theme
    property string role: "card"                // card | pill | gauge
    property color fillColor: "transparent"
    property color strokeColor: theme ? theme.border : "transparent"
    property real strokeWidth: theme ? theme.borderWidth : 1
    property string shapeType: theme ? theme.shapeOf(role) : "rounded"
    property real cornerRadius: theme ? theme.radiusOf(role) : 8
    property real chamferSize: theme ? theme.chamferOf(role) : 10
    // which corners a chamfer cuts: "tl", "tr", "br", "bl" (the skin's geometry.chamferCorners)
    property var chamferCorners: theme && theme.chamferCorners && theme.chamferCorners.length
                                 ? theme.chamferCorners : ["tr", "bl"]
    function cutAt(corner) { return chamferCorners.indexOf(corner) >= 0 }
    property real stadiumMax: theme ? theme.stadiumMax : 24
    property string borderStyle: theme && role !== "gauge" ? theme.borderStyle : "solid"
    property bool cornerBrackets: borderStyle === "tech-brackets"
    property color bracketColor: theme ? theme.bracketColor : strokeColor
    property real bracketSize: 10
    property real bracketInset: 4
    property string shadowType: theme && role !== "gauge" ? theme.shadowType : "none"
    property color shadowColor: theme ? theme.shadow : "black"
    property real shadowOffsetX: theme ? theme.shadowX : 0
    property real shadowOffsetY: theme ? theme.shadowY : 0
    property real shadowBlur: theme ? theme.shadowBlur : 0    // px
    property real padding: 0
    default property alias content: contentSlot.data

    readonly property Item face: faceItem
    readonly property bool offsetShadow: shadowType === "flat-2d" || shadowType === "soft"
    readonly property bool blurredShadow: shadowType === "glow" || (shadowType === "soft" && shadowBlur > 0)
    readonly property string shape: shapeType === "rounded" && cornerRadius <= 0 ? "sharp" : shapeType
    // the outline's corner radius and cut, as drawn at the face's outer edge
    readonly property real radius: shape === "stadium" ? Math.min(faceItem.width / 2, faceItem.height / 2, stadiumMax)
                                 : shape === "rounded" ? Math.min(cornerRadius, faceItem.width / 2, faceItem.height / 2) : 0
    readonly property real cut: shape === "chamfer" ? Math.min(chamferSize, faceItem.width / 2, faceItem.height / 2) : 0

    // The outline `d` px in from the face's edge, as SVG path data: the stroke
    // is centred on it, so d = half the stroke keeps the stroke inside.
    function outline(d) {
        var w = faceItem.width, h = faceItem.height
        if (w <= 2 * d || h <= 2 * d) return ""
        var x0 = d, y0 = d, x1 = w - d, y1 = h - d
        if (cut > 0) {
            var c = Math.max(0, cut - d * (2 - Math.SQRT2))    // a parallel 45° cut, d further in
            var tl = cutAt("tl") ? c : 0, tr = cutAt("tr") ? c : 0, br = cutAt("br") ? c : 0, bl = cutAt("bl") ? c : 0
            return `M ${x0 + tl} ${y0} H ${x1 - tr} L ${x1} ${y0 + tr} V ${y1 - br} L ${x1 - br} ${y1}`
                 + ` H ${x0 + bl} L ${x0} ${y1 - bl} V ${y0 + tl} Z`
        }
        var r = Math.max(0, radius - d)
        if (r === 0) return `M ${x0} ${y0} H ${x1} V ${y1} H ${x0} Z`
        return `M ${x0 + r} ${y0} H ${x1 - r} A ${r} ${r} 0 0 1 ${x1} ${y0 + r} V ${y1 - r}`
             + ` A ${r} ${r} 0 0 1 ${x1 - r} ${y1} H ${x0 + r} A ${r} ${r} 0 0 1 ${x0} ${y1 - r}`
             + ` V ${y0 + r} A ${r} ${r} 0 0 1 ${x0 + r} ${y0} Z`
    }

    Item {   // shadow: the face's silhouette, offset and/or blurred
        visible: root.shadowType !== "none" && root.shadowColor.a > 0
        x: faceItem.x + (root.offsetShadow ? root.shadowOffsetX : 0)
        y: faceItem.y + (root.offsetShadow ? root.shadowOffsetY : 0)
        width: faceItem.width; height: faceItem.height
        layer.enabled: visible && root.blurredShadow
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: Math.min(1, Math.max(root.shadowBlur, root.shadowType === "glow" ? 4 : 0) / 32)
            blurMax: 32
            autoPaddingEnabled: true
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.shadowColor
                strokeColor: "transparent"
                strokeWidth: -1
                PathSvg { path: root.outline(0) }
            }
        }
    }

    Item {
        id: faceItem
        anchors {
            fill: parent
            leftMargin: root.offsetShadow ? Math.max(0, -root.shadowOffsetX) : 0
            topMargin: root.offsetShadow ? Math.max(0, -root.shadowOffsetY) : 0
            rightMargin: root.offsetShadow ? Math.max(0, root.shadowOffsetX) : 0
            bottomMargin: root.offsetShadow ? Math.max(0, root.shadowOffsetY) : 0
        }

        Shape {
            anchors.fill: parent
            // the curve renderer draws no dashes
            preferredRendererType: root.borderStyle === "dashed" ? Shape.GeometryRenderer : Shape.CurveRenderer
            ShapePath {
                id: outlinePath
                readonly property real w: root.borderStyle === "tech-brackets" ? Math.min(1, root.strokeWidth) : root.strokeWidth
                fillColor: root.fillColor
                strokeColor: w > 0 ? (root.borderStyle === "tech-brackets"
                                      ? Qt.rgba(root.strokeColor.r, root.strokeColor.g, root.strokeColor.b, root.strokeColor.a * 0.45)
                                      : root.strokeColor) : "transparent"
                strokeWidth: w > 0 ? w : -1
                strokeStyle: root.borderStyle === "dashed" ? ShapePath.DashLine : ShapePath.SolidLine
                dashPattern: [4, 3]
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.FlatCap
                PathSvg { path: root.outline(Math.max(0, outlinePath.w) / 2) }
            }
            ShapePath {   // double: a hairline inside the border
                id: hairline
                readonly property bool on: root.borderStyle === "double" && root.strokeWidth > 0
                fillColor: "transparent"
                strokeColor: on ? root.strokeColor : "transparent"
                strokeWidth: on ? Math.max(1, root.strokeWidth / 2) : -1
                joinStyle: ShapePath.MiterJoin
                PathSvg { path: hairline.on ? root.outline(root.strokeWidth * 2.25) : "" }
            }
        }

        // L-shaped marks on the corners, clear of a rounded corner's curve;
        // none on the two a chamfer cuts away.
        Repeater {
            model: root.cornerBrackets ? 4 : 0
            Item {
                required property int index
                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index >= 2
                readonly property real inset: root.bracketInset + root.radius * 0.3
                readonly property real arm: Math.max(1.5, Math.min(2, root.strokeWidth))
                visible: !(root.cut > 0 && root.cutAt((atBottom ? "b" : "t") + (atRight ? "r" : "l")))
                width: root.bracketSize; height: width
                x: atRight ? faceItem.width - width - inset : inset
                y: atBottom ? faceItem.height - height - inset : inset
                Rectangle {   // horizontal arm
                    width: parent.width; height: parent.arm
                    y: parent.atBottom ? parent.height - height : 0
                    color: root.bracketColor
                }
                Rectangle {   // vertical arm
                    width: parent.arm; height: parent.height
                    x: parent.atRight ? parent.width - width : 0
                    color: root.bracketColor
                }
            }
        }

        Item {
            id: contentSlot
            anchors { fill: parent; margins: root.padding }
        }
    }
}
