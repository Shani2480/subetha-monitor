import QtQuick
import QtQuick.Controls.Basic
import "."

// A context menu on the Guide's page: a card with a hard shadow (film) or a
// phosphor-ruled panel (terminal). Fill it with Actions, MenuSeparators and
// nested GuideMenus. An Action with `property bool danger: true` reads in
// the alert colour; one with `property bool marked` shows a radio bullet,
// filled while it is true.
Menu {
    id: menu

    // Menu does not size itself to its delegates' text; wide enough for ours.
    width: 260
    padding: 4
    overlap: 4

    delegate: MenuItem {
        id: item
        readonly property bool danger: !!(action && action.danger)
        readonly property bool radio: !!action && action.marked !== undefined
        readonly property color fore: !enabled ? Theme.tint(0.35)
            : highlighted ? (Theme.dark ? Theme.bg : Theme.charcoal)
            : danger ? Theme.alert : Theme.ink

        implicitWidth: Math.max(220, label.implicitWidth + 64)
        implicitHeight: 28
        leftPadding: 26
        rightPadding: 24

        contentItem: Text {
            id: label
            text: item.text
            color: item.fore
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font { family: Theme.mono; features: Theme.figures; pixelSize: 12; bold: true; letterSpacing: 0.6 }
        }
        indicator: Text {
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            visible: item.radio
            text: item.action && item.action.marked ? "●" : "○"
            color: item.fore
            font { family: Theme.mono; features: Theme.figures; pixelSize: 10 }
        }
        arrow: Text {
            x: item.width - width - 9
            anchors.verticalCenter: parent.verticalCenter
            visible: item.subMenu !== null
            text: "▸"
            color: item.fore
            font { family: Theme.mono; features: Theme.figures; pixelSize: 12; bold: true }
        }
        background: Rectangle {
            radius: Theme.pillRadius
            color: !item.highlighted ? "transparent"
                 : item.danger ? Theme.alert
                 : Theme.dark ? Theme.phosphor : Theme.mustard
        }
    }

    background: Item {
        Rectangle {   // flat shadow (light)
            visible: Theme.flatShadow
            x: 3; y: 3; width: parent.width - 1; height: parent.height - 1
            radius: face.radius
            color: Theme.charcoal
        }
        Rectangle {
            id: face
            width: parent.width - 1; height: parent.height - 1
            radius: Theme.skinned ? Theme.pillRadius : Theme.dark ? 3 : 10
            color: Theme.dark ? Theme.crtCard : Theme.cream
            border { width: Theme.line; color: Theme.skinned ? Theme.border : Theme.ink }
        }
    }

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 90 } }
}
