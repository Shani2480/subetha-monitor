import QtQuick
import QtQuick.Controls.Basic
import "."

// A slider as a segmented gauge: a hairline track that fills with ink up to
// a square (terminal) or round, shadowed (film) handle.
Slider {
    id: slider

    implicitWidth: 260
    implicitHeight: 26

    background: Item {
        x: slider.leftPadding
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth
        height: 6
        Rectangle {
            anchors.fill: parent
            radius: Theme.small(3)
            color: Theme.dark ? Theme.withAlpha(Theme.phosphor, 0.08) : Theme.cream
            border { width: Theme.line; color: Theme.dark ? Theme.tint(0.4) : Theme.charcoal }
        }
        Rectangle {
            width: slider.visualPosition * parent.width
            height: parent.height
            radius: Theme.small(3)
            color: Theme.dark ? Theme.phosphor : Theme.coral
            border { width: Theme.skinned ? 0 : Theme.dark ? 0 : 2; color: Theme.charcoal }
        }
    }
    handle: Item {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: 16; height: 16
        Rectangle {   // flat shadow (light)
            visible: Theme.flatShadow && !slider.pressed
            x: 2; y: 2; width: 14; height: 14; radius: 7
            color: Theme.charcoal
        }
        Rectangle {
            x: slider.pressed && Theme.flatShadow ? 2 : 0
            y: x
            width: 14; height: 14
            radius: Theme.skinned ? Theme.small(7) : Theme.dark ? 1 : 7
            color: Theme.dark ? (slider.pressed || slider.hovered ? Theme.amber : Theme.bg) : Theme.mustard
            border { width: Theme.skinned ? Theme.line : 2; color: Theme.skinned ? Theme.border : Theme.dark ? Theme.amber : Theme.charcoal }
        }
    }
}
