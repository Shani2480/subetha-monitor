import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"

// The monitor's window: the Guide's masthead (title, host profile, a rotating
// entry from the Guide, DON'T PANIC and the theme switch), a tab strip, the
// five tabs, a status line, and the CRT tube laid over all of it in the dark
// theme. Context properties from main.py: settings, telemetry, processes,
// services.
ApplicationWindow {
    id: win

    readonly property var tabs: [
        { key: "overview",  label: "OVERVIEW",  source: "OverviewTab.qml" },
        { key: "processes", label: "PROCESSES", source: "ProcessesTab.qml" },
        { key: "services",  label: "SYSTEMD UNITS", source: "ServicesTab.qml" },
        { key: "network",   label: "NETWORK",   source: "NetworkTab.qml" },
        { key: "disks",     label: "STORAGE",   source: "DisksTab.qml" }
    ]
    property int currentTab: 0
    readonly property var t: telemetry.data
    readonly property var specs: telemetry.specs
    property string status: ""
    property bool statusOk: true

    function showTab(key) {
        var i = tabs.findIndex(t => t.key === key)
        if (i >= 0) currentTab = i
    }
    function report(message, ok) {
        status = message
        statusOk = ok
        statusTimer.restart()
    }

    width: 1280
    height: 860
    minimumWidth: 900
    minimumHeight: 620
    visible: true
    title: "Sub-Etha System Monitor"
    color: Theme.bg
    font.family: Theme.sans

    Component.onCompleted: {
        Theme.dark = Qt.binding(() => settings.theme !== "light")
        width = Math.max(minimumWidth, settings.width)
        height = Math.max(minimumHeight, settings.height)
        showTab(settings.tab)
    }
    onCurrentTabChanged: settings.tab = tabs[currentTab].key
    onClosing: settings.saveSize(width, height)

    Connections {
        target: settings
        function onTabRequested(key) {
            if (key) win.showTab(key)
            if (win.visibility === Window.Minimized) win.showNormal()
            win.raise()
            win.requestActivate()
        }
    }
    Connections { target: processes; function onActionResult(m, ok) { win.report(m, ok) } }
    Connections { target: services; function onActionResult(m, ok) { win.report(m, ok) } }
    Connections { target: telemetry; function onCopied(text) { win.report("COPIED " + text + " TO THE CLIPBOARD", true) } }

    Shortcut { sequence: "Ctrl+1"; onActivated: win.currentTab = 0 }
    Shortcut { sequence: "Ctrl+2"; onActivated: win.currentTab = 1 }
    Shortcut { sequence: "Ctrl+3"; onActivated: win.currentTab = 2 }
    Shortcut { sequence: "Ctrl+4"; onActivated: win.currentTab = 3 }
    Shortcut { sequence: "Ctrl+5"; onActivated: win.currentTab = 4 }
    Shortcut { sequence: "Ctrl+T"; onActivated: themeSwitch.clicked() }
    Shortcut { sequence: StandardKey.Quit; onActivated: win.close() }

    // Coordinate grid under everything: 24px phosphor squares on the terminal,
    // charcoal hairlines on the cream page.
    Image {
        anchors.fill: parent
        source: Theme.dark ? "components/grid-dark.svg" : "components/grid-light.svg"
        sourceSize: Qt.size(24, 24)
        fillMode: Image.Tile
        smooth: false
        opacity: Theme.dark ? 0.05 : 0.06
    }

    ColumnLayout {
        anchors { fill: parent; margins: 18 }
        spacing: 14

        // ---- masthead ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            DynamicFanBlade {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                rpm: (win.t.fans || []).reduce((m, f) => Math.max(m, f.rpm), 0)
                strokeColor: Theme.ink
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "THE SUB-ETHA SYSTEM MONITOR"
                    color: Theme.ink
                    font { family: Theme.sans; pixelSize: 24; weight: Font.Black; letterSpacing: Theme.dark ? 3 : 1.5 }
                }
                Text {
                    Layout.fillWidth: true
                    text: [win.specs.host, win.specs.os, "LINUX " + win.specs.kernel,
                           "UP " + Theme.duration(win.t.uptime || 0)].join("  ·  ").toUpperCase()
                    color: Theme.tint(0.65)
                    elide: Text.ElideRight
                    font { family: Theme.mono; pixelSize: 11; letterSpacing: 0.6 }
                }
                Text {
                    id: quip
                    Layout.fillWidth: true
                    color: Theme.accent
                    elide: Text.ElideRight
                    font { family: Theme.mono; pixelSize: 11; italic: !Theme.dark }
                    readonly property var lines: [
                        "Space is big. Your process table is merely large.",
                        "The answer is 42. The question is your load average.",
                        "Time is an illusion. Uptime doubly so.",
                        "Mostly harmless, apart from that one browser tab.",
                        "So long, and thanks for all the cycles.",
                        "Reality is frequently inaccurate. Telemetry is refreshed every 1.5 s.",
                        "A towel is the most useful thing a sysadmin can have.",
                        "Resistance is useless. Unless it's thermal.",
                        "The fans are spinning in exactly the way that bricks don't.",
                        "Share and enjoy. Then check the swap."
                    ]
                    property int index: Math.floor(Math.random() * lines.length)
                    text: "> " + lines[index]
                    Timer { interval: 14000; repeat: true; running: true
                            onTriggered: quip.index = (quip.index + 1) % quip.lines.length }
                }
            }
            DontPanicPill { Layout.alignment: Qt.AlignVCenter; pixelSize: 15 }
            GuideButton {
                id: themeSwitch
                Layout.alignment: Qt.AlignVCenter
                text: Theme.dark ? "1981 CRT ▸ 2005 FILM" : "2005 FILM ▸ 1981 CRT"
                tone: Theme.dark ? Theme.amber : Theme.coral
                onClicked: settings.theme = Theme.dark ? "light" : "dark"
            }
        }

        // ---- tab strip ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: win.tabs
                Item {
                    id: tabItem
                    required property var modelData
                    required property int index
                    readonly property bool current: win.currentTab === index
                    implicitWidth: tabLabel.implicitWidth + 30
                    implicitHeight: tabLabel.implicitHeight + 16

                    Rectangle {   // flat shadow (light), only under the current tab
                        visible: Theme.flatShadow && tabItem.current
                        x: 2; y: 2; width: tabFace.width; height: tabFace.height
                        radius: tabFace.radius
                        color: Theme.charcoal
                    }
                    Rectangle {
                        id: tabFace
                        width: parent.width - 2; height: parent.height - 2
                        radius: Theme.pillRadius
                        color: tabItem.current ? (Theme.dark ? Theme.withAlpha(Theme.phosphor, 0.14) : Theme.mustard)
                             : tabArea.containsMouse ? Theme.tint(0.06) : "transparent"
                        border.width: tabItem.current ? (Theme.dark ? 1 : 2) : 1
                        border.color: tabItem.current ? Theme.ink : Theme.tint(Theme.dark ? 0.25 : 0.35)
                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: (tabItem.index + 1) + " " + tabItem.modelData.label
                            color: tabItem.current ? Theme.ink : Theme.tint(0.7)
                            font { family: Theme.mono; pixelSize: 12; bold: true; letterSpacing: 1.2 }
                        }
                    }
                    MouseArea {
                        id: tabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.currentTab = tabItem.index
                    }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "SUB-ETHA FEED " + (telemetry.interval / 1000).toFixed(1) + " s"
                color: Theme.tint(0.5)
                font { family: Theme.mono; pixelSize: 10; letterSpacing: 1 }
            }
            Rectangle {   // feed LED, blinking on every sample
                id: led
                width: 8; height: 8; radius: 4
                color: Theme.high
                Connections { target: telemetry; function onDataChanged() { ledBlink.restart() } }
                SequentialAnimation on opacity {
                    id: ledBlink
                    running: false
                    NumberAnimation { to: 1; duration: 60 }
                    NumberAnimation { to: 0.25; duration: 900 }
                }
            }
        }

        // ---- tabs ----
        // Each tab loads the first time it is opened and then stays, so its
        // scroll and selection survive switching away.
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: win.currentTab
            Repeater {
                model: win.tabs
                Loader {
                    required property var modelData
                    required property int index
                    active: win.currentTab === index || item !== null
                    source: modelData.source
                    onLoaded: item.shown = Qt.binding(() => win.currentTab === index && win.visible
                                                       && win.visibility !== Window.Minimized)
                }
            }
        }

        // ---- status line ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle { height: 1; Layout.fillWidth: true; Layout.maximumWidth: 18; color: Theme.tint(0.4) }
            Text {
                Layout.fillWidth: true
                text: win.status || "ALL SYSTEMS MOSTLY HARMLESS. CTRL+1-5 TABS, CTRL+T THEME."
                color: win.status ? (win.statusOk ? Theme.cool : Theme.alert) : Theme.tint(0.5)
                elide: Text.ElideRight
                font { family: Theme.mono; pixelSize: 11; bold: win.status !== "" }
            }
            Text {
                id: clock
                color: Theme.tint(0.5)
                font { family: Theme.mono; pixelSize: 11 }
                text: Qt.formatTime(new Date(), "HH:mm:ss")
                Timer { interval: 1000; repeat: true; running: true
                        onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm:ss") }
            }
        }
    }
    Timer { id: statusTimer; interval: 7000; onTriggered: win.status = "" }

    CrtOverlay { anchors.fill: parent; z: 1000 }
}
