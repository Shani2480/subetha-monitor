import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"

// The monitor's preferences: what closing and minimizing do with the tray,
// where the tabs sit, how often telemetry is sampled, which tab opens first,
// the skin (shared with the Sub-Etha Guide widget) and the theme, picked
// from a preview of each. Every change is saved to settings.configPath at once.
Flickable {
    id: tab

    property bool shown: false
    readonly property var startupTabs: [{ value: "last", label: "LAST OPENED" }].concat(
        settings.tabs.map(k => ({ value: k, label: { overview: "OVERVIEW", sensors: "HARDWARE SENSORS", processes: "PROCESSES", services: "SYSTEMD UNITS",
                                                     network: "NETWORK", disks: "STORAGE", settings: "SETTINGS" }[k] })))

    clip: true
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: GuideScrollBar {}

    component Note: Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.tint(0.55)
        font { family: Theme.mono; features: Theme.figures; pixelSize: 11 }
    }
    component Label: Text {
        color: Theme.ink
        font { family: Theme.mono; features: Theme.figures; pixelSize: 12; bold: true; letterSpacing: 0.6 }
    }

    // A thumbnail of one look, drawn in its own palette whatever the current
    // theme (under a skin, that variant's): title bar, rail with the pill, a
    // card with a meter.
    component Preview: Item {
        id: pv
        property bool look: true          // true: the terminal
        readonly property var pal: Theme.look(look)
        readonly property color bg: pal.bg
        readonly property color card: pal.card
        readonly property color ink: pal.ink
        readonly property color pillColor: pal.pill
        Rectangle {
            anchors.fill: parent
            color: pv.bg
            radius: 6
            border { width: pv.look ? 1 : 2; color: pv.ink }
        }
        Rectangle { x: 2; y: 2; width: parent.width - 4; height: 14; radius: 4; color: "transparent"
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: pv.ink; opacity: 0.6 } }
        Rectangle { x: 8; y: 6; width: 6; height: 6; radius: 3; color: "#2BD65C" }
        Rectangle { x: 18; y: 8; width: 50; height: 2; color: pv.ink; opacity: 0.8 }
        Repeater {
            model: 3
            Text { required property int index; x: parent.width - 34 + index * 10; y: 2; text: ["_", "□", "✕"][index]
                   color: pv.ink; font { family: Theme.mono; features: Theme.figures; pixelSize: 8 } }
        }
        Rectangle {   // the rail and its pill
            x: 2; y: 17; width: 38; height: parent.height - 19
            color: Qt.tint(pv.bg, Qt.rgba(pv.ink.r, pv.ink.g, pv.ink.b, 0.04))
            Rectangle { x: 5; y: 21; width: 28; height: 8; radius: 2; color: pv.pillColor
                        border { width: 1; color: pv.ink } }
            Repeater { model: 4; Rectangle { required property int index; x: 8; y: 13 + index * 12
                                              width: 18; height: 2; color: pv.ink; opacity: 0.6 } }
        }
        Rectangle {   // a card
            x: 48; y: 24; width: parent.width - 58; height: parent.height - 34
            radius: pv.look ? 2 : 6
            color: pv.card
            border { width: pv.look ? 1 : 2; color: pv.look ? Qt.rgba(pv.ink.r, pv.ink.g, pv.ink.b, 0.5) : pv.ink }
            Rectangle { x: 8; y: 8; width: parent.width * 0.5; height: 3; color: pv.ink }
            Rectangle { x: 8; y: 18; width: parent.width - 16; height: 6; color: "transparent"; border { width: 1; color: pv.ink }
                        Rectangle { width: parent.width * 0.6; height: parent.height; color: pv.pal.good } }
            Rectangle { x: 8; y: 30; width: parent.width * 0.35; height: 8; radius: 4
                        color: pv.look ? "transparent" : pv.pal.accent; border { width: 1; color: pv.look ? pv.pal.accent : pv.ink } }
        }
    }

    // One alert threshold: caption, slider, figure; saved on release.
    component ThresholdRow: RowLayout {
        id: row
        property string label: ""
        property string key: ""
        property string unit: "°C"
        property int from: 40
        property int to: 110
        spacing: 12
        enabled: settings.alertsEnabled
        opacity: enabled ? 1 : 0.5
        Label { text: row.label; Layout.preferredWidth: 220 }
        GuideSlider {
            id: slider
            Layout.preferredWidth: 320
            from: row.from; to: row.to; stepSize: 1
            snapMode: Slider.SnapAlways
            value: settings[row.key]
            onPressedChanged: if (!pressed) settings[row.key] = Math.round(value)
        }
        Label { text: Math.round(slider.value) + " " + row.unit; color: Theme.accent; Layout.preferredWidth: 60 }
    }

    component ThemeCard: Item {
        id: tc
        property string key
        property string title
        property string blurb
        readonly property bool selected: settings.theme === key
        default property alias preview: frameSlot.data
        implicitWidth: 250
        implicitHeight: col.implicitHeight + 24

        Rectangle {   // flat shadow (light)
            visible: Theme.flatShadow
            x: 2; y: 2; width: parent.width - 2; height: parent.height - 2
            radius: Theme.outerRadius
            color: Theme.charcoal
        }
        Rectangle {
            width: parent.width - 2; height: parent.height - 2
            radius: Theme.outerRadius
            // Opaque on the film pages, or the shadow would show through.
            color: Theme.dark ? (tc.selected ? Theme.withAlpha(Theme.phosphor, 0.08) : area.containsMouse ? Theme.tint(0.05) : Theme.card)
                 : tc.selected ? Qt.tint(Theme.cream, Theme.withAlpha(Theme.mustard, 0.45))
                 : Qt.tint(Theme.card, area.containsMouse ? Theme.tint(0.05) : "transparent")
            border { width: tc.selected ? 2 : (Theme.line); color: tc.selected ? Theme.accent : Theme.dark ? Theme.tint(0.4) : Theme.charcoal }
        }
        ColumnLayout {
            id: col
            x: 12; y: 12
            width: parent.width - 26
            spacing: 8
            Item { id: frameSlot; Layout.fillWidth: true; implicitHeight: 110 }
            Label { text: (tc.selected ? "[x] " : "[ ] ") + tc.title; color: tc.selected ? Theme.accent : Theme.ink }
            Note { text: tc.blurb }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: settings.theme = tc.key
        }
    }

    ColumnLayout {
        id: column
        width: tab.width - 14
        spacing: 16

        // ---- window & tray ----
        GuideCard {
            Layout.fillWidth: true
            title: "WINDOW & SYSTEM TRAY"
            subtitle: tray.available ? "The planet in the tray keeps watch while the window is away."
                                     : "No system tray was found: closing and minimizing behave as usual."
            GuideCheck {
                enabled: tray.available
                text: "MINIMIZE TO SYSTEM TRAY ON WINDOW CLOSE"
                checked: settings.closeToTray
                onToggled: c => settings.closeToTray = c
            }
            GuideCheck {
                enabled: tray.available
                text: "MINIMIZE TO SYSTEM TRAY INSTEAD OF THE TASKBAR"
                checked: settings.minimizeToTray
                onToggled: c => settings.minimizeToTray = c
            }
            GuideCheck {
                enabled: tray.available
                text: "START MINIMIZED TO SYSTEM TRAY"
                checked: settings.startMinimized
                onToggled: c => settings.startMinimized = c
            }
            GuideCheck {
                enabled: tray.available
                text: "SHOW LIVE METRICS IN TRAY TOOLTIP"
                checked: settings.trayTooltip
                onToggled: c => settings.trayTooltip = c
            }
            RowLayout {
                Layout.topMargin: 6
                spacing: 12
                Label { text: "TRAY ICON SHOWS"; Layout.preferredWidth: 220 }
                GuideCombo {
                    id: trayMetric
                    textRole: "label"
                    valueRole: "value"
                    model: [
                        { value: "planet", label: "THE PLANET (LOGO)" },
                        { value: "cpu", label: "CPU USAGE %" },
                        { value: "cpuTemp", label: "CPU TEMPERATURE" },
                        { value: "ram", label: "MEMORY USAGE %" },
                        { value: "swap", label: "SWAP USAGE %" },
                        { value: "gpu", label: "GPU USAGE %" },
                        { value: "gpuTemp", label: "GPU TEMPERATURE" }
                    ]
                    function sync() { currentIndex = indexOfValue(settings.trayMetric) }
                    Component.onCompleted: sync()
                    Connections { target: settings; function onTrayMetricChanged() { trayMetric.sync() } }
                    onActivated: settings.trayMetric = currentValue
                }
                Repeater {
                    model: [{ key: "number", label: "NUMBER" }, { key: "graph", label: "GRAPH" }]
                    GuideButton {
                        required property var modelData
                        enabled: settings.trayMetric !== "planet"
                        text: (settings.trayStyle === modelData.key ? "● " : "○ ") + modelData.label
                        checked: settings.trayStyle === modelData.key
                        onClicked: settings.trayStyle = modelData.key
                    }
                }
                // The icon as the panel gets it, at two common tray sizes.
                Repeater {
                    model: [32, 22]
                    Image {
                        required property int modelData
                        Layout.leftMargin: 6
                        Layout.preferredWidth: modelData
                        Layout.preferredHeight: modelData
                        source: tray.preview || "../assets/subetha-icon.svg"
                        sourceSize: Qt.size(64, 64)
                        smooth: true
                        mipmap: true
                    }
                }
            }
            Note {
                text: settings.trayMetric !== "planet" && !tray.preview
                      ? "NO READING FOR THAT ON THIS MACHINE (YET): THE TRAY SHOWS THE PLANET UNTIL ONE ARRIVES."
                      : "A graph spans the last 20 samples; temperatures run from 30 to 100 °C. The colour follows the level, as on the Overview."
            }
            Note { text: "Quit from the tray icon's menu (right-click) or with Ctrl+Q." }
        }

        // ---- layout ----
        GuideCard {
            Layout.fillWidth: true
            title: "LAYOUT & INTERFACE"

            RowLayout {
                spacing: 12
                Label { text: "TAB POSITION"; Layout.preferredWidth: 220 }
                Repeater {
                    model: [{ key: "left", label: "LEFT SIDEBAR" }, { key: "top", label: "TOP HEADER" }]
                    GuideButton {
                        required property var modelData
                        text: (settings.tabPosition === modelData.key ? "● " : "○ ") + modelData.label
                        checked: settings.tabPosition === modelData.key
                        onClicked: settings.tabPosition = modelData.key
                    }
                }
            }
            RowLayout {
                spacing: 12
                Label { text: "TELEMETRY INTERVAL"; Layout.preferredWidth: 220 }
                GuideSlider {
                    id: interval
                    Layout.preferredWidth: 320
                    from: 0.5; to: 5.0; stepSize: 0.1
                    snapMode: Slider.SnapAlways
                    value: settings.interval / 1000
                    // Saved on release, not on every step of the drag.
                    onPressedChanged: if (!pressed) settings.interval = Math.round(value * 10) * 100
                }
                Label { text: interval.value.toFixed(1) + " s"; color: Theme.accent; Layout.preferredWidth: 60 }
            }
            Note { text: "How often the sensors, process table and sparklines are read. Faster costs a little CPU; histories keep their sample count, so they span less time." }
            RowLayout {
                spacing: 12
                Label { text: "DEFAULT STARTUP TAB"; Layout.preferredWidth: 220 }
                GuideCombo {
                    textRole: "label"
                    valueRole: "value"
                    model: tab.startupTabs
                    Component.onCompleted: currentIndex = indexOfValue(settings.startupTab)
                    onActivated: settings.startupTab = currentValue
                }
            }
        }

        // ---- alerts ----
        GuideCard {
            Layout.fillWidth: true
            title: "ALERTS"
            subtitle: "Amber at a warning, crimson when critical; the same thresholds as the Sub-Etha Guide widget's defaults."
            GuideCheck {
                text: "COLOUR READINGS AT THE THRESHOLDS"
                checked: settings.alertsEnabled
                onToggled: c => settings.alertsEnabled = c
            }
            GuideCheck {
                enabled: settings.alertsEnabled
                text: "ANIMATE THEM: BREATHING GLOW, BLINKING BADGES, STROBING BARS"
                checked: settings.enablePulsingAnimations
                onToggled: c => settings.enablePulsingAnimations = c
            }
            ThresholdRow { label: "CPU TEMP WARNING"; key: "cpuTempWarnThreshold" }
            ThresholdRow { label: "CPU TEMP CRITICAL"; key: "cpuTempCritThreshold" }
            ThresholdRow { label: "GPU TEMP WARNING"; key: "gpuTempWarnThreshold" }
            ThresholdRow { label: "GPU TEMP CRITICAL"; key: "gpuTempCritThreshold" }
            ThresholdRow { label: "CPU LOAD CRITICAL"; key: "cpuLoadCritThreshold"; unit: "%"; from: 50; to: 100 }
            ThresholdRow { label: "GPU LOAD CRITICAL"; key: "gpuLoadCritThreshold"; unit: "%"; from: 50; to: 100 }
            ThresholdRow { label: "MEMORY CRITICAL"; key: "ramLoadCritThreshold"; unit: "%"; from: 50; to: 100 }
            ThresholdRow { label: "DISK FULL CRITICAL"; key: "diskCritThreshold"; unit: "%"; from: 50; to: 100 }
            ThresholdRow { label: "ALERT AFTER"; key: "alertHoldSeconds"; unit: "s"; from: 0; to: 30 }
            Note { text: "A warning shows [WARN] on the card and colours its figure amber. A critical reading blinks [CRITICAL], haloes its card and strobes or pulses its bar. A reading must stay past a threshold for ALERT AFTER seconds before its level shows, and back below it as long before the level clears (0: at once); disks alert at once. A warning above its critical level is never reached: keep warning below critical." }
        }

        // ---- skin ----
        GuideCard {
            Layout.fillWidth: true
            title: "SKIN"
            subtitle: "The Guide's own look, or a skin from the widget's Theme Store, installed in " + themes.themesDir
            RowLayout {
                spacing: 12
                Label { text: "ACTIVE SKIN"; Layout.preferredWidth: 220 }
                GuideCombo {
                    id: skinPicker
                    implicitWidth: 360
                    textRole: "label"
                    valueRole: "value"
                    model: Theme.choices
                    function sync() { currentIndex = indexOfValue(settings.skin) }
                    onModelChanged: sync()
                    Component.onCompleted: sync()
                    Connections { target: settings; function onSkinChanged() { skinPicker.sync() } }
                    onActivated: themes.setTheme(currentValue, settings.theme)
                }
            }
            Note {
                visible: !!Theme.active
                text: Theme.active ? Theme.active.name + (Theme.active.author ? " by " + Theme.active.author : "")
                                     + " · v" + Theme.active.version + (Theme.active.description ? ". " + Theme.active.description : "") : ""
            }
            GuideCheck {
                text: "KEEP THE SKIN AND THEME IN STEP WITH THE SUB-ETHA GUIDE WIDGET"
                checked: themes.sync
                onToggled: c => themes.sync = c
            }
            Note { text: "Shared through " + themes.stateFile + ": a change in either app restyles the other at once. Turning this on hands the widget this window's look." }
        }

        // ---- theme ----
        GuideCard {
            Layout.fillWidth: true
            title: "THEME"
            subtitle: "Ctrl+T, the title bar or the tray menu flip between the first two."
            Flow {
                Layout.fillWidth: true
                spacing: 16
                ThemeCard {
                    key: "dark"; title: Theme.lex("darkTitle", "1981 SUB-ETHA CRT DARK", "DARK")
                    blurb: Theme.lex("darkBlurb", "Phosphor green on tube black, scanlines and amber reticles.", "The skin's dark variant.")
                    Preview { anchors.fill: parent; look: true }
                }
                ThemeCard {
                    key: "light"; title: Theme.lex("lightTitle", "2005 MOVIE LIGHT", "LIGHT")
                    blurb: Theme.lex("lightBlurb", "Cream Encyclopedia pages, charcoal ink, hard flat shadows.", "The skin's light variant.")
                    Preview { anchors.fill: parent; look: false }
                }
                ThemeCard {
                    key: "auto"; title: "SOLAR AUTO"
                    blurb: Theme.lex("autoBlurb", "The film pages from 07:00 to 19:00, the terminal after dark.", "Light from 07:00 to 19:00, dark after.")
                    Item {
                        anchors.fill: parent
                        Item {
                            width: parent.width / 2; height: parent.height; clip: true
                            Preview { width: parent.parent.width; height: parent.height; look: false }
                        }
                        Item {
                            x: parent.width / 2; width: parent.width / 2; height: parent.height; clip: true
                            Preview { x: -parent.x; width: parent.parent.width; height: parent.height; look: true }
                        }
                        Text { anchors.centerIn: parent; text: "☀ / ☾"; color: Theme.amber; style: Text.Outline; styleColor: Theme.charcoal
                               font { family: Theme.mono; features: Theme.figures; pixelSize: 16; bold: true } }
                    }
                }
            }
        }

        Note { text: "SAVED TO " + settings.configPath }
    }
}
