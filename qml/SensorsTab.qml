import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"

// Every hardware sensor the kernel exposes, in the manner of HWiNFO: a tree
// of devices and sections, each reading with its session minimum, maximum
// and average. Polling starts the first time the tab is shown and then runs
// for the rest of the session. Devices and sections fold by a click on
// their row, remembered in the settings; columns resize by their dividers.
// A search opens everything it matches. LOG CSV appends every sample to a
// file in the home folder.
ColumnLayout {
    id: tab

    property bool shown: false
    spacing: 12
    onShownChanged: hwinfo.active = shown
    Component.onDestruction: hwinfo.active = false

    readonly property var columnDefs: ({
        label: { label: "SENSOR",  width: 360, align: Text.AlignLeft },
        cur:   { label: "CURRENT", width: 130, align: Text.AlignRight },
        min:   { label: "MINIMUM", width: 120, align: Text.AlignRight },
        max:   { label: "MAXIMUM", width: 120, align: Text.AlignRight },
        avg:   { label: "AVERAGE", width: 120, align: Text.AlignRight }
    })
    readonly property var order: ["label", "cur", "min", "max", "avg"]
    readonly property int minColumn: 60
    readonly property int indent: 18

    // Widths by key; the sensor column also takes whatever room is left over.
    property var widths: ({})
    readonly property real valuesWidth: order.slice(1).reduce((s, k) => s + (widths[k] || 0), 0)
    function colWidth(key, avail) {
        return key === "label" ? Math.max(widths.label || 0, avail - valuesWidth) : widths[key] || columnDefs[key].width
    }

    Component.onCompleted: {
        var saved = settings.sensorColumnWidths || {}, w = {}
        for (var k in columnDefs)
            w[k] = saved[k] > 0 ? Math.max(minColumn, saved[k]) : columnDefs[k].width
        widths = w
    }
    function setWidth(key, w) {
        var copy = Object.assign({}, widths)
        copy[key] = Math.round(Math.max(minColumn, w))
        widths = copy
    }

    // ---- toolbar ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        GuideField {
            Layout.fillWidth: true
            Layout.minimumWidth: 140
            Layout.maximumWidth: 300
            placeholderText: "FILTER SENSORS..."
            onTextChanged: hwinfo.filterText = text
            Keys.onEscapePressed: text = ""
        }
        Text {
            text: "POLL"
            color: Theme.tint(0.6)
            font { family: Theme.mono; features: Theme.figures; pixelSize: 11; bold: true }
        }
        Repeater {
            model: hwinfo.intervals
            GuideCheck {
                required property int modelData
                text: modelData < 1000 ? modelData + " MS" : modelData / 1000 + " S"
                checked: hwinfo.interval === modelData
                onToggled: hwinfo.interval = modelData
            }
        }
        Item { Layout.fillWidth: true }
        GuideButton {
            text: hwinfo.anyCollapsed ? "EXPAND ALL" : "COLLAPSE ALL"
            onClicked: hwinfo.anyCollapsed ? hwinfo.expandAll() : hwinfo.collapseAll()
        }
        GuideButton { text: "RESET MIN/MAX"; onClicked: hwinfo.resetStatistics() }
        GuideButton {
            text: hwinfo.logging ? "● LOGGING" : "LOG CSV"
            checked: hwinfo.logging
            tone: hwinfo.logging ? Theme.alert : Theme.ink
            tooltip: hwinfo.logPath
            onClicked: hwinfo.logging = !hwinfo.logging
        }
    }

    GuideCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        padding: 12
        reticles: false
        spacing: 0

        // ---- header ----
        Row {
            id: header
            Layout.fillWidth: true
            Layout.rightMargin: 10
            height: 30
            Repeater {
                model: tab.order
                Item {
                    id: head
                    required property string modelData
                    readonly property var def: tab.columnDefs[modelData]
                    readonly property bool last: modelData === "avg"
                    width: tab.colWidth(modelData, header.width)
                    height: header.height

                    Text {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                  leftMargin: 8; rightMargin: 10 }
                        horizontalAlignment: head.def.align
                        text: head.def.label
                        elide: Text.ElideRight
                        color: Theme.tint(0.65)
                        font { family: Theme.mono; features: Theme.figures; pixelSize: 11; bold: true; letterSpacing: 1 }
                    }
                    Rectangle {   // divider
                        visible: !head.last
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: Theme.line
                        height: parent.height - 10
                        color: grip.containsMouse || grip.pressed ? Theme.accent : Theme.tint(0.2)
                    }
                    MouseArea {   // drag the divider to resize; double-click resets
                        id: grip
                        visible: !head.last
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
                        onReleased: settings.sensorColumnWidths = tab.widths
                        onDoubleClicked: { tab.setWidth(head.modelData, head.def.width); settings.sensorColumnWidths = tab.widths }
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: Theme.line; color: Theme.tint(Theme.dark ? 0.5 : 1) }

        // ---- rows ----
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: hwinfo.model
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true
            ScrollBar.vertical: GuideScrollBar {}

            delegate: Rectangle {
                id: row
                required property string kind
                required property string key
                required property int depth
                required property string label
                required property string cur
                required property string min
                required property string max
                required property string avg
                required property real frac
                required property bool expanded
                required property int count
                required property real heat
                required property int stripe
                readonly property bool sensor: kind === "sensor"
                readonly property bool device: kind === "device"
                readonly property real avail: list.width - 10

                width: avail
                height: device ? 34 : sensor ? 26 : 28
                color: rowArea.containsMouse && !sensor ? Theme.tint(0.08)
                     : device ? Theme.tint(Theme.dark ? 0.07 : 0.09)
                     : rowArea.containsMouse ? Theme.tint(0.06)
                     : sensor && stripe ? Theme.tint(Theme.dark ? 0.025 : 0.035) : "transparent"

                Rectangle {   // a rule above every device but the first
                    visible: row.device
                    width: parent.width; height: 1
                    color: Theme.tint(0.25)
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: row.sensor ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: if (!row.sensor) hwinfo.toggle(row.key)
                }

                Row {
                    anchors.fill: parent
                    // ---- sensor / section / device name ----
                    Item {
                        width: tab.colWidth("label", row.avail)
                        height: parent.height
                        Row {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                      leftMargin: 8 + row.depth * tab.indent; rightMargin: 8 }
                            spacing: 6
                            Text {
                                visible: !row.sensor
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10
                                text: row.expanded ? "▾" : "▸"
                                color: Theme.accent
                                font { family: Theme.mono; features: Theme.figures; pixelSize: 12; bold: true }
                            }
                            Rectangle {   // the device's hottest reading
                                visible: row.device && row.heat >= 0
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8; height: 8
                                radius: Theme.small(4)
                                color: Theme.heat(row.heat)
                            }
                            Text {
                                id: name
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, parent.width - 40 - (counter.visible ? counter.implicitWidth : 0))
                                text: row.label
                                elide: Text.ElideRight
                                color: row.device ? Theme.ink : row.sensor ? Theme.tint(0.85) : Theme.accent
                                font { family: Theme.mono; features: Theme.figures; pixelSize: row.device ? 13 : row.sensor ? 12 : 11
                                       bold: !row.sensor; letterSpacing: row.sensor ? 0 : 1
                                       capitalization: row.sensor ? Font.MixedCase : Font.AllUppercase }
                            }
                            Text {
                                id: counter
                                visible: !row.sensor
                                anchors.verticalCenter: parent.verticalCenter
                                text: "(" + row.count + ")"
                                color: Theme.tint(0.45)
                                font { family: Theme.mono; features: Theme.figures; pixelSize: 10 }
                            }
                        }
                    }
                    // ---- current, with where it sits between min and max ----
                    Item {
                        width: tab.colWidth("cur", row.avail)
                        height: parent.height
                        Text {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                      leftMargin: 8; rightMargin: 10 }
                            horizontalAlignment: Text.AlignRight
                            text: row.cur
                            elide: Text.ElideLeft
                            color: Theme.ink
                            font { family: Theme.mono; features: Theme.figures; pixelSize: 12; bold: true }
                        }
                        DynamicMetricGauge {   // a skin's: its own gauge shape
                            visible: Theme.skinned && row.sensor && row.frac >= 0
                            anchors { right: parent.right; rightMargin: 10; bottom: parent.bottom; bottomMargin: 1 }
                            width: parent.width - 18; height: 4
                            value: Math.max(0.02, row.frac)
                            fillColor: Theme.accent
                            segments: 16
                            live: false
                        }
                        Rectangle {
                            visible: !Theme.skinned && row.sensor && row.frac >= 0
                            anchors { right: parent.right; rightMargin: 10; bottom: parent.bottom; bottomMargin: 2 }
                            width: parent.width - 18; height: 2
                            color: Theme.tint(0.1)
                            Rectangle {
                                width: Math.max(2, parent.width * row.frac); height: parent.height
                                color: Theme.withAlpha(Theme.accent, 0.7)
                            }
                        }
                    }
                    Repeater {
                        model: [{ k: "min", v: row.min }, { k: "max", v: row.max }, { k: "avg", v: row.avg }]
                        Text {
                            required property var modelData
                            width: tab.colWidth(modelData.k, row.avail)
                            height: row.height
                            leftPadding: 8; rightPadding: 10
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: modelData.v
                            elide: Text.ElideLeft
                            color: Theme.tint(0.65)
                            font { family: Theme.mono; features: Theme.figures; pixelSize: 12 }
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
                text: hwinfo.samples === 0 ? "SCANNING /SYS/CLASS/HWMON FOR SENSORS..."
                    : hwinfo.filterText ? "NO SENSORS MATCH." : "THE KERNEL REPORTS NO SENSORS ON THIS MACHINE."
                color: Theme.tint(0.5)
                font { family: Theme.mono; features: Theme.figures; pixelSize: 13 }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: hwinfo.sensorCount + " SENSORS ON " + hwinfo.deviceCount + " DEVICES · "
            + hwinfo.samples + " SAMPLES OVER " + Theme.duration(hwinfo.sessionSeconds)
            + (hwinfo.logging ? " · LOGGING " + hwinfo.logRows + " ROWS TO " + hwinfo.logPath
                              : " · MIN / MAX / AVERAGE COVER THE WHOLE SESSION")
        color: hwinfo.logging ? Theme.accent : Theme.tint(0.5)
        elide: Text.ElideRight
        font { family: Theme.mono; features: Theme.figures; pixelSize: 10 }
    }
}
