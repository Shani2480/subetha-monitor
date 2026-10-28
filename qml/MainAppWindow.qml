import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts
import "components"

// The monitor's window, frameless: its own title bar (planet, name, theme
// switch, window controls), the navigation as a left rail or a top strip, a
// masthead (host profile, a rotating entry from the Guide, the feed LED), the
// six tabs and a status line, inside a rounded frame with the CRT tube laid
// over it in the dark theme. Grips along the edges resize it.
//
// Closing hides to the system tray while settings.closeToTray is on and a
// tray exists; otherwise it quits. Context properties from main.py:
// settings, telemetry, processes, services, tray.
ApplicationWindow {
    id: win

    readonly property var tabs: [
        { key: "overview",  label: "OVERVIEW",  source: "OverviewTab.qml" },
        { key: "processes", label: "PROCESSES", source: "ProcessesTab.qml" },
        { key: "services",  label: "SYSTEMD UNITS", source: "ServicesTab.qml" },
        { key: "network",   label: "NETWORK",   source: "NetworkTab.qml" },
        { key: "disks",     label: "STORAGE",   source: "DisksTab.qml" },
        { key: "settings",  label: "SETTINGS",  source: "SettingsTab.qml" }
    ]
    property int currentTab: 0
    readonly property var t: telemetry.data
    readonly property var specs: telemetry.specs
    property string status: ""
    property bool statusOk: true
    readonly property bool maximized: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property bool leftNav: settings.tabPosition === "left"
    readonly property real frameRadius: maximized ? 0 : 12
    property bool wasMaximized: false

    function showTab(key) {
        var i = tabs.findIndex(t => t.key === key)
        if (i >= 0) currentTab = i
    }
    function report(message, ok) {
        status = message
        statusOk = ok
        statusTimer.restart()
    }
    function toggleTheme() { settings.theme = Theme.dark ? "light" : "dark" }
    function saveGeometry() {
        if (visibility === Window.Windowed) settings.saveSize(width, height)
    }
    function restore() {
        if (wasMaximized) showMaximized()
        else showNormal()
        raise()
        requestActivate()
    }
    function hideToTray() {
        saveGeometry()
        wasMaximized = maximized
        hide()
        tray.hintOnce()
    }
    function minimize() {
        if (settings.minimizeToTray && tray.available) hideToTray()
        else showMinimized()
    }

    width: 1280
    height: 860
    minimumWidth: 1024
    minimumHeight: 620
    visible: false                       // shown from Component.onCompleted, unless starting in the tray
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Sub-Etha System Monitor"
    color: "transparent"                 // the frame paints the page, round-cornered
    font.family: Theme.sans

    Component.onCompleted: {
        Theme.dark = Qt.binding(() => settings.dark)
        width = Math.max(minimumWidth, settings.width)
        height = Math.max(minimumHeight, settings.height)
        showTab(settings.startTab)
        if (!(settings.startMinimized && tray.available)) show()
    }
    onCurrentTabChanged: settings.tab = tabs[currentTab].key
    onClosing: close => {
        if (settings.closeToTray && tray.available) {
            close.accepted = false
            hideToTray()
        } else {
            saveGeometry()
            Qt.callLater(tray.quit)
        }
    }
    // A minimize from the compositor (the taskbar, a shortcut) where it tells us.
    onVisibilityChanged: v => {
        if (v === Window.Minimized && settings.minimizeToTray && tray.available) Qt.callLater(hideToTray)
    }

    Connections {
        target: settings
        function onTabRequested(key) {
            if (key) win.showTab(key)
            win.restore()
        }
    }
    Connections {
        target: tray
        function onActivateRequested() {
            if (win.visible && win.active && win.visibility !== Window.Minimized) win.hideToTray()
            else win.restore()
        }
        function onToggleThemeRequested() { win.toggleTheme() }
    }
    Connections { target: Qt.application; function onAboutToQuit() { win.saveGeometry() } }
    Connections { target: processes; function onActionResult(m, ok) { win.report(m, ok) } }
    Connections { target: services; function onActionResult(m, ok) { win.report(m, ok) } }
    Connections { target: telemetry; function onCopied(text) { win.report("COPIED " + text + " TO THE CLIPBOARD", true) } }

    Shortcut { sequence: "Ctrl+1"; onActivated: win.currentTab = 0 }
    Shortcut { sequence: "Ctrl+2"; onActivated: win.currentTab = 1 }
    Shortcut { sequence: "Ctrl+3"; onActivated: win.currentTab = 2 }
    Shortcut { sequence: "Ctrl+4"; onActivated: win.currentTab = 3 }
    Shortcut { sequence: "Ctrl+5"; onActivated: win.currentTab = 4 }
    Shortcut { sequence: "Ctrl+6"; onActivated: win.currentTab = 5 }
    Shortcut { sequence: "Ctrl+,"; onActivated: win.currentTab = 5 }
    Shortcut { sequence: "Ctrl+T"; onActivated: win.toggleTheme() }
    Shortcut { sequence: StandardKey.Quit; onActivated: { win.saveGeometry(); tray.quit() } }

    // ---- the frame ----
    Item {
        id: frame
        anchors.fill: parent
        // Room for the film's flat shadow while floating.
        anchors.rightMargin: Theme.flatShadow && !win.maximized ? 3 : 0
        anchors.bottomMargin: anchors.rightMargin

        Rectangle {   // flat offset shadow (light)
            visible: Theme.flatShadow && !win.maximized
            x: 3; y: 3; width: parent.width; height: parent.height
            radius: win.frameRadius
            color: Theme.charcoal
        }

        Rectangle {
            id: frameMask
            anchors.fill: parent
            radius: win.frameRadius
            visible: false
            layer.enabled: true
        }

        // Everything inside, clipped to the round corners (square ones on
        // the software renderer, which has no shader effects).
        Item {
            id: surface
            anchors.fill: parent
            layer.enabled: win.frameRadius > 0 && GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: frameMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle { anchors.fill: parent; color: Theme.bg }

            // Coordinate grid under everything: 24px phosphor squares on the
            // terminal, charcoal hairlines on the cream page.
            Image {
                anchors.fill: parent
                source: Theme.dark ? "components/grid-dark.svg" : "components/grid-light.svg"
                sourceSize: Qt.size(24, 24)
                fillMode: Image.Tile
                smooth: false
                opacity: Theme.dark ? 0.05 : 0.06
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                SubEthaTitleBar {
                    Layout.fillWidth: true
                    window: win
                    onToggleTheme: win.toggleTheme()
                    onMinimizeRequested: win.minimize()
                    onCloseRequested: win.close()
                }
                Rectangle {   // the rule under the title bar
                    Layout.fillWidth: true
                    implicitHeight: Theme.dark ? 1 : 2
                    color: Theme.dark ? Theme.tint(0.45) : Theme.charcoal
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    NavRail {
                        visible: win.leftNav
                        Layout.fillHeight: true
                        Layout.preferredWidth: implicitWidth
                        tabs: win.tabs
                        currentIndex: win.currentTab
                        collapsed: settings.sidebarCollapsed
                        uptime: win.t.uptime || 0
                        onSelected: i => win.currentTab = i
                        onToggleTheme: win.toggleTheme()
                        onToggleCollapsed: settings.sidebarCollapsed = !settings.sidebarCollapsed
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 18
                        Layout.topMargin: 14
                        spacing: 14

                        // ---- masthead ----
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            DynamicFanBlade {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                duty: (win.t.fans || []).reduce((m, f) => Math.max(m, f.duty), 0)
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
                                        "Reality is frequently inaccurate. Telemetry is refreshed every "
                                            + (telemetry.interval / 1000).toFixed(1) + " s.",
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
                            Text {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 6
                                text: "SUB-ETHA FEED " + (telemetry.interval / 1000).toFixed(1) + " s"
                                color: Theme.tint(0.5)
                                font { family: Theme.mono; pixelSize: 10; letterSpacing: 1 }
                            }
                            Rectangle {   // feed LED, blinking on every sample
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 8
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

                        // ---- top tab strip, with a pill that slides to the current tab ----
                        Item {
                            visible: !win.leftNav
                            Layout.fillWidth: true
                            implicitHeight: tabRow.implicitHeight

                            Item {
                                id: topPill
                                readonly property Item target: tabRep.count > win.currentTab ? tabRep.itemAt(win.currentTab) : null
                                x: target ? target.x : 0
                                width: target ? target.width : 0
                                height: tabRow.height
                                Behavior on x { NumberAnimation { duration: Theme.animMs + 60; easing.type: Easing.OutCubic } }
                                Behavior on width { NumberAnimation { duration: Theme.animMs + 60; easing.type: Easing.OutCubic } }
                                Rectangle {   // flat offset shadow
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

                            Row {
                                id: tabRow
                                spacing: 6
                                Repeater {
                                    id: tabRep
                                    model: win.tabs
                                    Item {
                                        id: tabItem
                                        required property var modelData
                                        required property int index
                                        readonly property bool current: win.currentTab === index
                                        implicitWidth: tabLabel.implicitWidth + 30
                                        implicitHeight: tabLabel.implicitHeight + 16
                                        width: implicitWidth
                                        height: implicitHeight

                                        Rectangle {
                                            width: parent.width - 2; height: parent.height - 2
                                            radius: Theme.pillRadius
                                            color: !tabItem.current && tabArea.containsMouse ? Theme.tint(0.06) : "transparent"
                                            border.width: tabItem.current ? 0 : 1
                                            border.color: Theme.tint(Theme.dark ? 0.25 : 0.35)
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
                                text: win.status || "ALL SYSTEMS MOSTLY HARMLESS. CTRL+1-6 TABS, CTRL+T THEME."
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
                }
            }

            CrtOverlay { anchors.fill: parent; z: 1000 }
        }

        // ---- the outline: a phosphor rule with a soft inner glow, or a charcoal one ----
        Rectangle {
            anchors.fill: parent
            visible: !win.maximized
            radius: win.frameRadius
            color: "transparent"
            border { width: Theme.dark ? 1 : 2; color: Theme.dark ? Theme.phosphor : Theme.charcoal }
            Rectangle {
                visible: Theme.dark
                anchors { fill: parent; margins: 1 }
                radius: parent.radius - 1
                color: "transparent"
                border { width: 3; color: Theme.withAlpha(Theme.phosphor, 0.1) }
            }
        }
        Repeater {   // CRT corner brackets
            model: Theme.dark && !win.maximized ? 4 : 0
            Item {
                required property int index
                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index >= 2
                width: 12; height: 12
                x: atRight ? frame.width - width - 5 : 5
                y: atBottom ? frame.height - height - 5 : 5
                Rectangle { width: parent.width; height: 1.5; y: parent.atBottom ? parent.height - height : 0; color: Theme.amber }
                Rectangle { width: 1.5; height: parent.height; x: parent.atRight ? parent.width - width : 0; color: Theme.amber }
            }
        }
    }

    // ---- resize grips: 6px edges, 12px corners, handed to the compositor ----
    component Grip: MouseArea {
        property int edges
        enabled: !win.maximized
        hoverEnabled: true
        onPressed: win.startSystemResize(edges)
    }
    Grip { edges: Qt.LeftEdge;   cursorShape: Qt.SizeHorCursor; width: 6; anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 12; bottomMargin: 12 } }
    Grip { edges: Qt.RightEdge;  cursorShape: Qt.SizeHorCursor; width: 6; anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 12; bottomMargin: 12 } }
    Grip { edges: Qt.TopEdge;    cursorShape: Qt.SizeVerCursor; height: 6; anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 } }
    Grip { edges: Qt.BottomEdge; cursorShape: Qt.SizeVerCursor; height: 6; anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 } }
    Grip { edges: Qt.TopEdge | Qt.LeftEdge;     cursorShape: Qt.SizeFDiagCursor; width: 12; height: 12; anchors { top: parent.top; left: parent.left } }
    Grip { edges: Qt.BottomEdge | Qt.RightEdge; cursorShape: Qt.SizeFDiagCursor; width: 12; height: 12; anchors { bottom: parent.bottom; right: parent.right } }
    Grip { edges: Qt.TopEdge | Qt.RightEdge;    cursorShape: Qt.SizeBDiagCursor; width: 12; height: 12; anchors { top: parent.top; right: parent.right } }
    Grip { edges: Qt.BottomEdge | Qt.LeftEdge;  cursorShape: Qt.SizeBDiagCursor; width: 12; height: 12; anchors { bottom: parent.bottom; left: parent.left } }

    Timer { id: statusTimer; interval: 7000; onTriggered: win.status = "" }
}
