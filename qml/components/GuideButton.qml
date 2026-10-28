import QtQuick
import "."

// A bracketed command button, "[ START ]". On the film pages it is a flat
// slab with a hard shadow that it presses down onto; on the terminal an
// outline that floods with phosphor (or the `tone`) on hover.
Item {
    id: btn

    property string text: ""
    property color tone: Theme.ink           // Theme.alert for destructive commands
    property bool brackets: true
    property bool checked: false
    property int pixelSize: 12
    property string tooltip: ""
    signal clicked()

    readonly property bool hot: enabled && (area.containsMouse || checked)
    readonly property bool plain: Qt.colorEqual(tone, Theme.ink)
    implicitWidth: label.implicitWidth + 24
    implicitHeight: label.implicitHeight + 12
    opacity: enabled ? 1 : 0.35

    Rectangle {   // flat shadow (light)
        visible: Theme.flatShadow && !area.pressed
        x: 2; y: 2
        width: face.width; height: face.height
        radius: face.radius
        color: Theme.charcoal
    }
    Rectangle {
        id: face
        width: parent.width - 2; height: parent.height - 2
        x: area.pressed && Theme.flatShadow ? 2 : 0
        y: x
        radius: Theme.pillRadius
        // Opaque on the film pages, or the shadow would show through it.
        color: btn.hot ? btn.tone : Theme.dark ? "transparent"
             : btn.plain ? Theme.cream : Qt.tint(Theme.cream, Theme.withAlpha(btn.tone, 0.3))
        border.width: Theme.dark ? 1 : 2
        border.color: Theme.dark ? btn.tone : Theme.charcoal
        Behavior on color { ColorAnimation { duration: 90 } }
        Text {
            id: label
            anchors.centerIn: parent
            text: btn.brackets ? "[ " + btn.text + " ]" : btn.text
            color: btn.hot ? (Theme.dark ? Theme.bg : (btn.plain ? Theme.cream : Theme.charcoal)) : (Theme.dark ? btn.tone : Theme.charcoal)
            font { family: Theme.mono; pixelSize: btn.pixelSize; bold: true; letterSpacing: 0.8 }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: btn.clicked()
    }
}
