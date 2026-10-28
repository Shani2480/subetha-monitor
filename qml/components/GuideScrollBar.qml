import QtQuick
import QtQuick.Controls.Basic
import "."

// A thin themed scroll bar: a phosphor rail on the terminal, a charcoal
// slab on the film pages.
ScrollBar {
    id: bar
    policy: ScrollBar.AsNeeded
    minimumSize: 0.06
    contentItem: Rectangle {
        implicitWidth: 6
        implicitHeight: 6
        radius: Theme.dark ? 0 : 3
        color: bar.pressed ? Theme.accent : Theme.tint(bar.hovered ? 0.6 : 0.35)
        opacity: bar.active || bar.hovered ? 1 : 0.5
    }
    background: Item {}
}
