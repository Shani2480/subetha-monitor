import QtQuick
import QtQuick.Shapes

// A rolling telemetry graph: `historyData` (oldest first, each 0..1) drawn as a
// GPU Shape, a stroked PathPolyline over a faint filled area. The newest
// sample sits on the right edge and the trace grows leftwards until
// `capacity` samples span the width. It re-tessellates only when a sample
// arrives, never per frame. `inverted` hangs the graph from the top edge (the
// lower half of a two-way throughput plot).
Item {
    id: graph

    property var historyData: []
    property color strokeColor: "black"
    property color fillColor: Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.18)
    property real lineWidth: 1.5
    property int capacity: 24
    property bool inverted: false

    readonly property var points: {
        var pts = []
        var n = historyData ? historyData.length : 0
        if (n < 2 || width <= 0) return pts
        var step = width / Math.max(1, capacity - 1)
        var x0 = width - step * (n - 1)
        var span = height - lineWidth
        for (var i = 0; i < n; i++) {
            var f = Math.max(0, Math.min(1, Number(historyData[i]) || 0))
            pts.push(Qt.point(x0 + step * i, inverted ? lineWidth / 2 + f * span : height - lineWidth / 2 - f * span))
        }
        return pts
    }
    readonly property var area: points.length < 2 ? []
        : [Qt.point(points[0].x, inverted ? 0 : height)].concat(points)
              .concat([Qt.point(points[points.length - 1].x, inverted ? 0 : height)])

    Shape {
        anchors.fill: parent
        visible: graph.points.length >= 2
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: graph.fillColor
            PathPolyline { path: graph.area }
        }
        ShapePath {
            strokeColor: graph.strokeColor
            strokeWidth: graph.lineWidth
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: graph.points }
        }
    }
}
