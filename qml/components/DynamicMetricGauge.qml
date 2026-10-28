import QtQuick
import QtQuick.Shapes
import "."

// One gauge in the active look's own shape (the skin's geometry.gaugeShape):
//   "segmented"  LED blocks; on a CRT skin (features.enableCrtScanlines) ASCII cells
//   "flat"       a square bar, no radius
//   "stadium"    a capsule with a specular highlight over its fill
//   "chamfer"    a bar with its ends cut at 45°
//   "wavy"       a sine wave up to the value, then the flat track
// The Guide's own look keeps its segmented blocks. `value` fills it;
// `secondary` (0..1, below 0 none) lays a translucent wash behind, as the
// temperature behind a load. `glow` rings the track (a critical reading).
Item {
    id: gauge

    property real value: 0                         // 0..1
    property real secondary: -1                    // 0..1; < 0: none
    property color fillColor: Theme.gaugeLoad(value * 100)
    property color secondaryColor: Theme.gaugeTemp
    property real secondaryOpacity: 0.35
    property color trackColor: Theme.gaugeTrack
    property string shape: Theme.skinned ? Theme.gaugeShape || "segmented" : "segmented"
    property int segments: 24
    property bool glow: false
    property real glowOpacity: 1
    property color glowColor: Theme.critColor
    property bool live: true                       // runs the wavy gauge's motion

    readonly property real v: Math.max(0, Math.min(1, value))
    readonly property real s: Math.max(0, Math.min(1, secondary))
    readonly property bool hasSecondary: secondary >= 0
    readonly property bool ascii: shape === "segmented" && Theme.skinned && Theme.fx.crtScanlines
    // the Guide's own blocks: outlined; a skin's: the track colour lit by the fill
    readonly property bool outlined: !Theme.skinned

    implicitWidth: 160
    implicitHeight: 9

    Rectangle {   // the glow around the track
        visible: gauge.glow
        anchors { fill: parent; margins: -2 }
        radius: gauge.shape === "stadium" || gauge.shape === "wavy" ? height / 2 : Theme.small(4)
        color: "transparent"
        border { width: 2; color: gauge.glowColor }
        opacity: 0.55 * gauge.glowOpacity
    }

    Loader {
        anchors.fill: parent
        sourceComponent: gauge.ascii ? asciiBar
                       : ({ flat: flatBar, stadium: stadiumBar, chamfer: chamferBar, wavy: wavyBar })[gauge.shape] || blocks
    }

    // ---- segmented: LED blocks ----
    Component {
        id: blocks
        Row {
            id: row
            spacing: 2
            readonly property int lit: Math.round(gauge.v * gauge.segments)
            readonly property int washed: Math.round(gauge.s * gauge.segments)
            Repeater {
                model: gauge.segments
                Rectangle {
                    required property int index
                    readonly property bool on: index < row.lit
                    width: (gauge.width - row.spacing * (gauge.segments - 1)) / gauge.segments
                    height: gauge.height
                    radius: Theme.small(Math.min(2, height / 2))
                    color: gauge.outlined ? "transparent" : gauge.trackColor
                    border.width: gauge.outlined ? 1 : 0
                    border.color: on ? gauge.fillColor : Theme.tint(Theme.dark ? 0.3 : 0.45)
                    Rectangle {   // the secondary wash, behind
                        visible: gauge.hasSecondary && index < row.washed
                        anchors.fill: parent
                        radius: parent.radius
                        color: gauge.secondaryColor
                        opacity: gauge.secondaryOpacity
                    }
                    Rectangle {   // the value, in front (inset when there's a wash to show around it)
                        visible: parent.on
                        anchors { fill: parent; margins: !gauge.hasSecondary ? 0 : parent.height >= 7 ? 2 : 1 }
                        radius: gauge.hasSecondary ? Theme.small(1) : parent.radius
                        color: gauge.fillColor
                    }
                }
            }
        }
    }

    // ---- segmented on a CRT: text cells ----
    Component {
        id: asciiBar
        Row {
            id: cells
            readonly property int lit: Math.round(gauge.v * gauge.segments)
            readonly property int washed: Math.round(gauge.s * gauge.segments)
            Repeater {
                model: gauge.segments
                Text {
                    required property int index
                    readonly property bool on: index < cells.lit
                    readonly property bool wash: !on && gauge.hasSecondary && index < cells.washed
                    width: gauge.width / gauge.segments
                    height: gauge.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: on ? "█" : wash ? "▒" : "░"
                    // unlit cells are the same phosphor, dimmed, as on a real terminal
                    color: on ? gauge.fillColor : wash ? gauge.secondaryColor : gauge.fillColor
                    opacity: on ? 1 : wash ? Math.max(0.5, gauge.secondaryOpacity) : 0.35
                    font { family: Theme.mono; pixelSize: Math.max(8, gauge.height * 1.6) }
                }
            }
        }
    }

    // ---- flat: square ----
    Component {
        id: flatBar
        Rectangle {
            color: gauge.trackColor
            Rectangle {
                visible: gauge.hasSecondary
                width: parent.width * gauge.s; height: parent.height
                color: gauge.secondaryColor
                opacity: gauge.secondaryOpacity
            }
            Rectangle {
                width: parent.width * gauge.v
                height: gauge.hasSecondary ? Math.max(2, parent.height * 0.6) : parent.height
                anchors.verticalCenter: parent.verticalCenter
                color: gauge.fillColor
            }
        }
    }

    // ---- stadium: a capsule with a specular highlight ----
    Component {
        id: stadiumBar
        Rectangle {
            radius: height / 2
            color: gauge.trackColor
            clip: true
            Rectangle {
                visible: gauge.hasSecondary && gauge.s > 0
                width: Math.max(parent.height, parent.width * gauge.s); height: parent.height
                radius: height / 2
                color: gauge.secondaryColor
                opacity: gauge.secondaryOpacity
            }
            Rectangle {
                visible: gauge.v > 0
                width: Math.max(parent.height, parent.width * gauge.v); height: parent.height
                radius: height / 2
                color: gauge.fillColor
                Rectangle {   // the specular: a soft white sheen over the top half
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
                    height: parent.height / 2
                    radius: height / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.55) }
                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.05) }
                    }
                }
            }
        }
    }

    // ---- chamfer: 45° ends ----
    Component {
        id: chamferBar
        Item {
            id: ch
            readonly property real cut: Math.min(height, width / 4)
            component Cut: Shape {
                id: cutShape
                property color fill
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: cutShape.fill
                    startX: ch.cut; startY: 0
                    PathLine { x: ch.width; y: 0 }
                    PathLine { x: ch.width - ch.cut; y: ch.height }
                    PathLine { x: 0; y: ch.height }
                    PathLine { x: ch.cut; y: 0 }
                }
            }
            Cut { anchors.fill: parent; fill: gauge.trackColor }
            Item {
                visible: gauge.hasSecondary
                width: parent.width * gauge.s; height: parent.height; clip: true
                opacity: gauge.secondaryOpacity
                Cut { width: ch.width; height: ch.height; fill: gauge.secondaryColor }
            }
            Item {
                width: parent.width * gauge.v; height: parent.height; clip: true
                Cut { width: ch.width; height: ch.height; fill: gauge.fillColor }
            }
        }
    }

    // ---- wavy: a sine wave to the value, the flat track after it ----
    Component {
        id: wavyBar
        Canvas {
            id: wave
            property real phase: 0
            NumberAnimation on phase {
                from: 0; to: 2 * Math.PI; duration: 1800
                loops: Animation.Infinite
                running: gauge.live && wave.visible && gauge.v > 0
            }
            onPhaseChanged: requestPaint()
            onWidthChanged: requestPaint()
            Connections {
                target: gauge
                function onValueChanged() { wave.requestPaint() }
                function onSecondaryChanged() { wave.requestPaint() }
                function onFillColorChanged() { wave.requestPaint() }
                function onTrackColorChanged() { wave.requestPaint() }
                function onSecondaryColorChanged() { wave.requestPaint() }
            }
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width, h = height, lw = Math.max(2, h * 0.38), mid = h / 2
                var amp = Math.max(0, (h - lw) / 2), end = w * gauge.v, gap = lw * 1.5
                ctx.lineCap = "round"
                ctx.lineWidth = lw
                if (gauge.hasSecondary && gauge.s > 0) {   // the wash: a pale band behind
                    ctx.globalAlpha = gauge.secondaryOpacity
                    ctx.fillStyle = gauge.secondaryColor
                    ctx.fillRect(0, 0, w * gauge.s, h)
                    ctx.globalAlpha = 1
                }
                if (end + gap < w - lw / 2) {               // the track
                    ctx.strokeStyle = gauge.trackColor
                    ctx.beginPath()
                    ctx.moveTo(Math.max(lw / 2, end + gap), mid)
                    ctx.lineTo(w - lw / 2, mid)
                    ctx.stroke()
                }
                if (end > lw / 2) {                         // the wave
                    ctx.strokeStyle = gauge.fillColor
                    ctx.beginPath()
                    var period = Math.max(12, h * 2.6)
                    for (var x = lw / 2; x <= end; x += 1) {
                        var y = mid + amp * Math.sin(2 * Math.PI * x / period - wave.phase)
                        if (x === lw / 2) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                }
            }
        }
    }
}
