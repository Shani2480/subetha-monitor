pragma Singleton
import QtQuick
import "."

// The alert state the tabs share, judged as the widget's AlertManager does:
// 0 nominal, 1 warning, 2 critical, against the thresholds in `settings`.
// Temperature and load are judged on their own and the higher one wins;
// temperatures have a warning and a critical step, loads and disks only a
// critical one. A level rises or falls only once the reading has held it for
// `holdMs` (SustainedLevel), so a one-sample spike never trips an alert.
// With alerts off everything is nominal; with motion off the levels keep
// their colours but nothing breathes, blinks or strobes.
QtObject {
    id: alerts

    readonly property bool enabled: settings.alertsEnabled
    readonly property bool motion: enabled && settings.enablePulsingAnimations
    readonly property int holdMs: settings.alertHoldSeconds * 1000   // how long a reading must stay at a level before it shows

    function tempLevel(kind, celsius) {
        if (!enabled || !(celsius > 0)) return 0
        var crit = kind === "gpu" ? settings.gpuTempCritThreshold : settings.cpuTempCritThreshold
        var warn = kind === "gpu" ? settings.gpuTempWarnThreshold : settings.cpuTempWarnThreshold
        return celsius >= crit ? 2 : celsius >= warn ? 1 : 0
    }
    function loadLevel(kind, percent) {
        if (!enabled) return 0
        var crit = kind === "gpu" ? settings.gpuLoadCritThreshold : kind === "ram" ? settings.ramLoadCritThreshold
                 : kind === "disk" ? settings.diskCritThreshold : settings.cpuLoadCritThreshold
        return percent >= crit ? 2 : 0
    }

    readonly property var t: telemetry.data
    readonly property var cpu: t.cpu || {}
    readonly property var gpu: t.gpu || {}
    readonly property var mem: t.mem || {}
    readonly property SustainedLevel cpuTempHold: SustainedLevel { interval: alerts.holdMs; raw: alerts.tempLevel("cpu", alerts.cpu.temp || 0) }
    readonly property SustainedLevel cpuLoadHold: SustainedLevel { interval: alerts.holdMs; raw: alerts.loadLevel("cpu", alerts.cpu.usage || 0) }
    readonly property SustainedLevel gpuTempHold: SustainedLevel { interval: alerts.holdMs; raw: alerts.tempLevel("gpu", alerts.gpu.temp || 0) }
    readonly property SustainedLevel gpuLoadHold: SustainedLevel {
        interval: alerts.holdMs; raw: alerts.gpu.name ? alerts.loadLevel("gpu", alerts.gpu.usage || 0) : 0 }
    readonly property SustainedLevel ramHold: SustainedLevel { interval: alerts.holdMs; raw: alerts.loadLevel("ram", alerts.mem.percent || 0) }
    // switching alerts off clears them at once
    readonly property int cpuTemp: enabled ? cpuTempHold.level : 0
    readonly property int cpuLoad: enabled ? cpuLoadHold.level : 0
    readonly property int gpuTemp: enabled ? gpuTempHold.level : 0
    readonly property int gpuLoad: enabled ? gpuLoadHold.level : 0
    readonly property int ram: enabled ? ramHold.level : 0
    readonly property int cpuLevel: Math.max(cpuTemp, cpuLoad)
    readonly property int gpuLevel: Math.max(gpuTemp, gpuLoad)
    readonly property int disks: (t.disks || []).some(d => loadLevel("disk", d.percent) === 2) ? 2 : 0

    // The badge's figure: the reading that tripped it.
    readonly property string cpuText: cpuTemp === 2 ? Theme.temp(cpu.temp) : Theme.pct(cpu.usage)
    readonly property string gpuText: gpuTemp === 2 ? Theme.temp(gpu.temp) : Theme.pct(gpu.usage)
    readonly property string ramText: Theme.pct(mem.percent)
}
