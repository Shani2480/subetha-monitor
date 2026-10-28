import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "."

// The left navigation rail: the planet and SUB-ETHA DIAGNOSTICS on top, one
// entry per tab with a bracketed pill that slides to the current one, and the
// uptime and theme switch at the bottom. Collapsed, it is a 48px strip of
// tab numbers (the Ctrl+N shortcuts), with names in tooltips.
Item {
    id: rail

    property var tabs: []                 // [{ key, label }]
    property int currentIndex: 0
    property bool collapsed: false
    property real uptime: 0
    signal selected(int index)
    signal toggleTheme()
    signal toggleCollapsed()

    readonly property int itemHeight: 38
    readonly property int itemSpacing: 6

    implicitWidth: collapsed ? 48 : 200
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutCubic } }
    clip: true

    Rectangle {   // the rail's own ground, a shade off the page
        anchors.fill: parent
        color: Theme.dark ? Theme.withAlpha(Theme.phosphor, 0.025) : Theme.withAlpha(Theme.paper, 0.85)
    }
    Rectangle {   // the rule between rail and page
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: Theme.dark ? 1 : 2
        color: Theme.tint(Theme.dark ? 0.35 : 1)
    }

    ColumnLayout {
        anchors { fill: parent; topMargin: 14; bottomMargin: 12; leftMargin: rail.collapsed ? 6 : 12; rightMargin: rail.collapsed ? 8 : 14 }
        spacing: 16

        // ---- identity ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Image {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Layout.alignment: rail.collapsed ? Qt.AlignHCenter : Qt.AlignLeft
                source: "../../assets/subetha-icon.svg"
                sourceSize: Qt.size(60, 60)
            }
            Text {
                visible: !rail.collapsed
                Layout.fillWidth: true
                text: "SUB-ETHA\nDIAGNOSTICS"
                color: Theme.ink
                lineHeight: 0.95
                font { family: Theme.mono; pixelSize: 12; bold: true; letterSpacing: 1.6 }
            }
        }

        // ---- entries ----
        Item {
            Layout.fillWidth: true
            implicitHeight: rail.tabs.length * (rail.itemHeight + rail.itemSpacing)

            Item {   // the sliding pill, with its flat offset shadow
                id: pill
                width: parent.width
                height: rail.itemHeight
                y: rail.currentIndex * (rail.itemHeight + rail.itemSpacing)
                Behavior on y { NumberAnimation { duration: Theme.animMs + 60; easing.type: Easing.OutCubic } }
                Rectangle {
                    x: 2; y: 2; width: parent.width - 2; height: parent.height - 2
                    radius: Theme.pillRadius
                    color: Theme.dark ? Theme.withAlpha(Theme.phosphor, 0.22) : Theme.charcoal
                }
                Rectangle {
                    width: parent.width - 2; height: parent.height - 2
                    radius: Theme.pillRadius
                    color: Theme.dark ? Theme.withAlpha(Theme.phosphor, 0.14) : Theme.coral
                    border { width: Theme.dark ? 1 : 2; color: Theme.dark ? Theme.phosphor : Theme.charcoal }
                }
            }

            Repeater {
                model: rail.tabs
                Item {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property bool current: rail.currentIndex === index
                    width: parent.width
                    height: rail.itemHeight
                    y: index * (rail.itemHeight + rail.itemSpacing)

                    Rectangle {
                        width: parent.width - 2; height: parent.height - 2
                        radius: Theme.pillRadius
                        visible: area.containsMouse && !entry.current
                        color: Theme.tint(0.07)
                    }
                    Text {
                        width: parent.width - 2; height: parent.height - 2
                        leftPadding: rail.collapsed ? 0 : 10
                        horizontalAlignment: rail.collapsed ? Text.AlignHCenter : Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: rail.collapsed ? String(entry.index + 1)
                            : entry.current ? "[ " + entry.modelData.label + " ]"
                            : "  " + entry.modelData.label
                        color: entry.current ? Theme.ink : Theme.tint(0.7)
                        font { family: Theme.mono; pixelSize: 12; bold: true; letterSpacing: 1.1 }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rail.selected(entry.index)
                        ToolTip.visible: rail.collapsed && containsMouse
                        ToolTip.delay: 400
                        ToolTip.text: entry.modelData.label + "  (Ctrl+" + (entry.index + 1) + ")"
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // ---- footer ----
        Text {
            Layout.fillWidth: true
            horizontalAlignment: rail.collapsed ? Text.AlignHCenter : Text.AlignLeft
            text: rail.collapsed ? "UP" : "UPTIME"
            color: Theme.tint(0.5)
            font { family: Theme.mono; pixelSize: 9; bold: true; letterSpacing: 1.4 }
        }
        Text {
            Layout.topMargin: -12
            Layout.fillWidth: true
            horizontalAlignment: rail.collapsed ? Text.AlignHCenter : Text.AlignLeft
            text: rail.collapsed ? Math.floor(rail.uptime / 86400) + "d" : Theme.duration(rail.uptime)
            color: Theme.ink
            elide: Text.ElideRight
            font { family: Theme.mono; pixelSize: rail.collapsed ? 11 : 15; bold: true }
        }
        GuideButton {
            Layout.fillWidth: true
            text: rail.collapsed ? (Theme.dark ? "◐" : "◑") : (Theme.dark ? "1981 ▸ 2005" : "2005 ▸ 1981")
            brackets: !rail.collapsed
            pixelSize: 11
            tone: Theme.dark ? Theme.amber : Theme.coral
            onClicked: rail.toggleTheme()
        }
        GuideButton {
            Layout.fillWidth: true
            text: rail.collapsed ? "»" : "« COLLAPSE"
            brackets: false
            pixelSize: 11
            onClicked: rail.toggleCollapsed()
        }
    }
}
