import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Shapes
import "components"

// Every process, searchable and sortable, sampled only while this tab is on
// screen. Columns resize by their dividers and reorder by dragging their
// headings, both remembered in the settings. Selection follows the PID, not
// the row, so it stays on the same process as the table re-sorts. A right
// click opens the process menu: signals, priority, copy, properties.
// TERMINATE and KILL ask first.
ColumnLayout {
    id: tab

    property bool shown: false
    property int selectedPid: -1
    property string selectedName: ""
    property var menuRow: ({})             // the row the context menu was opened on

    spacing: 12
    onShownChanged: processes.active = shown
    Component.onDestruction: processes.active = false

    readonly property var columnDefs: ({
        pid:     { label: "PID",            width: 80,  align: Text.AlignRight },
        name:    { label: "NAME / COMMAND", width: 240, align: Text.AlignLeft },
        user:    { label: "USER",           width: 100, align: Text.AlignLeft },
        cpu:     { label: "CPU %",          width: 90,  align: Text.AlignRight },
        memMb:   { label: "MEMORY",         width: 110, align: Text.AlignRight },
        read:    { label: "DISK READ",      width: 100, align: Text.AlignRight },
        write:   { label: "DISK WRITE",     width: 100, align: Text.AlignRight },
        threads: { label: "THREADS",        width: 70,  align: Text.AlignRight },
        nice:    { label: "NICE",           width: 70,  align: Text.AlignRight }
    })
    readonly property var defaultOrder: ["pid", "name", "user", "cpu", "memMb", "read", "write", "threads", "nice"]
    readonly property int minColumn: 44
    readonly property var priorities: [
        { nice: -20, label: "Very High (-20)" }, { nice: -10, label: "High (-10)" },
        { nice: 0, label: "Normal (0)" }, { nice: 10, label: "Low (10)" }, { nice: 19, label: "Very Low (19)" }
    ]
    readonly property var quickFilters: [
        { key: "all", label: "ALL" }, { key: "mine", label: "MY PROCESSES (" + processes.currentUser.toUpperCase() + ")" },
        { key: "system", label: "SYSTEM / ROOT" }, { key: "heavy", label: "HEAVY LOAD (>" + processes.heavyCpu + "% CPU)" }
    ]

    // The layout in use: widths by key, and the keys in display order. The
    // header and rows repeat over `order` and read `widths`, so a resize
    // drag updates cells in place instead of rebuilding them.
    property var widths: ({})
    property var order: []
    readonly property real tableWidth: order.reduce((s, k) => s + (widths[k] || 0), 0)

    Component.onCompleted: {
        var saved = settings.columnWidths || {}, w = {}
        for (var k in columnDefs)
            w[k] = saved[k] > 0 ? Math.max(minColumn, saved[k]) : columnDefs[k].width
        widths = w
        var o = []
        for (var key of (settings.columnOrder || []))
            if (key in columnDefs && o.indexOf(key) < 0) o.push(key)
        for (var d of defaultOrder)
            if (o.indexOf(d) < 0) o.push(d)
        order = o
        for (var p of priorities)
            priorityMenu.addAction(priorityAction.createObject(priorityMenu, { text: p.label, nice: p.nice }))
    }
    function setWidth(key, w) {
        var copy = Object.assign({}, widths)
        copy[key] = Math.round(Math.max(minColumn, w))
        widths = copy
    }
    function moveColumn(key, to) {
        var o = order.filter(k => k !== key)
        o.splice(Math.max(0, Math.min(o.length, to)), 0, key)
        order = o
        settings.columnOrder = o
    }
    function resetColumns() {
        var w = {}
        for (var k in columnDefs) w[k] = columnDefs[k].width
        widths = w
        order = defaultOrder.slice()
        settings.columnWidths = {}
        settings.columnOrder = []
    }

    function memText(mb, pct) {
        return (mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : mb.toFixed(mb >= 100 ? 0 : 1) + " MB") + " " + pct.toFixed(1) + "%"
    }
    function ioText(v) { return v < 0 ? "--" : v < 1 ? "0" : Theme.rate(v) }

    function select(pid, name) {
        selectedPid = pid
        selectedName = name
    }
    function signalSelected(which) {
        if (selectedPid < 0) return
        confirm.which = which
        confirm.ask(which === "KILL" ? "KILL PROCESS (SIGKILL)" : "END PROCESS (SIGTERM)",
                    (which === "KILL"
                        ? "Vaporise <b>" + selectedName + "</b> (PID " + selectedPid + ") at once? It gets no chance to save anything, much like the Earth."
                        : "Ask <b>" + selectedName + "</b> (PID " + selectedPid + ") to shut down politely? It may save its work first."),
                    which === "KILL" ? "KILL" : "END")
    }

    // ---- toolbar ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        GuideField {
            id: search
            Layout.fillWidth: true
            Layout.minimumWidth: 140
            Layout.maximumWidth: 320
            placeholderText: "FILTER PROCESSES..."
            onTextChanged: processes.filterText = text
            Keys.onEscapePressed: text = ""
        }
        Repeater {
            model: tab.quickFilters
            GuideButton {
                required property var modelData
                text: modelData.label
                pixelSize: 10
                checked: processes.quickFilter === modelData.key
                tone: modelData.key === "heavy" ? Theme.accent : Theme.ink
                onClicked: processes.quickFilter = modelData.key
            }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            text: processes.model.count + " / " + processes.total + " PROCESSES"
            color: Theme.tint(0.6)
            font { family: Theme.mono; features: Theme.figures; pixelSize: 11; bold: true }
        }
    }

    GuideCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        padding: 12
        reticles: false
        spacing: 0

        Item {
            id: table
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Wider than the card when the columns add up to more: a
            // horizontal scroll bar appears, the vertical one stays put.
            Flickable {
                id: hflick
                anchors { fill: parent; rightMargin: 10; bottomMargin: tab.tableWidth > width ? 10 : 0 }
                contentWidth: Math.max(width, tab.tableWidth)
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: GuideScrollBar {
                    parent: table
                    policy: tab.tableWidth > hflick.width ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; rightMargin: 10 }
                }

                Column {
                    width: hflick.contentWidth
                    height: hflick.height

                    // ---- header ----
                    Row {
                        id: header
                        height: 30
                        Repeater {
                            model: tab.order
                            Item {
                                id: head
                                required property string modelData
                                required property int index
                                readonly property var def: tab.columnDefs[modelData]
                                readonly property bool sorted: processes.sortKey === modelData
                                property real dragOffset: 0
                                property bool dragging: false
                                width: tab.widths[modelData] || def.width
                                height: header.height
                                z: dragging ? 2 : 0
                                transform: Translate { x: head.dragOffset }

                                Rectangle {   // lifted while being dragged
                                    anchors.fill: parent
                                    visible: head.dragging
                                    radius: Theme.pillRadius
                                    color: Theme.card
                                    border { width: Theme.line; color: Theme.accent }
                                }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: head.def.align === Text.AlignRight ? head.width - width - 10 : 8
                                    width: Math.min(implicitWidth, head.width - 18)
                                    spacing: 5
                                    clip: true
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: head.def.label
                                        color: head.sorted ? Theme.accent : headArea.containsMouse ? Theme.ink : Theme.tint(0.65)
                                        font { family: Theme.mono; features: Theme.figures; pixelSize: 11; bold: true; letterSpacing: 1 }
                                    }
                                    Shape {   // sort direction
                                        id: arrow
                                        readonly property bool down: processes.sortDescending
                                        visible: head.sorted
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 8; height: 5
                                        preferredRendererType: Shape.CurveRenderer
                                        ShapePath {
                                            strokeColor: "transparent"
                                            fillColor: Theme.accent
                                            startX: 0; startY: arrow.down ? 0 : 5
                                            PathLine { x: 8; y: arrow.down ? 0 : 5 }
                                            PathLine { x: 4; y: arrow.down ? 5 : 0 }
                                            PathLine { x: 0; y: arrow.down ? 0 : 5 }
                                        }
                                    }
                                }
                                MouseArea {   // click sorts, drag reorders
                                    id: headArea
                                    anchors { fill: parent; rightMargin: 5 }
                                    hoverEnabled: true
                                    cursorShape: head.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    property real pressX
                                    property bool wasDrag: false
                                    onPressed: mouse => { pressX = mapToItem(header, mouse.x, 0).x; wasDrag = false }
                                    onPositionChanged: mouse => {
                                        if (!pressed) return
                                        var dx = mapToItem(header, mouse.x, 0).x - pressX
                                        if (!head.dragging && Math.abs(dx) > 8) head.dragging = true
                                        if (head.dragging) head.dragOffset = dx
                                    }
                                    onReleased: {
                                        wasDrag = head.dragging
                                        if (!head.dragging) return
                                        // Drop before the first column whose middle is right of ours.
                                        var centre = head.x + head.width / 2 + head.dragOffset, to = 0, x = 0
                                        for (var k of tab.order) {
                                            var w = tab.widths[k]
                                            if (k !== head.modelData && x + w / 2 < centre) to++
                                            x += w
                                        }
                                        head.dragging = false
                                        head.dragOffset = 0
                                        tab.moveColumn(head.modelData, to)
                                    }
                                    onClicked: if (!wasDrag) processes.sortBy(head.modelData)
                                }
                                Rectangle {   // divider
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    width: Theme.line
                                    height: parent.height - 10
                                    color: grip.containsMouse || grip.pressed ? Theme.accent : Theme.tint(0.2)
                                }
                                MouseArea {   // drag the divider to resize; double-click resets
                                    id: grip
                                    anchors { right: parent.right; rightMargin: -4; top: parent.top; bottom: parent.bottom }
                                    width: 9
                                    hoverEnabled: true
                                    cursorShape: Qt.SplitHCursor
                                    property real pressX
                                    property real startWidth
                                    onPressed: mouse => { pressX = mapToItem(header, mouse.x, 0).x; startWidth = head.width }
                                    onPositionChanged: mouse => {
                                        if (pressed) tab.setWidth(head.modelData, startWidth + mapToItem(header, mouse.x, 0).x - pressX)
                                    }
                                    onReleased: settings.columnWidths = tab.widths
                                    onDoubleClicked: { tab.setWidth(head.modelData, head.def.width); settings.columnWidths = tab.widths }
                                }
                            }
                        }
                    }
                    Rectangle { width: parent.width; height: Theme.line; color: Theme.tint(Theme.dark ? 0.5 : 1) }

                    // ---- rows ----
                    ListView {
                        id: list
                        width: parent.width
                        height: parent.height - header.height - 2
                        clip: true
                        model: processes.model
                        boundsBehavior: Flickable.StopAtBounds
                        reuseItems: true
                        ScrollBar.vertical: GuideScrollBar {
                            parent: table
                            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 32 }
                        }

                        delegate: Rectangle {
                            id: row
                            required property int index
                            required property int pid
                            required property string name
                            required property string user
                            required property real cpu
                            required property real memMb
                            required property real memPct
                            required property real read
                            required property real write
                            required property int threads
                            required property int nice
                            required property string cmd
                            readonly property bool selected: tab.selectedPid === pid

                            width: list.width
                            height: 26
                            color: selected ? (Theme.dark ? Theme.withAlpha(Theme.amber, 0.18) : Theme.withAlpha(Theme.coral, 0.25))
                                 : rowArea.containsMouse ? Theme.tint(0.06)
                                 : index % 2 ? Theme.tint(Theme.dark ? 0.025 : 0.035) : "transparent"
                            border.width: selected ? 1 : 0
                            border.color: Theme.accent

                            Row {
                                anchors { top: parent.top; bottom: parent.bottom }
                                Repeater {
                                    model: tab.order
                                    Item {
                                        id: cell
                                        required property string modelData
                                        readonly property var def: tab.columnDefs[modelData]
                                        width: tab.widths[modelData] || def.width
                                        height: row.height
                                        clip: true

                                        Text {   // every column but the name
                                            visible: cell.modelData !== "name"
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 10 }
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: cell.def.align
                                            elide: Text.ElideRight
                                            color: cell.modelData === "cpu" ? Theme.load(row.cpu * 4)
                                                 : cell.modelData === "user" && row.user !== processes.currentUser ? Theme.tint(0.55)
                                                 : cell.modelData === "nice" && row.nice < 0 ? Theme.accent
                                                 : cell.modelData === "nice" && row.nice > 0 ? Theme.tint(0.55)
                                                 : cell.modelData === "write" && row.write >= 1 ? Theme.cool
                                                 : Theme.ink
                                            font { family: Theme.mono; features: Theme.figures; pixelSize: 12 }
                                            text: {
                                                switch (cell.modelData) {
                                                case "pid": return row.pid
                                                case "user": return row.user
                                                case "cpu": return row.cpu.toFixed(1)
                                                case "memMb": return tab.memText(row.memMb, row.memPct)
                                                case "read": return tab.ioText(row.read)
                                                case "write": return tab.ioText(row.write)
                                                case "threads": return row.threads
                                                case "nice": return (row.nice > 0 ? "+" : "") + row.nice
                                                }
                                                return ""
                                            }
                                        }
                                        Row {   // the name, then its command line, dimmed
                                            visible: cell.modelData === "name"
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 10 }
                                            spacing: 8
                                            Text {
                                                id: nameText
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Math.min(implicitWidth, parent.width)
                                                text: row.name
                                                elide: Text.ElideRight
                                                color: Theme.ink
                                                font { family: Theme.mono; features: Theme.figures; pixelSize: 12; bold: true }
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Math.max(0, parent.width - nameText.width - 8)
                                                text: row.cmd
                                                elide: Text.ElideRight
                                                color: Theme.tint(0.45)
                                                font { family: Theme.mono; features: Theme.figures; pixelSize: 11 }
                                            }
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        tab.select(row.pid, row.name)
                                        tab.menuRow = { pid: row.pid, name: row.name, cmd: row.cmd, nice: row.nice }
                                        processMenu.popup()
                                    } else if (row.selected) {
                                        tab.selectedPid = -1
                                    } else {
                                        tab.select(row.pid, row.name)
                                    }
                                }
                                onDoubleClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        tab.select(row.pid, row.name)
                                        properties.show(row.pid)
                                    }
                                }
                                ToolTip.visible: containsMouse && row.cmd !== "" && pressedButtons === 0 && !processMenu.visible
                                ToolTip.delay: 900
                                ToolTip.text: row.cmd
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: processes.total === 0 ? "SCANNING THE PROCESS TABLE..." : Theme.lex("noMatch", "NO PROCESSES MATCH. THEY MAY HAVE GONE FOR A TOWEL.", "NO PROCESSES MATCH.")
                color: Theme.tint(0.5)
                font { family: Theme.mono; features: Theme.figures; pixelSize: 13 }
            }
        }
    }

    // ---- selection info / hints ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Text {
            Layout.fillWidth: true
            text: tab.selectedPid > 0 ? "SELECTED: " + tab.selectedName + " (PID " + tab.selectedPid + ")  ·  RIGHT-CLICK FOR ACTIONS, DOUBLE-CLICK FOR PROPERTIES, DELETE TO KILL"
                                      : "CLICK A HEADING TO SORT (AGAIN TO FLIP), DRAG IT TO REORDER, DRAG ITS EDGE TO RESIZE. RIGHT-CLICK A PROCESS FOR ACTIONS."
            color: Theme.tint(0.5)
            elide: Text.ElideRight
            font { family: Theme.mono; features: Theme.figures; pixelSize: 10 }
        }
        GuideButton { text: "RESET COLUMNS"; pixelSize: 10; onClicked: tab.resetColumns() }
    }

    Shortcut { sequence: "Ctrl+F"; enabled: tab.shown; onActivated: search.forceActiveFocus() }
    Shortcut { sequence: "Delete"; enabled: tab.shown && tab.selectedPid > 0; onActivated: tab.signalSelected("KILL") }
    Shortcut { sequence: "Alt+Return"; enabled: tab.shown && tab.selectedPid > 0; onActivated: properties.show(tab.selectedPid) }

    GuideMenu {
        id: processMenu
        Action { text: "Kill Process (SIGKILL)"; property bool danger: true; onTriggered: tab.signalSelected("KILL") }
        Action { text: "End Process (SIGTERM)"; onTriggered: tab.signalSelected("TERM") }
        GuideMenuSeparator {}
        GuideMenu {
            id: priorityMenu
            title: "Set Priority (Nice)"
            // Filled from `priorities` in Component.onCompleted.
        }
        GuideMenuSeparator {}
        Action { text: "Copy PID"; onTriggered: telemetry.copyText(String(tab.menuRow.pid)) }
        Action { text: "Copy Command Line"; enabled: !!tab.menuRow.cmd; onTriggered: telemetry.copyText(tab.menuRow.cmd) }
        GuideMenuSeparator {}
        Action { text: "Show Process Properties"; onTriggered: properties.show(tab.menuRow.pid) }
    }
    Component {
        id: priorityAction
        Action {
            property int nice
            property bool marked: tab.menuRow.nice === nice
            onTriggered: processes.setNice(tab.menuRow.pid, nice)
        }
    }

    ConfirmDialog {
        id: confirm
        property string which: "TERM"
        parent: Overlay.overlay
        tone: which === "KILL" ? Theme.alert : Theme.accent
        onAccepted: processes.sendSignal(tab.selectedPid, which)
    }

    ProcessProperties {
        id: properties
        parent: Overlay.overlay
    }
}
