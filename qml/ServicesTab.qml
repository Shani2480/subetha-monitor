import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"

// systemd service units of the system or the user's session, read over
// D-Bus every few seconds while the tab is on screen, each with START, STOP
// and RESTART. System units ask polkit for authorisation.
ColumnLayout {
    id: tab

    property bool shown: false
    spacing: 12
    onShownChanged: services.active = shown
    Component.onDestruction: services.active = false

    function stateColor(active) {
        return active === "active" ? Theme.high : active === "failed" ? Theme.alert
             : active === "activating" || active === "deactivating" || active === "reloading" ? Theme.mid
             : Theme.tint(0.5)
    }

    // ---- toolbar ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Repeater {
            model: [{ key: "system", label: "SYSTEM" }, { key: "user", label: "USER SESSION" }]
            GuideButton {
                required property var modelData
                text: modelData.label
                checked: services.scope === modelData.key
                onClicked: services.scope = modelData.key
            }
        }
        GuideField {
            Layout.preferredWidth: 240
            placeholderText: "search units and descriptions"
            onTextChanged: services.filterText = text
            Keys.onEscapePressed: text = ""
        }
        Repeater {
            model: [{ key: "all", label: "ALL" }, { key: "active", label: "ACTIVE" },
                    { key: "inactive", label: "INACTIVE" }, { key: "failed", label: "FAILED" }]
            GuideCheck {
                required property var modelData
                text: modelData.label
                checked: services.stateFilter === modelData.key
                onToggled: services.stateFilter = modelData.key
            }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            text: services.counts.active + " ACTIVE · " + services.counts.failed + " FAILED · " + services.counts.total + " UNITS"
            color: services.counts.failed > 0 ? Theme.alert : Theme.tint(0.6)
            font { family: Theme.mono; pixelSize: 11; bold: true }
        }
        GuideButton { text: services.loading ? "READING..." : "REFRESH"; onClicked: services.refresh() }
    }

    GuideCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        padding: 12
        reticles: false
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: 10
            spacing: 0
            Repeater {
                model: [{ label: "UNIT", w: 300 }, { label: "LOAD", w: 90 }, { label: "ACTIVE", w: 170 },
                        { label: "DESCRIPTION", w: -1 }, { label: "CONTROLS", w: 290 }]
                Text {
                    required property var modelData
                    Layout.preferredWidth: modelData.w > 0 ? modelData.w : 100
                    Layout.fillWidth: modelData.w < 0
                    leftPadding: 8
                    topPadding: 7; bottomPadding: 7
                    text: modelData.label
                    color: Theme.tint(0.65)
                    font { family: Theme.mono; pixelSize: 11; bold: true; letterSpacing: 1 }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: Theme.dark ? 1 : 2; color: Theme.tint(Theme.dark ? 0.5 : 1) }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: services.model
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: GuideScrollBar {}

            delegate: Rectangle {
                id: row
                required property int index
                required property string name
                required property string description
                required property string load
                required property string active
                required property string sub
                required property string pending
                readonly property bool running: active === "active" || active === "activating" || active === "reloading"

                width: list.width - 10
                height: 34
                color: rowArea.containsMouse ? Theme.tint(0.06) : index % 2 ? Theme.tint(Theme.dark ? 0.025 : 0.035) : "transparent"
                MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    Text {
                        Layout.preferredWidth: 300
                        leftPadding: 8; rightPadding: 8
                        text: row.name
                        elide: Text.ElideMiddle
                        color: Theme.ink
                        font { family: Theme.mono; pixelSize: 12; bold: true }
                    }
                    Text {
                        Layout.preferredWidth: 90
                        leftPadding: 8
                        text: row.load
                        color: row.load === "loaded" ? Theme.tint(0.7) : Theme.mid
                        font { family: Theme.mono; pixelSize: 11 }
                    }
                    RowLayout {
                        Layout.fillWidth: false
                        Layout.preferredWidth: 162
                        Layout.leftMargin: 8
                        spacing: 6
                        Rectangle { width: 8; height: 8; radius: Theme.dark ? 0 : 4; color: tab.stateColor(row.active) }
                        Text {
                            Layout.fillWidth: true
                            text: row.pending ? row.pending.toUpperCase() + "ING..." : row.active + " (" + row.sub + ")"
                            color: row.pending ? Theme.accent : tab.stateColor(row.active)
                            elide: Text.ElideRight
                            font { family: Theme.mono; pixelSize: 11; bold: true }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 100
                        leftPadding: 8; rightPadding: 8
                        text: row.description
                        elide: Text.ElideRight
                        color: Theme.tint(0.75)
                        font { family: Theme.mono; pixelSize: 11 }
                    }
                    Row {
                        Layout.preferredWidth: 290
                        spacing: 6
                        GuideButton {
                            text: "START"; pixelSize: 10
                            enabled: !row.running && !row.pending
                            tone: Theme.high
                            onClicked: services.control(row.name, "start")
                        }
                        GuideButton {
                            text: "STOP"; pixelSize: 10
                            enabled: row.running && !row.pending
                            tone: Theme.alert
                            onClicked: services.control(row.name, "stop")
                        }
                        GuideButton {
                            text: "RESTART"; pixelSize: 10
                            enabled: !row.pending
                            tone: Theme.dark ? Theme.amber : Theme.mustard
                            onClicked: services.control(row.name, "restart")
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                visible: list.count === 0
                text: services.error ? "THE BUS IS NOT ANSWERING: " + services.error
                    : services.loading ? "QUERYING ORG.FREEDESKTOP.SYSTEMD1..." : "NO UNITS MATCH."
                color: services.error ? Theme.alert : Theme.tint(0.5)
                font { family: Theme.mono; pixelSize: 13 }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: services.scope === "system"
            ? "SYSTEM UNITS: CONTROLS ASK POLKIT FOR AUTHORISATION. STOPPING THE WRONG ONE MAY DEMOLISH YOUR SESSION TO MAKE WAY FOR A HYPERSPACE BYPASS."
            : "USER UNITS RUN IN YOUR OWN SESSION (systemctl --user) AND NEED NO PASSWORD."
        color: Theme.tint(0.5)
        elide: Text.ElideRight
        font { family: Theme.mono; pixelSize: 10 }
    }
}
