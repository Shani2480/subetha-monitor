import QtQuick
import "."

// The look's screen effects over the whole window, each on only when the
// look asks for it (Theme.fx; a skin's `features`): the CRT's raster
// scanlines, the phosphor's rolling refresh glow (shaders/phosphor.frag),
// L brackets in the corners, and a glass sheen. The Guide's terminal has the
// first three; the film pages none. It takes no input.
Item {
    id: fxLayer

    property bool framed: true            // false when maximized: no corner brackets
    enabled: false

    Loader {
        anchors.fill: parent
        active: Theme.fx.crtScanlines
        sourceComponent: CrtOverlay {}
    }

    Loader {
        anchors.fill: parent
        active: Theme.fx.phosphorDecay
        sourceComponent: ShaderEffect {
            property real phase: 0
            property real strength: Theme.skinned ? 0.8 : 0.5
            property color tint: Theme.ink
            fragmentShader: "shaders/phosphor.frag.qsb"
            NumberAnimation on phase { from: 0; to: 1; duration: 2500; loops: Animation.Infinite }
        }
    }

    Loader {
        anchors.fill: parent
        active: Theme.fx.cornerBrackets && fxLayer.framed
        sourceComponent: Item {
            readonly property real size: Theme.skinned ? 14 : 12
            readonly property real thick: Theme.skinned ? Math.max(1.5, Theme.borderWidth) : 1.5
            Repeater {
                model: 4
                Item {
                    required property int index
                    readonly property bool atRight: index % 2 === 1
                    readonly property bool atBottom: index >= 2
                    width: parent.size; height: parent.size
                    x: atRight ? fxLayer.width - width - 5 : 5
                    y: atBottom ? fxLayer.height - height - 5 : 5
                    Rectangle { width: parent.width; height: parent.parent.thick; y: parent.atBottom ? parent.height - height : 0; color: Theme.bracketColor }
                    Rectangle { width: parent.parent.thick; height: parent.height; x: parent.atRight ? parent.width - width : 0; color: Theme.bracketColor }
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: Theme.fx.glassBlur
        sourceComponent: Item {
            Rectangle {   // frosted: a faint wash of the page colour, brighter at the top
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.05 : 0.10) }
                    GradientStop { position: 0.35; color: "transparent" }
                    GradientStop { position: 1; color: Theme.withAlpha(Theme.bg, 0.04) }
                }
            }
            Rectangle {   // the specular rim along the top edge
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18 }
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.35 : 0.8) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }
    }
}
