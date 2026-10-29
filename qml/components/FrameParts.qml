import QtQuick
import QtQuick.Shapes
import "."

// The built frames' pieces around the window (Theme.frameStyle), each
// cosmetic and drawn here from the skin's colours, with its art where it
// names some. MainAppWindow places them:
//   Wing      "console": a side panel of switches and buttons (left: rocker
//             switches, red / yellow / green buttons, pressure gauges;
//             right: levers, small dials and glass bulbs)
//   Conduit   "console": a pipe along the bottom whose LED segments light
//             green to amber with the CPU's load
//   Plating   "scrap": galvanized plates behind everything, with ink seams,
//             welded lines and corner rivets
//   Toolbelt  "scrap": the frame's toolbelt art as a bottom workbench rail
//   CandyEdge "candy": the frame's decorations tiled along an edge
QtObject {
    id: parts

    readonly property real ink: Theme.cartoon ? 3 : 2

    component Wing: Item {
        id: wing
        property bool onRight: false
        implicitWidth: 46
        readonly property color line: Theme.border
        Rectangle {   // the panel
            anchors { fill: parent; topMargin: 6; bottomMargin: 6; leftMargin: wing.onRight ? 2 : 6; rightMargin: wing.onRight ? 6 : 2 }
            radius: 6
            color: Qt.darker(Theme.card, Theme.dark ? 0.8 : 1.08)
            border { width: Theme.cartoon ? 3 : 2; color: wing.line }
            Column {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 10 }
                spacing: 12
                Repeater {   // left: rocker switches; right: levers
                    model: 2
                    Rectangle {
                        required property int index
                        width: 18; height: 28; radius: 3
                        color: "#3B3F45"
                        border { width: 2; color: wing.line }
                        Rectangle {
                            width: wing.onRight ? 4 : 12; height: wing.onRight ? 20 : 12
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: wing.onRight ? (index ? 2 : 6) : (index ? 3 : parent.height - height - 3)
                            radius: wing.onRight ? 2 : 2
                            color: wing.onRight ? "#D8D8D8" : index ? "#E5352B" : "#3DBE4B"
                            Rectangle { visible: wing.onRight; width: 10; height: 10; radius: 5; x: -3; y: -3; color: "#E5352B"; border { width: 1.5; color: wing.line } }
                        }
                    }
                }
                Repeater {   // left: red / yellow / green buttons; right: glass bulbs
                    model: 3
                    Rectangle {
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 16; height: wing.onRight ? 20 : 16; radius: 8
                        color: wing.onRight ? Qt.rgba(0.6, 1, 0.7, 0.35 + 0.2 * index) : ["#E5352B", "#F2D231", "#3DBE4B"][index]
                        border { width: 2; color: wing.line }
                        Rectangle { x: 3; y: 3; width: 5; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.6) }
                    }
                }
                Repeater {   // small gauges / dial meters
                    model: 2
                    Rectangle {
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 26; height: 26; radius: 13
                        color: "#F4F1E6"
                        border { width: 2; color: wing.line }
                        Rectangle {
                            width: 2; height: 10
                            x: parent.width / 2 - 1; y: parent.height / 2 - height
                            transformOrigin: Item.Bottom
                            rotation: -60 + (index * 70) + (wing.onRight ? 30 : 0)
                            color: "#111111"
                        }
                    }
                }
            }
        }
    }

    component Conduit: Item {
        id: pipe
        property real load: 0                   // 0..1
        implicitHeight: 22
        Rectangle {
            anchors { fill: parent; margins: 3 }
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0; color: "#9AA1A8" }
                GradientStop { position: 0.5; color: "#5E656C" }
                GradientStop { position: 1; color: "#3C4247" }
            }
            border { width: Theme.cartoon ? 3 : 2; color: Theme.border }
            Row {
                anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
                spacing: 4
                readonly property int count: Math.max(8, Math.floor((width + 4) / 16))
                Repeater {
                    model: parent.count
                    Rectangle {
                        required property int index
                        readonly property real at: index / Math.max(1, parent.count - 1)
                        readonly property bool lit: at <= pipe.load
                        width: 12; height: 6; radius: 2
                        color: lit ? Qt.rgba(0.24 + 0.72 * at, 0.85 - 0.25 * at, 0.2, 1) : "#2A2E32"
                        border { width: 1; color: "#111111" }
                    }
                }
            }
        }
    }

    component Plating: Canvas {
        id: plate
        readonly property color seam: Theme.border
        readonly property color rivet: Theme.frame && Theme.frame.rivets ? Theme.frame.rivets : "#B8BEC4"
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onSeamChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            // irregular plates: a few cuts that wander a little
            ctx.strokeStyle = seam
            ctx.lineWidth = 2.5
            ctx.lineJoin = "round"
            var cols = [0.31, 0.64], rows = [0.42, 0.78]
            cols.forEach(function (c, i) {
                ctx.beginPath()
                ctx.moveTo(width * c, 0)
                ctx.lineTo(width * (c + 0.012 * (i ? 1 : -1)), height * 0.5)
                ctx.lineTo(width * c, height)
                ctx.stroke()
            })
            rows.forEach(function (r, i) {
                ctx.beginPath()
                ctx.moveTo(0, height * r)
                ctx.lineTo(width * 0.5, height * (r + 0.01 * (i ? -1 : 1)))
                ctx.lineTo(width, height * r)
                ctx.stroke()
            })
            // welded seams: a bead of short ticks
            ctx.lineWidth = 1.2
            ctx.strokeStyle = Qt.rgba(seam.r, seam.g, seam.b, 0.6)
            for (var x = width * 0.08; x < width * 0.28; x += 6) {
                ctx.beginPath(); ctx.moveTo(x, height * 0.42 - 3); ctx.lineTo(x + 3, height * 0.42 + 3); ctx.stroke()
            }
            for (var y = height * 0.5; y < height * 0.74; y += 6) {
                ctx.beginPath(); ctx.moveTo(width * 0.64 - 3, y); ctx.lineTo(width * 0.64 + 3, y + 3); ctx.stroke()
            }
            // rivets in the corners
            var at = [[14, 14], [width - 14, 14], [14, height - 14], [width - 14, height - 14]]
            at.forEach(function (p) {
                ctx.beginPath(); ctx.arc(p[0], p[1], 4.5, 0, 2 * Math.PI)
                ctx.fillStyle = rivet; ctx.fill()
                ctx.lineWidth = 1.5; ctx.strokeStyle = seam; ctx.stroke()
                ctx.beginPath(); ctx.arc(p[0] - 1.2, p[1] - 1.2, 1.4, 0, 2 * Math.PI)
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.6); ctx.fill()
            })
        }
    }

    component Toolbelt: Image {
        source: Theme.frame && Theme.frame.toolbelt ? Theme.frame.toolbelt : ""
        sourceSize.height: 68
        fillMode: Image.TileHorizontally
        verticalAlignment: Image.AlignBottom
    }

    component CandyEdge: Image {
        property bool vertical: false
        source: Theme.frame && Theme.frame.decorations ? Theme.frame.decorations : ""
        sourceSize: Qt.size(22, 22)
        fillMode: vertical ? Image.TileVertically : Image.TileHorizontally
        opacity: 0.55
    }

    // the candy box's slightly wavy ink border
    component WavyBorder: Canvas {
        id: wavy
        property color ink: Theme.border
        property real lineWidth: 2.5
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onInkChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = ink
            ctx.lineWidth = lineWidth
            ctx.lineJoin = "round"
            var m = lineWidth / 2 + 1.5, w = width - m, h = height - m, a = 1.2, p = 46
            function wave(t) { return a * Math.sin(t / p * 2 * Math.PI) }
            ctx.beginPath()
            ctx.moveTo(m, m)
            for (var x = m; x <= w; x += 4) ctx.lineTo(x, m + wave(x))
            for (var y = m; y <= h; y += 4) ctx.lineTo(w + wave(y), y)
            for (x = w; x >= m; x -= 4) ctx.lineTo(x, h + wave(x))
            for (y = h; y >= m; y -= 4) ctx.lineTo(m + wave(y), y)
            ctx.closePath()
            ctx.stroke()
        }
    }
}
