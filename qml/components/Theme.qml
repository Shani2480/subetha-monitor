pragma Singleton
import QtQuick

// The monitor's design tokens: the same two looks as the Sub-Etha Guide
// widget (contents/ui/common/SubEthaTheme.qml), the 1981 BBC Sub-Etha terminal
// (dark) and the 2005 film's cream Encyclopedia pages (light), plus the number
// formatting every tab shares. MainAppWindow sets `dark` from the settings.
QtObject {
    id: theme

    property bool dark: true

    // ---- raw palette ----
    readonly property color cream:    "#F5F2EB"
    readonly property color paper:    "#EDE8DC"
    readonly property color charcoal: "#1B2028"
    readonly property color coral:    "#FF6B4A"
    readonly property color mustard:  "#FFBE1A"
    readonly property color teal:     "#26A69A"
    readonly property color crtBlack: "#040806"
    readonly property color crtCard:  "#07110C"
    readonly property color phosphor: "#00FF66"
    readonly property color amber:    "#FFB000"
    readonly property color cyan:     "#00E5FF"
    readonly property color red:      "#FF3333"

    // ---- roles ----
    readonly property color bg:     dark ? crtBlack : cream
    readonly property color card:   dark ? crtCard : paper
    readonly property color ink:    dark ? phosphor : charcoal     // text and outlines
    readonly property color badge:  dark ? amber : mustard         // DON'T PANIC
    readonly property color accent: dark ? amber : coral           // commentary, selection
    readonly property color cool:   dark ? cyan : teal             // upload, writes, I/O
    readonly property color alert:  dark ? red : "#E53935"
    readonly property color reticle: dark ? amber : charcoal
    // Fill by how healthy a level is: good, middling, bad
    readonly property color high:   dark ? phosphor : teal
    readonly property color mid:    dark ? amber : mustard
    readonly property color low:    dark ? red : coral

    readonly property string mono: "monospace"
    readonly property string sans: dark ? "monospace" : Qt.application.font.family
    readonly property real outerRadius: dark ? 4 : 16
    readonly property real pillRadius: dark ? 2 : 10
    readonly property bool flatShadow: !dark     // 2px 2px solid charcoal, no blur

    readonly property int animMs: 180

    function tint(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    // Load-style level: higher is worse.
    function load(p) { return p >= 85 ? low : p >= 50 ? mid : high }
    // Battery-style level: higher is better.
    function level(p) { return p >= 50 ? high : p >= 20 ? mid : low }
    function heat(t) { return t >= 90 ? low : t >= 75 ? mid : high }

    // ---- formatting ----
    function bytes(n, digits) {
        n = Number(n) || 0
        var u = ["B", "KB", "MB", "GB", "TB", "PB"], i = 0
        while (Math.abs(n) >= 1024 && i < u.length - 1) { n /= 1024; i++ }
        var d = digits !== undefined ? digits : (i === 0 ? 0 : n >= 100 ? 0 : n >= 10 ? 1 : 2)
        return n.toFixed(d) + " " + u[i]
    }
    function rate(n) { return bytes(n) + "/s" }
    function mbps(n) { return ((Number(n) || 0) / 1048576).toFixed(1) }
    function pct(v) { return Math.round(Number(v) || 0) + "%" }
    function temp(v) { return v > 0 ? Math.round(v) + "°C" : "--" }
    function rpm(v) { return Math.round(Number(v) || 0) + " RPM" }
    function ghz(mhz) { return mhz > 0 ? (mhz / 1000).toFixed(2) + " GHz" : "--" }
    function duration(secs) {
        secs = Math.max(0, Math.floor(secs))
        var d = Math.floor(secs / 86400), h = Math.floor(secs % 86400 / 3600), m = Math.floor(secs % 3600 / 60)
        return (d ? d + "d " : "") + (d || h ? h + "h " : "") + m + "m"
    }
    // A history scaled to 0..1 for SparklineGraph: by `max`, or by its own peak.
    function norm(history, max) {
        var h = history || []
        var top = max > 0 ? max : Math.max.apply(null, h.concat([1e-9]))
        return h.map(function (v) { return Math.max(0, Math.min(1, (Number(v) || 0) / top)) })
    }
}
