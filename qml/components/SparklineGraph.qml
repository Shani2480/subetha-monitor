import QtQuick
import QtQuick.Shapes

// A rolling telemetry graph: `historyData` (oldest first, each 0..1) drawn as a
// GPU Shape, a stroked PathPolyline over a faint filled area. The newest
// sample sits on the right edge and the trace grows leftwards until
// `capacity` samples span the width. It re-tessellates only when a sample
// arrives, never per frame. `inverted` hangs the graph from the top edge (the
// lower half of a two-way throughput plot).
//
// A skin whose controls.graph is "taskmgr" draws it as Task Manager's
// Performance and Networking graphs: its own background, a grid that scrolls
// left one step per sample, a 1px trace and (with graphFill false) no area.
// `backdrop` false leaves those to the graph underneath (an overlaid trace).
Item {
    id: graph

    property var historyData: []
    property color strokeColor: "black"
    property color fillColor: Theme.taskmgr && !graph.taskFill ? "transparent"
                            : Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.18)
    property real lineWidth: Theme.taskmgr ? 1 : 1.5
    property int capacity: 24
    property bool inverted: false
    property bool backdrop: true

    readonly property bool taskFill: Theme.controls.graphFill !== false
    // samples seen, so the grid scrolls with them
    property int ticks: 0
    onHistoryDataChanged: ticks++

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

    Loader {   // Task Manager's backdrop: its panel and scrolling grid
        anchors.fill: parent
        active: Theme.taskmgr && graph.backdrop
        sourceComponent: Rectangle {
            color: Theme.ctl("graphBackground", "transparent")
            clip: true
            Canvas {
                id: gridCanvas
                anchors.fill: parent
                readonly property color line: Theme.ctl("graphGrid", Theme.tint(0.16))
                readonly property real cell: Math.max(8, Math.min(16, height / 4))
                readonly property real step: graph.width / Math.max(1, graph.capacity - 1)
                onLineChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections { target: graph; function onTicksChanged() { gridCanvas.requestPaint() } }
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = line
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    for (var y = graph.inverted ? 0 : height; graph.inverted ? y <= height : y >= 0; y += graph.inverted ? cell : -cell) {
                        var yy = Math.round(y) + 0.5
                        ctx.moveTo(0, yy); ctx.lineTo(width, yy)
                    }
                    var shift = (graph.ticks * step) % cell
                    for (var x = width - shift; x >= 0; x -= cell) {
                        var xx = Math.round(x) + 0.5
                        ctx.moveTo(xx, 0); ctx.lineTo(xx, height)
                    }
                    ctx.stroke()
                }
            }
        }
    }

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
            joinStyle: Theme.taskmgr ? ShapePath.MiterJoin : ShapePath.RoundJoin
            capStyle: Theme.taskmgr ? ShapePath.FlatCap : ShapePath.RoundCap
            PathPolyline { path: graph.points }
        }
    }
}
