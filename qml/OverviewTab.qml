import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"

// The master view: the host's profile with a Guide entry fitted to how the
// machine is doing, then a tile per subsystem (CPU, GPU, memory, cooling,
// network, storage), each with live readings and a 24-sample sparkline.
Flickable {
    id: tab

    property bool shown: false
    readonly property var t: telemetry.data
    readonly property var specs: telemetry.specs
    readonly property var cpu: t.cpu || {}
    // each core's recent load, 0..1, for a skin's per-core traces (controls.coreGraph "multi")
    property var coreHist: []
    onCpuChanged: {
        if (!Theme.coreTraces) return
        var now = cpu.perCore || []
        coreHist = now.slice(0, 16).map(function (v, i) {
            return (coreHist[i] || []).concat([Math.max(0, Math.min(1, (Number(v) || 0) / 100))]).slice(-40)
        })
    }
    readonly property var gpu: t.gpu || {}
    readonly property var mem: t.mem || {}
    readonly property var net: t.net || {}
    readonly property var hist: t.history || {}
    readonly property var fans: t.fans || []
    readonly property var battery: t.battery || {}
    readonly property int columns: width >= 1240 ? 3 : 2

    // A critical figure on the CRT terminal or a glitch skin jumps a pixel now and then.
    property real jitterY: 0
    SequentialAnimation on jitterY {
        running: tab.shown && Alerts.motion && Theme.alertJitter
                 && (Alerts.cpuLoad === 2 || Alerts.gpuLoad === 2 || Alerts.ram === 2)
        loops: Animation.Infinite
        onRunningChanged: if (!running) tab.jitterY = 0
        PauseAnimation { duration: 1100 }
        PropertyAction { value: -1 }
        PauseAnimation { duration: 70 }
        PropertyAction { value: 0 }
        PauseAnimation { duration: 260 }
        PropertyAction { value: -1 }
        PauseAnimation { duration: 50 }
        PropertyAction { value: 0 }
    }

    // The Guide's verdict, or the active skin's line for the same level
    // (plain words where the skin has none).
    function verdict(skinLine, guide, plain) { return skinLine || Theme.lex("", guide, plain) }
    readonly property string entry: {
        var q = Theme.quips
        if (Alerts.cpuTemp === 2 || Alerts.gpuTemp === 2)
            return verdict(q.critical, "WARNING: TEMPERATURES APPROACHING THOSE OF A SMALL SUN. DON'T PANIC.",
                           "CRITICAL: TEMPERATURES ABOVE THE CRITICAL THRESHOLD.")
        if ((cpu.usage || 0) >= 85)
            return verdict(q.highLoad, "INFINITE IMPROBABILITY DRIVE ENGAGED: EVERY CORE IS THINKING VERY HARD.",
                           "HIGH LOAD: EVERY CORE IS BUSY.")
        if ((mem.percent || 0) >= 90)
            return verdict(q.moderate, "MEMORY NEARLY FULL. LIKE THE GUIDE, IT HAS MANY OMISSIONS BUT IS CHEAPER.",
                           "MEMORY NEARLY FULL.")
        if ((gpu.usage || 0) >= 80)
            return verdict(q.moderate, "THE GRAPHICS ENGINE IS RENDERING THE SUNSETS OF MAGRATHEA.",
                           "THE GPU IS UNDER HEAVY LOAD.")
        if (battery.present && !battery.plugged && battery.percent < 20)
            return verdict("", "BATTERY LOW. PLEASE FIND A TOWEL AND A WALL SOCKET.", "BATTERY LOW. CONNECT THE CHARGER.")
        if ((cpu.usage || 0) < 10)
            return verdict(q.nominal, "MOSTLY HARMLESS. THE MACHINE IS CONTEMPLATING THE ANSWER.", "SYSTEM IDLE.")
        return verdict(q.nominal, "ALL SYSTEMS NOMINAL. SHARE AND ENJOY.", "ALL SYSTEMS NOMINAL.")
    }

    function cpuFanDuty() {
        var f = fans.find(f => /CPU/.test(f.label)) || fans[0]
        return f ? f.duty : 0
    }
    function gpuFanDuty() {
        var f = fans.find(f => /GPU/.test(f.label) || f.chip === "amdgpu")
        return f ? f.duty : 0
    }

    contentWidth: width
    contentHeight: grid.implicitHeight + profile.implicitHeight + 16
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: GuideScrollBar {}

    // ---- system profile ----
    GuideCard {
        id: profile
        width: tab.width - 10
        title: Theme.lex("profileTitle", "SYSTEM PROFILE", "SYSTEM PROFILE") + "  //  " + (tab.specs.host || "").toUpperCase()
        icon: "app"
        subtitle: Theme.lex("entryLabel", "GUIDE ENTRY", "STATUS") + ": " + tab.entry
        header: [
            Text {
                visible: tab.battery.present === true
                text: "BAT " + Math.round(tab.battery.percent || 0) + "%" + (tab.battery.plugged ? " ⚡" : "")
                color: Theme.level(tab.battery.percent || 0)
                font { family: Theme.mono; features: Theme.figures; pixelSize: 14; bold: true }
            }
        ]
        GridLayout {
            Layout.fillWidth: true
            columns: 6
            columnSpacing: 18
            rowSpacing: 6
            ReadoutLabel { Layout.fillWidth: true; Layout.columnSpan: 2; label: "PROCESSOR"; value: (tab.specs.cpuModel || "") + "  " + tab.specs.cores + "C/" + tab.specs.threads + "T" }
            ReadoutLabel { Layout.fillWidth: true; Layout.columnSpan: 2; label: Theme.lex("gpuLabel", "GRAPHICS ENGINE", "GRAPHICS"); value: tab.specs.gpuModel || "--" }
            ReadoutLabel { Layout.fillWidth: true; label: "MEMORY"; value: Theme.bytes(tab.specs.ramTotal, 0) }
            ReadoutLabel { Layout.fillWidth: true; label: "KERNEL"; value: tab.specs.kernel || "--" }
        }
    }

    GridLayout {
        id: grid
        y: profile.height + 16
        width: tab.width - 10
        columns: tab.columns
        columnSpacing: 16
        rowSpacing: 16

        // ---- CPU ----
        GuideCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: Theme.lex("cpuTitle", "CPU  //  PROCESSING CORE", "CPU")
            icon: "cpu"
            section: "cpu"
            subtitle: tab.specs.cpuModel || ""
            alertTracked: true
            alertLevel: Alerts.cpuLevel
            alertFigure: Alerts.cpuText
            live: tab.shown
            header: [ DynamicFanBlade { width: 28; height: 28; duty: tab.cpuFanDuty(); strokeColor: Theme.ink } ]

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Row {   // the cartoon lab's three half dials (controls.dialStyle "semicircle")
                    visible: Theme.analogDial && Theme.dialStyle === "semicircle"
                    spacing: 6
                    SemiDial { caption: "USAGE"; value: (tab.cpu.usage || 0) / 100; live: tab.shown }
                    SemiDial { caption: "SPEED"; value: tab.cpu.freqMax > 0 ? (tab.cpu.freq || 0) / tab.cpu.freqMax : 0; live: tab.shown }
                    SemiDial { caption: "TEMP"; value: (tab.cpu.temp || 0) / (Theme.controls.dialTempMax || 100); live: tab.shown }
                }
                AnalogDial {   // a skin's round meter (geometry.gaugeShape "analog-dial")
                    visible: Theme.analogDial && Theme.dialStyle !== "semicircle"
                    Layout.preferredWidth: 72; Layout.preferredHeight: 72
                    value: tab.cpu.usage || 0
                    figure: Theme.pct(tab.cpu.usage)
                    caption: "CPU Usage"
                    live: tab.shown
                }
                Text {
                    text: Theme.pct(tab.cpu.usage)
                    color: Theme.levelInk(Alerts.cpuLoad, Theme.load(tab.cpu.usage || 0))
                    font { family: Theme.mono; features: Theme.figures; pixelSize: 40; bold: true }
                    transform: Translate { y: Alerts.cpuLoad === 2 ? tab.jitterY : 0 }
                }
                ReadoutLabel { Layout.fillWidth: true; label: "TEMP"; value: Theme.temp(tab.cpu.temp); valueColor: Theme.levelInk(Alerts.cpuTemp, Theme.heat(tab.cpu.temp || 0)) }
                ReadoutLabel { Layout.fillWidth: true; label: "CLOCK"; value: Theme.ghz(tab.cpu.freq) }
                ReadoutLabel { Layout.fillWidth: true; label: "LOAD AVG"; value: (tab.cpu.load || [0]).map(v => v.toFixed(2)).join(" ") }
            }
            DualMetricBar {
                Layout.fillWidth: true
                usageFraction: (tab.cpu.usage || 0) / 100
                tempValue: tab.cpu.temp || 0
                tempLevel: Alerts.cpuTemp
                loadLevel: Alerts.cpuLoad
                live: tab.shown
                segmentHeight: 12
                segments: 30
            }
            Text {
                text: "LOAD (FILL) OVER TEMPERATURE (WASH, 30-100°C)"
                color: Theme.tint(0.45)
                font { family: Theme.mono; features: Theme.figures; pixelSize: 9; letterSpacing: 0.8 }
            }
            SparklineGraph {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                historyData: tab.hist.cpu || []
                strokeColor: Theme.load(tab.cpu.usage || 0)
            }
            Column {   // a skin's per-core traces: a jagged line each, labelled
                visible: Theme.coreTraces
                Layout.fillWidth: true
                spacing: 1
                Repeater {
                    model: Theme.coreTraces ? tab.coreHist.length : 0
                    Row {
                        id: coreRow
                        required property int index
                        width: parent.width
                        spacing: 6
                        Text {
                            width: 58
                            anchors.verticalCenter: parent.verticalCenter
                            text: (Theme.controls.coreLabel || "CORE ") + (coreRow.index + 1)
                            color: Theme.coreColor(coreRow.index)
                            font { family: Theme.mono; features: Theme.figures; pixelSize: 9; bold: true }
                        }
                        SparklineGraph {
                            width: coreRow.width - 64; height: 14
                            capacity: 40
                            lineWidth: 1.5
                            backdrop: false
                            fillColor: "transparent"
                            historyData: tab.coreHist[coreRow.index] || []
                            strokeColor: Theme.coreColor(coreRow.index)
                        }
                    }
                }
            }
            Flow {   // one micro meter per thread
                visible: !Theme.coreTraces
                Layout.fillWidth: true
                spacing: 3
                Repeater {
                    model: tab.cpu.perCore || []
                    Item {
                        required property var modelData
                        required property int index
                        width: 14; height: 30
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: coreNo.top; bottomMargin: 2 }
                            // the Guide's outlined cells; a skin's gauge track, rounded with its gauges
                            color: Theme.skinned ? Theme.gaugeTrack : "transparent"
                            radius: Theme.skinned && Theme.roundCaps ? width / 2 : 0
                            border.width: Theme.skinned ? 0 : 1
                            border.color: Theme.tint(0.3)
                            Rectangle {
                                readonly property real inset: Theme.skinned ? 0 : 2
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: inset }
                                height: Math.max(0, (parent.height - 2 * inset) * Math.min(1, modelData / 100))
                                radius: parent.radius
                                color: Theme.gaugeLoad(modelData)
                                Behavior on height { NumberAnimation { duration: 400 } }
                            }
                        }
                        Text {
                            id: coreNo
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            text: index
                            color: Theme.tint(0.45)
                            font { family: Theme.mono; features: Theme.figures; pixelSize: 7 }
                        }
                    }
                }
            }
        }

        // ---- GPU ----
        GuideCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: Theme.lex("gpuTitle", "GPU  //  GRAPHICS ENGINE", "GPU")
            icon: "gpu"
            section: "gpu"
            subtitle: tab.gpu.name || "NO GRAPHICS ENGINE DETECTED"
            alertTracked: !!tab.gpu.name
            alertLevel: Alerts.gpuLevel
            alertFigure: Alerts.gpuText
            live: tab.shown
            header: [ DynamicFanBlade { width: 28; height: 28; duty: tab.gpuFanDuty(); strokeColor: Theme.ink } ]

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                SemiDial {
                    visible: Theme.analogDial && Theme.dialStyle === "semicircle"
                    caption: "LOAD"
                    value: (tab.gpu.usage || 0) / 100
                    live: tab.shown
                }
                AnalogDial {   // the GPU's temperature, its red zone the skin's danger range
                    visible: Theme.analogDial && Theme.dialStyle !== "semicircle"
                    Layout.preferredWidth: 72; Layout.preferredHeight: 72
                    value: tab.gpu.temp || 0
                    max: Theme.controls.dialTempMax || 100
                    dangerFrom: Theme.controls.dialDangerFrom || -1
                    needle: Theme.ctl("needleTemp", Theme.gaugeTemp)
                    figure: Theme.temp(tab.gpu.temp)
                    caption: "Temperature"
                    live: tab.shown
                }
                Text {
                    text: Theme.pct(tab.gpu.usage)
                    color: Theme.levelInk(Alerts.gpuLoad, Theme.load(tab.gpu.usage || 0))
                    font { family: Theme.mono; features: Theme.figures; pixelSize: 40; bold: true }
                    transform: Translate { y: Alerts.gpuLoad === 2 ? tab.jitterY : 0 }
                }
                ReadoutLabel { Layout.fillWidth: true; label: "EDGE"; value: Theme.temp(tab.gpu.temp); valueColor: Theme.levelInk(Alerts.gpuTemp, Theme.heat(tab.gpu.temp || 0)) }
                ReadoutLabel { Layout.fillWidth: true; label: "JUNCTION"; value: Theme.temp(tab.gpu.junction); valueColor: Theme.heat((tab.gpu.junction || 0) - 10) }
                ReadoutLabel { Layout.fillWidth: true; label: "POWER"; value: tab.gpu.power > 0 ? tab.gpu.power.toFixed(1) + " W" : "--" }
            }
            DualMetricBar {
                Layout.fillWidth: true
                usageFraction: (tab.gpu.usage || 0) / 100
                tempValue: tab.gpu.temp || 0
                tempLevel: Alerts.gpuTemp
                loadLevel: Alerts.gpuLoad
                live: tab.shown
                segmentHeight: 12
                segments: 30
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    Layout.preferredWidth: 46
                    text: "VRAM"
                    color: Theme.tint(0.6)
                    font { family: Theme.mono; features: Theme.figures; pixelSize: 10; bold: true }
                }
                SegmentBar {
                    Layout.fillWidth: true
                    fraction: tab.gpu.vramTotal > 0 ? tab.gpu.vramUsed / tab.gpu.vramTotal : 0
                    fill: Theme.cool
                    segments: 30
                }
                Text {
                    text: tab.gpu.vramTotal > 0 ? Theme.bytes(tab.gpu.vramUsed, 1) + " / " + Theme.bytes(tab.gpu.vramTotal, 0) : "--"
                    color: Theme.ink
                    font { family: Theme.mono; features: Theme.figures; pixelSize: 10; bold: true }
                }
            }
            Text {
                text: "MEMORY CONTROLLER " + Theme.pct(tab.gpu.memUsage) + (tab.gpu.memTemp > 0 ? "  ·  VRAM " + Theme.temp(tab.gpu.memTemp) : "")
                color: Theme.tint(0.55)
                font { family: Theme.mono; features: Theme.figures; pixelSize: 10 }
            }
            SparklineGraph {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                historyData: tab.hist.gpu || []
                strokeColor: Theme.load(tab.gpu.usage || 0)
            }
            Item { Layout.fillHeight: true }
        }

        // ---- memory ----
        GuideCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: Theme.lex("memoryTitle", "MEMORY  //  CORE STORE", "MEMORY")
            icon: "ram"
            section: "memory"
            subtitle: Theme.bytes(tab.mem.used, 1) + " OF " + Theme.bytes(tab.mem.total, 0) + " IN USE"
            alertTracked: true
            alertLevel: Alerts.ram
            alertFigure: Alerts.ramText
            live: tab.shown

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Text {
                    text: Theme.pct(tab.mem.percent)
                    color: Theme.levelInk(Alerts.ram, Theme.load(tab.mem.percent || 0))
                    font { family: Theme.mono; features: Theme.figures; pixelSize: 40; bold: true }
                    transform: Translate { y: Alerts.ram === 2 ? tab.jitterY : 0 }
                }
                ReadoutLabel { Layout.fillWidth: true; label: "AVAILABLE"; value: Theme.bytes(tab.mem.available, 1) }
                ReadoutLabel { Layout.fillWidth: true; label: "CACHED"; value: Theme.bytes(tab.mem.cached, 1) }
            }
            SegmentBar {
                Layout.fillWidth: true
                fraction: (tab.mem.percent || 0) / 100
                segments: 30
                segmentHeight: 12
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Image {   // the skin's swap icon
                    visible: source != ""
                    Layout.preferredWidth: 16; Layout.preferredHeight: 16
                    source: Theme.icon("swap")
                    sourceSize: Qt.size(32, 32)
                }
                Text {
                    Layout.preferredWidth: 46
                    text: "SWAP"
                    color: Theme.tint(0.6)
                    font { family: Theme.mono; features: Theme.figures; pixelSize: 10; bold: true }
                }
                SegmentBar {
                    Layout.fillWidth: true
                    fraction: (tab.mem.swapPercent || 0) / 100
                    segments: 30
                }
                Text {
                    text: tab.mem.swapTotal > 0 ? Theme.bytes(tab.mem.swapUsed, 1) + " / " + Theme.bytes(tab.mem.swapTotal, 0) : "NONE"
                    color: Theme.ink
                    font { family: Theme.mono; features: Theme.figures; pixelSize: 10; bold: true }
                }
            }
            SparklineGraph {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                historyData: tab.hist.ram || []
                strokeColor: Theme.load(tab.mem.percent || 0)
            }
            Item { Layout.fillHeight: true }
        }

        // ---- fans ----
        GuideCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: Theme.lex("coolingTitle", "COOLING ARRAYS", "COOLING")
            icon: "fan"
            subtitle: tab.fans.length ? tab.fans.length + " FAN" + (tab.fans.length > 1 ? "S" : "") + " REPORTING" : "NO FAN TELEMETRY"

            Repeater {
                model: tab.fans
                RowLayout {
                    id: fanRow
                    required property var modelData
                    readonly property int full: modelData.full
                    readonly property real duty: modelData.duty
                    Layout.fillWidth: true
                    spacing: 14
                    DynamicFanBlade {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        duty: fanRow.duty
                        strokeColor: Theme.load(fanRow.duty * 100)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: fanRow.modelData.label
                                color: Theme.ink
                                font { family: Theme.mono; features: Theme.figures; pixelSize: 12; bold: true; letterSpacing: 0.8 }
                            }
                            Text {
                                text: Theme.rpm(fanRow.modelData.rpm)
                                color: Theme.ink
                                font { family: Theme.mono; features: Theme.figures; pixelSize: 16; bold: true }
                            }
                        }
                        SegmentBar {
                            Layout.fillWidth: true
                            fraction: fanRow.duty
                            segments: 24
                        }
                        SparklineGraph {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            historyData: Theme.norm((tab.t.fanHistory || {})[fanRow.modelData.label], fanRow.full)
                            strokeColor: Theme.cool
                            lineWidth: 1
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // ---- network ----
        GuideCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: Theme.lex("networkTitle", "SUB-ETHA NETWORK", "NETWORK")
            icon: "netDown"
            section: "network"
            subtitle: tab.net.iface ? (tab.net.iface + "  ·  " + (tab.net.kind || "").toUpperCase()).toUpperCase() : "NO ACTIVE LINK"

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                ReadoutLabel { Layout.fillWidth: true; label: "▼ DOWNLOAD"; value: Theme.rate(tab.net.rx); valueSize: 20; valueColor: Theme.netDown }
                ReadoutLabel { Layout.fillWidth: true; label: "▲ UPLOAD"; value: Theme.rate(tab.net.tx); valueSize: 20; valueColor: Theme.netUp }
            }
            Item {   // two-way plot: download up from the axis, upload hanging below
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                readonly property real peak: Math.max(1024, Math.max.apply(null, (tab.hist.rx || []).concat(tab.hist.tx || []).concat([0])))
                SparklineGraph {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: parent.height / 2
                    historyData: Theme.norm(tab.hist.rx, parent.peak)
                    strokeColor: Theme.netDown
                }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Theme.tint(0.3) }
                SparklineGraph {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: parent.height / 2
                    historyData: Theme.norm(tab.hist.tx, parent.peak)
                    strokeColor: Theme.netUp
                    inverted: true
                }
            }
            CopyableValue { Layout.fillWidth: true; label: "LAN IP"; value: tab.net.lan || "" }
            CopyableValue {
                Layout.fillWidth: true
                label: "WAN IP"
                value: telemetry.wanState === "ok" ? telemetry.wanIp : telemetry.wanState === "offline" ? "OFFLINE" : "RESOLVING..."
            }
            Item { Layout.fillHeight: true }
        }

        // ---- storage ----
        GuideCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: Theme.lex("storageTitle", "DATA BANKS", "STORAGE")
            icon: "disk"
            section: "disk"
            subtitle: "READ " + Theme.rate(tab.t.diskRead) + "  ·  WRITE " + Theme.rate(tab.t.diskWrite)
            alertTracked: true
            alertLevel: Alerts.disks
            live: tab.shown

            Repeater {
                model: (tab.t.disks || []).slice(0, 5)
                ColumnLayout {
                    id: diskRow
                    required property var modelData
                    readonly property bool critical: Alerts.loadLevel("disk", modelData.percent) === 2
                    Layout.fillWidth: true
                    spacing: 3
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: diskRow.modelData.mount + "  [" + diskRow.modelData.fstype + "]"
                            color: diskRow.critical ? Theme.critColor : Theme.ink
                            elide: Text.ElideMiddle
                            font { family: Theme.mono; features: Theme.figures; pixelSize: 11; bold: true }
                        }
                        Text {
                            text: Theme.bytes(diskRow.modelData.used, 0) + " / " + Theme.bytes(diskRow.modelData.total, 0)
                            color: Theme.tint(0.7)
                            font { family: Theme.mono; features: Theme.figures; pixelSize: 10 }
                        }
                    }
                    SegmentBar {
                        Layout.fillWidth: true
                        fraction: diskRow.modelData.percent / 100
                        segments: 30
                        fill: diskRow.critical ? Theme.critColor : Theme.load(diskRow.modelData.percent)
                    }
                    Text {
                        text: "R " + Theme.rate(diskRow.modelData.read) + "   W " + Theme.rate(diskRow.modelData.write)
                        color: Theme.tint(0.55)
                        font { family: Theme.mono; features: Theme.figures; pixelSize: 9 }
                    }
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                readonly property real peak: Math.max(1048576, Math.max.apply(null, (tab.hist.diskRead || []).concat(tab.hist.diskWrite || []).concat([0])))
                SparklineGraph { anchors.fill: parent; historyData: Theme.norm(tab.hist.diskRead, parent.peak); strokeColor: Theme.ink }
                SparklineGraph { anchors.fill: parent; historyData: Theme.norm(tab.hist.diskWrite, parent.peak); strokeColor: Theme.cool; fillColor: "transparent"; backdrop: false }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
