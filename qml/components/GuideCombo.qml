import QtQuick
import QtQuick.Controls.Basic
import "."

// A drop-down in the same bracketed slab as GuideButton, opening a
// GuideMenu-styled list. Takes a model of { value, label } and `textRole:
// "label"`, `valueRole: "value"`.
ComboBox {
    id: combo

    implicitWidth: 240
    implicitHeight: 32
    font { family: Theme.mono; features: Theme.figures; pixelSize: 12; bold: true }

    contentItem: Text {
        leftPadding: 12
        rightPadding: 28
        text: combo.displayText
        color: Theme.ink
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font: combo.font
    }
    indicator: Text {
        x: combo.width - width - 12
        anchors.verticalCenter: parent.verticalCenter
        text: combo.popup.visible ? "▴" : "▾"
        color: Theme.accent
        font { family: Theme.mono; features: Theme.figures; pixelSize: 13; bold: true }
    }
    background: Item {
        ThemeShapeContainer {   // a skin's pill shape
            visible: Theme.skinned
            anchors.fill: parent
            role: "pill"
            fillColor: combo.hovered ? Theme.cardHover : Theme.card
            strokeColor: combo.visualFocus || combo.popup.visible ? Theme.accent : Theme.border
            cornerBrackets: false
        }
        Rectangle {   // flat shadow (light)
            visible: Theme.flatShadow && !Theme.skinned
            x: 2; y: 2; width: parent.width - 2; height: parent.height - 2
            radius: Theme.pillRadius
            color: Theme.charcoal
        }
        Rectangle {
            visible: !Theme.skinned
            width: parent.width - 2; height: parent.height - 2
            radius: Theme.pillRadius
            color: Theme.dark ? (combo.hovered ? Theme.tint(0.08) : "transparent") : Theme.cream
            border { width: Theme.line; color: combo.visualFocus || combo.popup.visible ? Theme.accent : Theme.dark ? Theme.tint(0.5) : Theme.charcoal }
        }
    }
    delegate: ItemDelegate {
        id: entry
        required property var model
        required property int index
        width: ListView.view.width
        height: 28
        highlighted: combo.highlightedIndex === index
        contentItem: Text {
            text: entry.model[combo.textRole]
            color: entry.highlighted ? (Theme.dark || Theme.skinned ? Theme.bg : Theme.charcoal) : Theme.ink
            verticalAlignment: Text.AlignVCenter
            font: combo.font
        }
        background: Rectangle {
            radius: Theme.pillRadius
            color: entry.highlighted ? (Theme.skinned ? Theme.accent : Theme.dark ? Theme.phosphor : Theme.mustard) : "transparent"
        }
    }
    popup: Popup {
        y: combo.height + 2
        width: combo.width
        padding: 4
        implicitHeight: contentItem.implicitHeight + 8
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: combo.popup.visible ? combo.delegateModel : null
            currentIndex: combo.highlightedIndex
        }
        background: Rectangle {
            radius: Theme.skinned ? Theme.pillRadius : Theme.dark ? 3 : 10
            color: Theme.skinned ? Theme.card : Theme.dark ? Theme.crtCard : Theme.cream
            border { width: Theme.skinned ? Math.max(1, Theme.borderWidth) : Theme.line
                     color: Theme.skinned ? Theme.border : Theme.dark ? Theme.phosphor : Theme.charcoal }
        }
    }
}
