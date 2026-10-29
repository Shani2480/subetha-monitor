import QtQuick
import QtQuick.Shapes

// The window's outline under a skin's chrome: its own top and bottom corner
// radii (Luna's round top over square bottom corners), or 45° cuts
// (Kiroshi). Fills for the frame's mask, strokes for its border.
Shape {
    id: frame

    property string shapeType: "rounded"          // rounded, chamfer
    property real topRadius: 8
    property real bottomRadius: 0
    property real cut: 14
    property var corners: ["tl", "br"]               // which corners a chamfer cuts
    property color fillColor: "transparent"
    property color strokeColor: "transparent"
    property real strokeWidth: 0

    preferredRendererType: Shape.CurveRenderer
    readonly property real i: strokeWidth / 2      // the stroke sits inside the edge
    readonly property real w: width - i
    readonly property real h: height - i
    readonly property real tr: Math.max(0, Math.min(topRadius - i, height / 2))
    readonly property real br: Math.max(0, Math.min(bottomRadius - i, height / 2))
    readonly property real c: Math.max(0, cut - i)
    function k(corner) { return corners.indexOf(corner) >= 0 ? c : 0 }
    readonly property string path: shapeType === "chamfer"
        ? "M " + (i + k("tl")) + " " + i + " L " + (w - k("tr")) + " " + i + " L " + w + " " + (i + k("tr"))
          + " L " + w + " " + (h - k("br")) + " L " + (w - k("br")) + " " + h
          + " L " + (i + k("bl")) + " " + h + " L " + i + " " + (h - k("bl")) + " L " + i + " " + (i + k("tl")) + " Z"
        : "M " + (i + tr) + " " + i + " L " + (w - tr) + " " + i
          + (tr > 0 ? " A " + tr + " " + tr + " 0 0 1 " + w + " " + (i + tr) : "")
          + " L " + w + " " + (h - br)
          + (br > 0 ? " A " + br + " " + br + " 0 0 1 " + (w - br) + " " + h : "")
          + " L " + (i + br) + " " + h
          + (br > 0 ? " A " + br + " " + br + " 0 0 1 " + i + " " + (h - br) : "")
          + " L " + i + " " + (i + tr)
          + (tr > 0 ? " A " + tr + " " + tr + " 0 0 1 " + (i + tr) + " " + i : "") + " Z"

    ShapePath {
        fillColor: frame.fillColor
        strokeColor: frame.strokeWidth > 0 ? frame.strokeColor : "transparent"
        strokeWidth: frame.strokeWidth
        joinStyle: ShapePath.MiterJoin
        PathSvg { path: frame.path }
    }
}
