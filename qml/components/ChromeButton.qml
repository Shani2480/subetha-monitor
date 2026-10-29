import QtQuick
import QtQuick.Shapes
import "."

// One window control (minimize, maximize, restore, close) as the operating
// system a skin imitates draws it (Theme.chromeStyle):
//   ""          the Guide's: a flat glyph on the bar, flooding on hover
//   "luna"      XP: a square bevelled blue tile, the close one red, white glyphs
//   "aero"      Vista: glassy tiles joined in a strip, a wider red close
//   "aqua"      macOS: red / yellow / green jelly lights, glyphs on hover
//   "material"  a round icon button with a tonal hover
//   "terminal"  [_] [▫] [X] in the mono font
//   "kiroshi"   slanted outlined tabs; close floods red
//   "hud"       flat glyphs in the accent (≡ menu, –, ✕), a tint on hover
//   "scrap"     lopsided junk-plate buttons: – in teal, ✕ in hot pink
//   "candy"     round sweets: green to minimize and maximize, red to close
// `groupHot` is set by the bar for the macOS lights, which show their
// glyphs together while the pointer is over any of them.
Item {
    id: wb

    property string kind                       // minimize, maximize, restore, close, menu
    property string style: Theme.chromeStyle
    property bool groupHot: false
    property real barHeight: 38
    signal clicked()

    readonly property bool danger: kind === "close"
    readonly property bool hot: area.containsMouse
    readonly property bool down: area.pressed

    implicitWidth: ({ luna: 23, aero: danger ? 44 : 27, aqua: 20, material: 36, terminal: 30, kiroshi: 34, hud: 30,
                      scrap: danger ? 34 : 28, candy: 22 })[style] || 46
    implicitHeight: ({ luna: 23, aero: 20, aqua: 20, material: 32, terminal: barHeight, kiroshi: 22, hud: 26,
                       scrap: danger ? 26 : 22, candy: 22 })[style] || barHeight

    // ---- the glyphs, shared by the drawn styles ----
    component Glyph: Item {
        id: glyph
        property color ink: "white"
        property real stroke: 1.5
        property real size: 10
        width: size; height: size
        Rectangle {   // minimize: an underscore
            visible: wb.kind === "minimize"
            width: glyph.size; height: glyph.stroke + (wb.style === "luna" ? 1 : 0)
            y: glyph.size - height
            color: glyph.ink
        }
        Rectangle {   // maximize: a box, its top rule heavier on Luna
            visible: wb.kind === "maximize"
            anchors.fill: parent
            color: "transparent"
            border { width: glyph.stroke; color: glyph.ink }
            Rectangle { visible: wb.style === "luna" || wb.style === "aero"; width: parent.width; height: glyph.stroke * 2; color: glyph.ink }
        }
        Item {        // restore: two overlapping boxes
            visible: wb.kind === "restore"
            anchors.fill: parent
            Rectangle { x: parent.width * 0.3; width: parent.width * 0.7; height: parent.height * 0.7; color: "transparent"; border { width: glyph.stroke; color: glyph.ink } }
            Rectangle { y: parent.height * 0.3; width: parent.width * 0.7; height: parent.height * 0.7; color: "transparent"; border { width: glyph.stroke; color: glyph.ink } }
        }
        Repeater {    // close: a cross
            model: wb.kind === "close" ? [45, -45] : []
            Rectangle {
                required property int modelData
                width: glyph.size * 1.3; height: glyph.stroke
                anchors.centerIn: parent
                rotation: modelData
                antialiasing: true
                color: glyph.ink
            }
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: ({ luna: luna, aero: aero, aqua: aqua, material: material, terminal: terminal, kiroshi: kiroshi,
                            hud: hud, scrap: scrap, candy: candy })[wb.style] || guide
    }

    // ---- the Guide's own ----
    Component {
        id: guide
        Item {
            readonly property color glyphInk: wb.hot && wb.danger ? "#FFFFFF" : wb.hot ? Theme.ink : Theme.tint(0.75)
            Rectangle {
                anchors.fill: parent
                visible: wb.hot
                // Close floods red; the others glow faintly.
                color: wb.danger ? (Theme.skinned ? Theme.red : Theme.dark ? "#FF3333" : "#FF4A4A")
                     : Theme.dark ? Theme.withAlpha(Theme.phosphor, wb.down ? 0.28 : 0.16)
                     : Theme.withAlpha(Theme.mustard, wb.down ? 0.75 : 0.5)
            }
            Glyph { anchors.centerIn: parent; ink: parent.glyphInk; size: wb.kind === "close" ? 10 : 10 }
        }
    }

    // ---- Windows XP Luna ----
    Component {
        id: luna
        Rectangle {
            radius: 3
            border { width: 1; color: "#FFFFFF" }
            readonly property color face: wb.danger ? Theme.cc("closeFace", "#E0552F") : Theme.cc("buttonFace", "#2C68E8")
            gradient: Gradient {
                GradientStop { position: 0; color: wb.down ? Qt.darker(face, 1.25) : Qt.lighter(face, wb.hot ? 1.55 : 1.4) }
                GradientStop { position: 0.55; color: wb.down ? Qt.darker(face, 1.1) : wb.hot ? Qt.lighter(face, 1.15) : face }
                GradientStop { position: 1; color: Qt.darker(face, wb.down ? 1.05 : 1.2) }
            }
            Glyph {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: wb.down ? 1 : 0
                anchors.verticalCenterOffset: wb.down ? 1 : 0
                ink: wb.danger ? Theme.cc("closeGlyph", "#FFFFFF") : Theme.cc("buttonGlyph", "#FFFFFF")
                stroke: wb.danger ? 2.2 : 1.6
                size: wb.danger ? 9 : 9
            }
        }
    }

    // ---- Windows Vista Aero ----
    Component {
        id: aero
        Item {
            id: aeroFace
            readonly property color face: wb.danger ? Theme.cc("closeFace", "#C8442E") : Theme.cc("buttonFace", Qt.rgba(1, 1, 1, 0.18))
            Rectangle {
                anchors.fill: parent
                radius: 3
                border { width: 1; color: Qt.rgba(0, 0, 0, 0.45) }
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(aeroFace.face, wb.hot ? 1.6 : 1.35) }
                    GradientStop { position: 0.48; color: Qt.lighter(aeroFace.face, wb.hot ? 1.25 : 1.05) }
                    GradientStop { position: 0.52; color: wb.down ? Qt.darker(aeroFace.face, 1.3) : Qt.darker(aeroFace.face, 1.1) }
                    GradientStop { position: 1; color: wb.hot && !wb.danger ? Qt.rgba(0.35, 0.8, 1, 0.55) : aeroFace.face }
                }
                Rectangle {   // the inner white rim
                    anchors { fill: parent; margins: 1 }
                    radius: 2
                    color: "transparent"
                    border { width: 1; color: Qt.rgba(1, 1, 1, 0.45) }
                }
            }
            Glyph {
                anchors.centerIn: parent
                ink: Theme.cc(wb.danger ? "closeGlyph" : "buttonGlyph", "#FFFFFF")
                stroke: 1.6
                size: 8
            }
        }
    }

    // ---- macOS: the traffic lights ----
    Component {
        id: aqua
        Item {
            readonly property color light: wb.danger ? "#FF5F57" : wb.kind === "minimize" ? "#FEBC2E" : "#28C840"
            Rectangle {
                anchors.centerIn: parent
                width: 12; height: 12; radius: 6
                color: wb.down ? Qt.darker(parent.light, 1.2) : parent.light
                border { width: 0.5; color: Qt.darker(parent.light, 1.35) }
                Rectangle {   // the jelly's highlight
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 1 }
                    width: 7; height: 4; radius: 2
                    color: Qt.rgba(1, 1, 1, 0.35)
                }
                Text {
                    anchors.centerIn: parent
                    visible: wb.groupHot
                    text: wb.danger ? "×" : wb.kind === "minimize" ? "–" : "+"
                    color: Qt.rgba(0, 0, 0, 0.55)
                    font { pixelSize: 11; bold: true }
                }
            }
        }
    }

    // ---- Material: round icon buttons ----
    Component {
        id: material
        Item {
            Rectangle {
                anchors.centerIn: parent
                width: 32; height: 32; radius: 16
                color: wb.danger && wb.hot ? Theme.withAlpha(Theme.red, 0.85)
                     : Theme.withAlpha(Theme.ink, wb.down ? 0.16 : wb.hot ? 0.09 : 0)
            }
            Glyph {
                anchors.centerIn: parent
                ink: wb.danger && wb.hot ? "#FFFFFF" : Theme.cc("buttonGlyph", Theme.ink)
                stroke: 1.6
                size: 10
            }
        }
    }

    // ---- terminal: bracketed text ----
    Component {
        id: terminal
        Rectangle {
            color: wb.hot ? (wb.danger ? Theme.red : Theme.ink) : "transparent"
            Text {
                anchors.centerIn: parent
                text: wb.danger ? "[X]" : wb.kind === "minimize" ? "[_]" : wb.kind === "maximize" ? "[▫]" : "[=]"
                color: wb.hot ? Theme.bg : Theme.cc("buttonGlyph", Theme.ink)
                font { family: Theme.mono; pixelSize: 13; bold: true }
            }
        }
    }

    // ---- Kiroshi: slanted tabs ----
    Component {
        id: kiroshi
        Item {
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1.5
                    strokeColor: wb.danger ? Theme.red : Theme.cc("buttonFace", Theme.accent)
                    fillColor: wb.hot ? (wb.danger ? Theme.red : Theme.withAlpha(Theme.cc("buttonFace", Theme.accent), 0.3)) : "transparent"
                    startX: 6; startY: 0
                    PathLine { x: wb.width; y: 0 }
                    PathLine { x: wb.width - 6; y: wb.height }
                    PathLine { x: 0; y: wb.height }
                    PathLine { x: 6; y: 0 }
                }
            }
            Glyph {
                anchors.centerIn: parent
                ink: wb.hot && wb.danger ? "#FFFFFF" : Theme.cc("buttonGlyph", Theme.ink)
                stroke: 1.5
                size: 9
            }
        }
    }

    // ---- HUD: flat glyphs in the accent ----
    Component {
        id: hud
        Rectangle {
            radius: 3
            color: wb.hot ? Theme.withAlpha(wb.danger ? Theme.red : Theme.accent, wb.down ? 0.35 : 0.2) : "transparent"
            Text {
                anchors.centerIn: parent
                text: wb.kind === "menu" ? "≡" : wb.danger ? "✕" : wb.kind === "minimize" ? "–" : wb.kind === "maximize" ? "□" : "❐"
                color: Theme.cc("buttonGlyph", Theme.accent)
                font { family: Theme.sans; pixelSize: wb.kind === "menu" ? 17 : 14; bold: true }
            }
        }
    }

    // ---- scrap: lopsided junk plates ----
    Component {
        id: scrap
        Item {
            readonly property color plate: wb.danger ? Theme.cc("closeFace", "#FF3EA5") : Theme.cc("buttonFace", "#2EC4B6")
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 4
                rotation: wb.danger ? 3 : -2
                antialiasing: true
                color: wb.down ? Qt.darker(parent.plate, 1.25) : wb.hot ? Qt.lighter(parent.plate, 1.15) : parent.plate
                border { width: 2.5; color: Theme.border }
                Rectangle { width: 4; height: 4; radius: 2; x: 3; y: 3; color: Theme.border }   // a bolt
            }
            Text {
                anchors.centerIn: parent
                text: wb.danger ? "✕" : wb.kind === "minimize" ? "–" : "□"
                color: "#FFFFFF"
                style: Text.Outline; styleColor: Theme.border
                font { family: Theme.sans; pixelSize: 14; weight: Font.Black }
            }
        }
    }

    // ---- candy: round sweets ----
    Component {
        id: candy
        Rectangle {
            readonly property color sweet: wb.danger ? "#FF4D5E" : "#4CCB5A"
            anchors.centerIn: parent
            width: 18; height: 18; radius: 9
            color: wb.down ? Qt.darker(sweet, 1.2) : wb.hot ? Qt.lighter(sweet, 1.12) : sweet
            border { width: 2.5; color: Theme.border }
            Rectangle { x: 4; y: 3; width: 6; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.6) }
            Text {
                anchors.centerIn: parent
                visible: wb.hot
                text: wb.danger ? "✕" : wb.kind === "minimize" ? "–" : "+"
                color: "#FFFFFF"
                font { pixelSize: 10; bold: true }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: wb.clicked()
    }
}
