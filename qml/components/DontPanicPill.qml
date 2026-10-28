import QtQuick
import "."

// The Guide's cover legend as a pill: mustard with a charcoal outline and a
// flat shadow on the movie pages, an amber outline glowing on the terminal;
// under a skin, its badge (text, colours, pill shape).
Item {
    id: pill

    property string text: Theme.badgeText
    property int pixelSize: 13

    implicitWidth: label.implicitWidth + pixelSize * 1.8 + 2
    implicitHeight: label.implicitHeight + pixelSize * 0.8 + 2

    ThemeShapeContainer {
        visible: Theme.skinned
        anchors.fill: parent
        role: "pill"
        fillColor: Theme.badge
        strokeColor: Theme.badge
        cornerBrackets: false
        Text {
            anchors.centerIn: parent
            text: pill.text
            color: Theme.badgeInk
            font { family: Theme.sans; pixelSize: pill.pixelSize; weight: Font.Black; letterSpacing: 1 }
        }
    }
    Rectangle {   // flat shadow (light)
        visible: Theme.flatShadow && !Theme.skinned
        x: 2; y: 2
        width: parent.width - 2; height: parent.height - 2
        radius: height / 2
        color: Theme.charcoal
    }
    Rectangle {
        visible: !Theme.skinned
        width: parent.width - 2; height: parent.height - 2
        radius: height / 2
        color: Theme.dark ? Theme.withAlpha(Theme.amber, 0.08) : Theme.mustard
        border.width: 2
        border.color: Theme.dark ? Theme.amber : Theme.charcoal
        Text {
            id: label
            anchors.centerIn: parent
            text: pill.text
            color: Theme.dark ? Theme.amber : Theme.charcoal
            font { family: Theme.sans; pixelSize: pill.pixelSize; weight: Font.Black; letterSpacing: 1 }
        }
    }
}
