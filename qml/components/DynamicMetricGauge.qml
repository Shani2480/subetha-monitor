import QtQuick
import QtQuick.Shapes
import "."

// One gauge in the active look's own shape (the skin's geometry.gaugeShape):
//   "segmented"  LED blocks; on a CRT skin (features.enableCrtScanlines) ASCII cells
//   "flat"       a square bar, no radius
//   "stadium"    a capsule with a specular highlight over its fill
//   "chamfer"    a bar with its ends cut at 45°
//   "wavy"       a sine wave up to the value, then the flat track
// A skin's controls.meter, when set, draws in its operating system's idiom
// instead, whatever the shape:
//   "bevel"   Luna: a recessed 3D well, the fill a glass gradient with a white
//             specular band (green glossy blocks when the shape is segmented)
//   "ascii"   a terminal's [||||||||....] 44%
//   "gadget"  the Vista Sidebar's rounded segments, green shading to orange
//   "angled"  slanted parallelogram blocks
//   "slime"   a glass tube filling with ooze, its meniscus wobbling, a drop
//             now and then falling from under it
// controls.meterLabel puts the percentage at the right end.
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
    property string meter: Theme.skinned ? Theme.meterStyle : ""
    property bool showLabel: Theme.skinned && !!Theme.controls.meterLabel && meter !== "ascii"

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

    Text {   // the percentage at the right end (controls.meterLabel)
        id: label
        visible: gauge.showLabel
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: Math.round(gauge.v * 100) + "%"
        color: Theme.ink
        font { family: Theme.mono; features: Theme.figures; pixelSize: Math.max(10, Math.min(12, gauge.height + 2)) }
    }

    Loader {
        anchors { fill: parent; rightMargin: gauge.showLabel ? label.implicitWidth + 6 : 0 }
        sourceComponent: gauge.meter === "bevel" ? bevelBar
                       : gauge.meter === "ascii" ? bracketBar
                       : gauge.meter === "gadget" ? gadgetBar
                       : gauge.meter === "angled" ? angledBar
                       : gauge.meter === "slime" ? slimeBar
                       : gauge.ascii ? asciiBar
                       : ({ flat: flatBar, stadium: stadiumBar, chamfer: chamferBar, wavy: wavyBar, "analog-dial": flatBar })[gauge.shape] || blocks
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

    // ---- bevel: Luna's recessed well with a glass fill ----
    // The well: dark 1px top and left, white bottom and right. The fill is
    // the skin's meter gradient while the reading is nominal, else the
    // level's colour shaded the same way.
    readonly property bool nominal: Qt.colorEqual(fillColor, Theme.gaugeUsage) || Qt.colorEqual(fillColor, Theme.high)
    readonly property color glassTop: nominal ? Theme.ctl("meterFillTop", Qt.lighter(fillColor, 1.45)) : Qt.lighter(fillColor, 1.45)
    readonly property color glassBottom: nominal ? Theme.ctl("meterFillBottom", fillColor) : fillColor
    component Glass: Rectangle {
        property color lit: gauge.glassTop
        property color deep: gauge.glassBottom
        gradient: Gradient {
            GradientStop { position: 0; color: lit }
            GradientStop { position: 0.5; color: deep }
            GradientStop { position: 1; color: Qt.lighter(lit, 1.05) }
        }
        Rectangle {   // the specular band across the middle
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: -parent.height * 0.12 }
            height: Math.max(1, parent.height * 0.28)
            color: Theme.ctl("meterSheen", Qt.rgba(1, 1, 1, 0.45))
        }
    }
    Component {
        id: bevelBar
        Item {
            id: well
            Rectangle { anchors.fill: parent; color: Theme.ctl("meterTrack", gauge.trackColor) }
            Rectangle { width: parent.width; height: 1; color: Theme.ctl("meterInsetDark", "#7F9DB9") }
            Rectangle { width: 1; height: parent.height; color: Theme.ctl("meterInsetDark", "#7F9DB9") }
            Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: Theme.ctl("meterInsetLight", "#FFFFFF") }
            Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: Theme.ctl("meterInsetLight", "#FFFFFF") }
            Item {
                id: inside
                anchors { fill: parent; margins: 2 }
                clip: true
                Rectangle {   // the secondary wash
                    visible: gauge.hasSecondary
                    width: parent.width * gauge.s; height: parent.height
                    color: gauge.secondaryColor
                    opacity: gauge.secondaryOpacity
                }
                Glass {   // continuous glass
                    visible: Theme.gaugeShape !== "segmented"
                    width: parent.width * gauge.v; height: parent.height
                }
                Row {     // XP's green blocks, glossy
                    visible: Theme.gaugeShape === "segmented"
                    spacing: 2
                    readonly property real block: Math.max(4, Math.round(inside.height * 0.75))
                    readonly property int count: Math.floor((inside.width + spacing) / (block + spacing))
                    Repeater {
                        model: Math.round(parent.count * gauge.v)
                        Glass { width: parent.block; height: inside.height }
                    }
                }
            }
        }
    }

    // ---- ascii: [|||||.....] 44% ----
    Component {
        id: bracketBar
        Text {
            id: brackets
            readonly property int pixel: Math.max(10, Math.min(14, gauge.height + 4))
            readonly property string pct: (" " + Math.round(gauge.v * 100)).slice(-3) + "%"
            readonly property int cells: Math.max(4, Math.floor(width / Math.max(1, metrics.advanceWidth)) - 2 - pct.length - 1)
            readonly property int lit: Math.round(gauge.v * cells)
            TextMetrics { id: metrics; font: brackets.font; text: "|" }
            verticalAlignment: Text.AlignVCenter
            color: gauge.fillColor
            textFormat: Text.PlainText
            text: "[" + "|".repeat(lit) + ".".repeat(cells - lit) + "] " + pct
            font { family: Theme.mono; features: Theme.figures; pixelSize: pixel }
        }
    }

    // ---- gadget: the Sidebar's rounded segments, green to orange ----
    Component {
        id: gadgetBar
        Row {
            id: pods
            spacing: 2
            readonly property int count: Math.max(6, Math.min(20, Math.round(gauge.width / 14)))
            readonly property int lit: Math.round(gauge.v * count)
            Repeater {
                model: pods.count
                Rectangle {
                    required property int index
                    readonly property real at: index / Math.max(1, pods.count - 1)
                    readonly property color hue: Qt.rgba(0.30 + 0.70 * at, 0.77 - 0.22 * at, 0.09, 1)   // #4CC417 → #FF8C17
                    readonly property bool on: index < pods.lit
                    width: (gauge.width - pods.spacing * (pods.count - 1)) / pods.count
                    height: gauge.height
                    radius: height / 2
                    color: on ? hue : gauge.trackColor
                    border { width: 1; color: on ? Qt.darker(hue, 1.3) : Qt.darker(gauge.trackColor, 1.15) }
                    Rectangle {   // the glassy top
                        visible: parent.on
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
                        height: parent.height / 2
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.4)
                    }
                }
            }
        }
    }

    // ---- angled: slanted blocks ----
    Component {
        id: angledBar
        Row {
            id: slants
            spacing: 3
            readonly property int count: Math.max(8, Math.min(32, Math.round(gauge.width / 9)))
            readonly property int lit: Math.round(gauge.v * count)
            readonly property int washed: Math.round(gauge.s * count)
            Repeater {
                model: slants.count
                Rectangle {
                    required property int index
                    width: (gauge.width - slants.spacing * (slants.count - 1)) / slants.count
                    height: gauge.height
                    antialiasing: true
                    color: index < slants.lit ? gauge.fillColor
                         : gauge.hasSecondary && index < slants.washed ? Qt.tint(gauge.trackColor, Theme.withAlpha(gauge.secondaryColor, gauge.secondaryOpacity))
                         : gauge.trackColor
                    // a shear: the top leans right
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.6, 0, height * 0.6, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                }
            }
        }
    }

    // ---- slime: a glass tube filling with ooze ----
    Component {
        id: slimeBar
        Item {
            id: tube
            property real phase: 0
            NumberAnimation on phase {
                from: 0; to: 2 * Math.PI; duration: 1600
                loops: Animation.Infinite
                running: gauge.live && tube.visible
            }
            Rectangle {   // the glass
                id: glassTube
                anchors.fill: parent
                radius: height / 2
                color: Theme.withAlpha(gauge.trackColor, 0.55)
                border { width: Theme.cartoon ? 2 : 1; color: Theme.border }
                clip: true
                Canvas {   // the ooze, its end a wobbling meniscus
                    id: ooze
                    anchors { fill: parent; margins: glassTube.border.width }
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var w = width * gauge.v, h = height
                        if (w <= 0) return
                        var wob = Math.min(4, h * 0.35)
                        ctx.fillStyle = gauge.fillColor
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        for (var y = 0; y <= h; y += 1)
                            ctx.lineTo(Math.max(0, w + wob * Math.sin(tube.phase + y / h * Math.PI * 1.4)), y)
                        ctx.lineTo(0, h)
                        ctx.closePath()
                        ctx.fill()
                        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.25)   // bubbles
                        for (var b = 0; b < 3; b++) {
                            var bx = (w * (0.2 + 0.3 * b) + tube.phase * 6 * (b + 1)) % Math.max(1, w)
                            ctx.beginPath(); ctx.arc(bx, h * (0.3 + 0.2 * b), Math.max(1, h * 0.12), 0, 2 * Math.PI); ctx.fill()
                        }
                    }
                    Connections {
                        target: tube
                        function onPhaseChanged() { ooze.requestPaint() }
                    }
                }
                Rectangle {   // the specular stripe along the glass
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: parent.height * 0.18; leftMargin: parent.radius; rightMargin: parent.radius }
                    height: Math.max(1, parent.height * 0.16)
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.55)
                }
            }
            Rectangle {   // a drop, now and then, from under the ooze's end
                id: drop
                width: Math.max(3, tube.height * 0.35); height: width * 1.25; radius: width / 2
                x: tube.width * gauge.v - width
                color: gauge.fillColor
                visible: gauge.v > 0.05 && opacity > 0
                opacity: 0
                SequentialAnimation {
                    running: gauge.live && tube.visible && gauge.v > 0.05
                    loops: Animation.Infinite
                    PauseAnimation { duration: 2600 }
                    PropertyAction { target: drop; property: "y"; value: tube.height - drop.height / 2 }
                    PropertyAction { target: drop; property: "opacity"; value: 1 }
                    ParallelAnimation {
                        NumberAnimation { target: drop; property: "y"; to: tube.height + 10; duration: 520; easing.type: Easing.InQuad }
                        NumberAnimation { target: drop; property: "opacity"; to: 0; duration: 520; easing.type: Easing.InQuad }
                    }
                }
            }
        }
    }
}
