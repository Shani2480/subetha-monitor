import QtQuick
import "."

// The tube itself, over the whole window: raster scanlines every 2px at 0.08
// and a faint vignette on the terminal; nothing on the film pages. It takes
// no input.
Item {
    id: overlay

    visible: Theme.dark
    enabled: false

    Image {
        anchors.fill: parent
        source: "scanlines.svg"
        sourceSize: Qt.size(4, 2)
        fillMode: Image.Tile
        smooth: false
        opacity: 0.08
    }
    Rectangle {   // a tube's darker edges
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.22) }
            GradientStop { position: 0.06; color: "transparent" }
            GradientStop { position: 0.94; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.22) }
        }
    }
}
