import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"

// Every process, searchable and sortable, sampled only while this tab is on
// screen. Selection follows the PID, not the row, so it stays on the same
// process as the table re-sorts. TERMINATE and KILL ask first.
ColumnLayout {
    id: tab

    property bool shown: false
    property int selectedPid: -1
    property string selectedName: ""

    spacing: 12
    onShownChanged: processes.active = shown
    Component.onDestruction: processes.active = false

    readonly property var columns: [
        { key: "pid",   label: "PID",          width: 80,  align: Text.AlignRight },
        { key: "name",  label: "PROCESS",      width: -1,  align: Text.AlignLeft },
        { key: "user",  label: "USER",         width: 120, align: Text.AlignLeft },
        { key: "cpu",   label: "CPU %",        width: 90,  align: Text.AlignRight },
        { key: "memMb", label: "MEMORY",       width: 150, align: Text.AlignRight },
        { key: "io",    label: "DISK I/O",     width: 110, align: Text.AlignRight }
    ]

    function signalSelected(which) {
        if (selectedPid < 0) return
        confirm.which = which
        confirm.ask(which === "KILL" ? "KILL PROCESS (SIGKILL)" : "TERMINATE PROCESS (SIGTERM)",
                    (which === "KILL"
                        ? "Vaporise <b>" + selectedName + "</b> (PID " + selectedPid + ") at once? It gets no chance to save anything, much like the Earth."
                        : "Ask <b>" + selectedName + "</b> (PID " + selectedPid + ") to shut down politely? It may save its work first."),
                    which === "KILL" ? "KILL" : "TERMINATE")
    }

    // ---- toolbar ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        GuideField {
            id: search
            Layout.preferredWidth: 320
            placeholderText: "search name, PID, user, command"
            onTextChanged: processes.filterText = text
            Keys.onEscapePressed: text = ""
        }
        GuideCheck {
            text: "USER ONLY (" + processes.currentUser + ")"
            checked: processes.userOnly
            onToggled: c => processes.userOnly = c
        }
        Item { Layout.fillWidth: true }
        Text {
            text: processes.model.count + " / " + processes.total + " PROCESSES"
            color: Theme.tint(0.6)
            font { family: Theme.mono; pixelSize: 11; bold: true }
        }
        GuideButton {
            text: "TERMINATE (SIGTERM)"
            enabled: tab.selectedPid > 0
            tone: Theme.dark ? Theme.amber : Theme.mustard
            onClicked: tab.signalSelected("TERM")
        }
        GuideButton {
            text: "KILL (SIGKILL)"
            enabled: tab.selectedPid > 0
            tone: Theme.alert
            onClicked: tab.signalSelected("KILL")
        }
    }

    GuideCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        padding: 12
        reticles: false
        spacing: 0

        // ---- header ----
        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: 10
            spacing: 0
            Repeater {
                model: tab.columns
                Item {
                    id: head
                    required property var modelData
                    readonly property bool sorted: processes.sortKey === modelData.key
                    Layout.preferredWidth: modelData.width > 0 ? modelData.width : 100
                    Layout.fillWidth: modelData.width < 0
                    implicitHeight: 30
                    Text {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: head.modelData.align
                        text: head.modelData.label + (head.sorted ? (processes.sortDescending ? " ▼" : " ▲") : "")
                        color: head.sorted ? Theme.accent : headArea.containsMouse ? Theme.ink : Theme.tint(0.65)
                        font { family: Theme.mono; pixelSize: 11; bold: true; letterSpacing: 1 }
                    }
                    MouseArea {
                        id: headArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: processes.sortBy(head.modelData.key)
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: Theme.dark ? 1 : 2; color: Theme.tint(Theme.dark ? 0.5 : 1) }

        // ---- rows ----
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: processes.model
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true
            ScrollBar.vertical: GuideScrollBar {}

            delegate: Rectangle {
                id: row
                required property int index
                required property int pid
                required property string name
                required property string user
                required property real cpu
                required property real memMb
                required property real memPct
                required property real io
                required property string cmd
                readonly property bool selected: tab.selectedPid === pid

                width: list.width - 10
                height: 26
                color: selected ? (Theme.dark ? Theme.withAlpha(Theme.amber, 0.18) : Theme.withAlpha(Theme.coral, 0.25))
                     : rowArea.containsMouse ? Theme.tint(0.06)
                     : index % 2 ? Theme.tint(Theme.dark ? 0.025 : 0.035) : "transparent"
                border.width: selected ? 1 : 0
                border.color: Theme.accent

                RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    Repeater {
                        model: tab.columns
                        Text {
                            required property var modelData
                            Layout.preferredWidth: modelData.width > 0 ? modelData.width : 100
                            Layout.fillWidth: modelData.width < 0
                            leftPadding: 8; rightPadding: 8
                            horizontalAlignment: modelData.align
                            elide: Text.ElideRight
                            color: modelData.key === "cpu" ? Theme.load(row.cpu * 4)
                                 : modelData.key === "user" && row.user !== processes.currentUser ? Theme.tint(0.55)
                                 : Theme.ink
                            font { family: Theme.mono; pixelSize: 12; bold: modelData.key === "name" }
                            text: {
                                switch (modelData.key) {
                                case "pid": return row.pid
                                case "name": return row.name
                                case "user": return row.user
                                case "cpu": return row.cpu.toFixed(1)
                                case "memMb": return (row.memMb >= 1024 ? (row.memMb / 1024).toFixed(2) + " GB" : row.memMb.toFixed(1) + " MB")
                                                     + "  " + row.memPct.toFixed(1) + "%"
                                case "io": return row.io < 0 ? "--" : row.io < 1 ? "0" : Theme.rate(row.io)
                                }
                                return ""
                            }
                        }
                    }
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        tab.selectedPid = row.selected ? -1 : row.pid
                        tab.selectedName = row.name
                    }
                    onDoubleClicked: { tab.selectedPid = row.pid; tab.selectedName = row.name; tab.signalSelected("TERM") }
                    ToolTip.visible: containsMouse && row.cmd !== "" && pressedButtons === 0
                    ToolTip.delay: 900
                    ToolTip.text: row.cmd
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: processes.total === 0 ? "SCANNING THE PROCESS TABLE..." : "NO PROCESSES MATCH. THEY MAY HAVE GONE FOR A TOWEL."
                color: Theme.tint(0.5)
                font { family: Theme.mono; pixelSize: 13 }
            }
        }
    }

    // Selection info / hints
    Text {
        Layout.fillWidth: true
        text: tab.selectedPid > 0 ? "SELECTED: " + tab.selectedName + " (PID " + tab.selectedPid + ")  ·  DOUBLE-CLICK A ROW TO TERMINATE, DELETE KEY TO KILL"
                                  : "CLICK A ROW TO SELECT IT. CLICK CPU % OR MEMORY TO SORT; CLICK AGAIN TO FLIP."
        color: Theme.tint(0.5)
        elide: Text.ElideRight
        font { family: Theme.mono; pixelSize: 10 }
    }

    Shortcut { sequence: "Ctrl+F"; enabled: tab.shown; onActivated: search.forceActiveFocus() }
    Shortcut { sequence: "Delete"; enabled: tab.shown && tab.selectedPid > 0; onActivated: tab.signalSelected("KILL") }

    ConfirmDialog {
        id: confirm
        property string which: "TERM"
        parent: Overlay.overlay
        tone: which === "KILL" ? Theme.alert : (Theme.dark ? Theme.amber : Theme.coral)
        onAccepted: processes.sendSignal(tab.selectedPid, which)
    }
}
