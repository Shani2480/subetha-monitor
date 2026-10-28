import QtQuick
import QtQuick.Controls.Basic
import "."

// A dashed rule between groups of a GuideMenu.
MenuSeparator {
    topPadding: 4
    bottomPadding: 4
    contentItem: Row {
        spacing: 3
        clip: true
        Repeater {
            model: 60
            Rectangle { width: 4; height: 1; color: Theme.tint(0.4) }
        }
    }
}
