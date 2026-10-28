import QtQuick
import "."

// A bracketed command button, "[ START ]". On the film pages it is a flat
// slab with a hard shadow that it presses down onto; on the terminal an
// outline that floods with phosphor (or the `tone`) on hover; under a skin,
// its pill shape (chamfered, stadium, sharp) in its colours.
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

    ThemeShapeContainer {
        visible: Theme.skinned
        anchors.fill: parent
        anchors.margins: area.pressed && shadowType === "flat-2d" ? 1 : 0
        role: "pill"
        fillColor: btn.hot ? btn.tone : Theme.card
        strokeColor: btn.plain ? Theme.border : btn.tone
        cornerBrackets: false
        shadowType: area.pressed ? "none" : Theme.shadowType
    }
    Rectangle {   // flat shadow (light)
        visible: Theme.flatShadow && !area.pressed && !Theme.skinned
        x: 2; y: 2
        width: face.width; height: face.height
        radius: face.radius
        color: Theme.charcoal
    }
    Rectangle {
        id: face
        width: parent.width - 2; height: parent.height - 2
        x: area.pressed && Theme.flatShadow && !Theme.skinned ? 2 : 0
        y: x
        radius: Theme.pillRadius
        // Opaque on the film pages, or the shadow would show through it.
        color: Theme.skinned ? "transparent" : btn.hot ? btn.tone : Theme.dark ? "transparent"
             : btn.plain ? Theme.cream : Qt.tint(Theme.cream, Theme.withAlpha(btn.tone, 0.3))
        border.width: Theme.skinned ? 0 : Theme.dark ? 1 : 2
        border.color: Theme.dark ? btn.tone : Theme.charcoal
        Behavior on color { ColorAnimation { duration: 90 } }
        Text {
            id: label
            anchors.centerIn: parent
            text: btn.brackets ? "[ " + btn.text + " ]" : btn.text
            color: Theme.skinned ? (btn.hot ? Theme.bg : btn.plain ? Theme.ink : btn.tone)
                 : btn.hot ? (Theme.dark ? Theme.bg : (btn.plain ? Theme.cream : Theme.charcoal)) : (Theme.dark ? btn.tone : Theme.charcoal)
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
