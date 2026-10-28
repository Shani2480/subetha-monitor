import QtQuick

// A skin's coordinate grid, drawn in its own ink: hairlines every `cell`
// pixels and a heavier rule every `major` cells. The Guide keeps its own
// phosphor / charcoal grid art; this is for skins with features.enableGrid.
Canvas {
    id: grid
    property color color: Theme.ink
    property int cell: 24
    property int major: 4
    property real minorAlpha: 0.05
    property real majorAlpha: 0.11

    renderStrategy: Canvas.Cooperative
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.lineWidth = 1
        for (var pass = 0; pass < 2; pass++) {
            ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, pass ? majorAlpha : minorAlpha)
            ctx.beginPath()
            for (var x = 0, i = 0; x <= width; x += cell, i++)
                if ((i % major === 0) === (pass === 1)) { ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, height) }
            for (var y = 0, j = 0; y <= height; y += cell, j++)
                if ((j % major === 0) === (pass === 1)) { ctx.moveTo(0, y + 0.5); ctx.lineTo(width, y + 0.5) }
            ctx.stroke()
        }
    }
}
