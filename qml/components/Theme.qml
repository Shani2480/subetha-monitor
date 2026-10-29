pragma Singleton
import QtQuick
import "skins.js" as Skins

// The monitor's design tokens: the same two looks as the Sub-Etha Guide
// widget (contents/ui/common/SubEthaTheme.qml), the 1981 BBC Sub-Etha terminal
// (dark) and the 2005 film's cream Encyclopedia pages (light), plus the number
// formatting every tab shares. MainAppWindow sets `wantDark` from the settings.
//
// A community skin (the widget's, installed under ~/.local/share/subetha/
// themes/, parsed by the widget's own skins.js) replaces the raw palette, so
// every role and direct use follows it, and brings the geometry the
// components draw through ThemeShapeContainer: card, pill and gauge shapes,
// border, corner brackets and shadow. Without one every token is the Guide's.
QtObject {
    id: theme

    signal settingsRequested()                   // a Sidebar gadget's gear (GuideCard); MainAppWindow opens Settings
    property bool wantDark: true                 // the settings' light / dark, "auto" resolved
    property var installed: []                   // [{ id, dir, json }] from main.py's `themes`
    property string activeId: "h2g2"             // "h2g2": the Guide's own palette

    // (through JSON, so main.py's lists arrive as plain arrays for skins.js's Array.isArray)
    readonly property var skins: installed.map(function (s) {
        try { return Skins.entry(s.id, s.dir, JSON.parse(JSON.stringify(s.json))) } catch (e) { return null }
    }).filter(function (s) { return s })
    // Every look the title bar and Settings offer: the Guide's own, then each installed skin.
    readonly property var choices: [{ value: "h2g2", label: "H2G2 · SUB-ETHA GUIDE" }].concat(
        skins.map(function (s) { return { value: s.id, label: s.name.toUpperCase() } }))
    readonly property var active: skins.find(function (s) { return s.id === activeId }) || null
    readonly property var skin: active ? active.style : null
    readonly property bool skinned: !!skin
    // A skin with light and dark variants follows the setting; one without keeps its single look.
    readonly property bool dark: skin && !skin.variants && skin.isDark !== null ? skin.isDark : wantDark
    readonly property var variant: skin && skin.variants ? skin.variants[dark ? "dark" : "light"] : null
    readonly property var skinColors: !skin ? ({}) : variant ? Object.assign({}, skin.colors, variant.colors) : skin.colors
    function sc(key, fallback) { return skinColors[key] ? skinColors[key] : fallback }

    // ---- raw palette (a skin replaces all of it) ----
    readonly property color cream:    sc("background", "#F5F2EB")
    readonly property color paper:    sc("cardBackground", "#EDE8DC")
    readonly property color charcoal: sc("textPrimary", "#1B2028")
    readonly property color coral:    sc("accentSecondary", "#FF6B4A")
    readonly property color mustard:  sc("accent", "#FFBE1A")
    readonly property color teal:     sc("accentTertiary", "#26A69A")
    readonly property color crtBlack: sc("background", "#040806")
    readonly property color crtCard:  sc("cardBackground", "#07110C")
    readonly property color phosphor: sc("textPrimary", "#00FF66")
    readonly property color amber:    sc("accent", "#FFB000")
    readonly property color cyan:     sc("accentTertiary", "#00E5FF")
    readonly property color red:      sc("accentSecondary", "#FF3333")

    // ---- roles ----
    readonly property color bg:     dark ? crtBlack : cream
    readonly property color card:   dark ? crtCard : paper
    readonly property color ink:    dark ? phosphor : charcoal     // text and outlines
    readonly property color badge:  variant && variant.badgeColor ? variant.badgeColor
                                  : skin && skin.badgeColor ? skin.badgeColor : dark ? amber : mustard   // DON'T PANIC
    readonly property color accent: dark ? amber : coral           // commentary, selection
    readonly property color cool:   dark ? cyan : teal             // upload, writes, I/O
    readonly property color alert:  dark || skinned ? red : "#E53935"
    // alert levels (Alerts.qml): fixed, so a skin's palette never hides a warning
    readonly property color warnColor: dark ? "#FFB000" : "#E8890C"     // warning: amber
    readonly property color critColor: dark ? "#FF2A4B" : "#D91B33"     // critical: crimson
    // the CRT terminal and glitch skins jitter a critical figure by a pixel
    readonly property bool alertJitter: (dark && !skinned) || (!!frame && frame.glitch === true)
    function levelInk(level, resting) { return level === 2 ? critColor : level === 1 ? warnColor : resting }
    readonly property color reticle: skinned ? bracketColor : dark ? amber : charcoal
    // Fill by how healthy a level is: good, middling, bad
    readonly property color high:   sc("accentGood", dark ? phosphor : teal)
    readonly property color mid:    dark ? amber : mustard
    readonly property color low:    dark ? red : coral

    // ---- skin-only roles; without a skin each is the Guide's own look ----
    readonly property color inkSoft:    sc("textSecondary", tint(0.6))
    readonly property color commentary: sc("commentary", accent)
    readonly property color cardHover:  sc("cardBackgroundHover", tint(0.05))
    readonly property color border:     sc("border", dark ? tint(0.55) : ink)
    readonly property color shadow:     sc("shadowColor", dark ? tint(0.4) : ink)
    readonly property color badgeInk:   variant && variant.badgeTextColor ? variant.badgeTextColor
                                      : skin && skin.badgeTextColor ? skin.badgeTextColor : dark ? badge : ink
    readonly property string badgeText: !skin ? "DON'T PANIC" : skin.badgeText || active.name.toUpperCase()
    readonly property var quips: skin ? skin.quips : ({})       // { nominal, moderate, highLoad, critical, night }
    readonly property var frame: !skin || !skin.frame ? null
                               : variant ? Object.assign({}, skin.frame, variant.frame) : skin.frame
    readonly property var labels: skin ? skin.labels : ({})
    readonly property color sparkline: sc("sparkline", "transparent")     // transparent: as the Guide colours it

    // ---- geometry, as SubEthaTheme reads it; ThemeShapeContainer draws it ----
    readonly property var geo: skin ? skin.geometry : ({})
    function gv(key, fallback) { var v = geo[key]; return v === null || v === undefined || v === "" ? fallback : v }
    readonly property real legacyChamfer: frame && frame.chamfer ? frame.chamfer : 0
    readonly property real legacyRadius: skin && skin.borderRadius !== null ? skin.borderRadius : -1
    readonly property string cardShape: gv("cardShape", legacyChamfer > 0 ? "chamfer"
                                                      : legacyRadius === 0 || (!skin && dark) ? "sharp" : "rounded")
    readonly property string pillShape: gv("pillShape", skin ? (legacyRadius === 0 ? "sharp" : "rounded") : dark ? "sharp" : "stadium")
    readonly property string gaugeShape: gv("gaugeShape", !skin ? (dark ? "segmented" : "stadium")
                                                        : ({ blocks: "segmented", slot: "flat", tube: "stadium" })[skin.gaugeStyle])
    readonly property real cornerRadius: gv("cornerRadius", legacyRadius >= 0 ? legacyRadius : 12)
    readonly property real pillCornerRadius: gv("pillRadius", Math.min(12, cornerRadius))
    readonly property real chamferCut: gv("chamferCut", legacyChamfer || 12)
    readonly property real pillChamferCut: gv("pillChamferCut", Math.min(6, chamferCut))
    readonly property real stadiumMax: 24
    readonly property string borderStyle: gv("borderStyle", "solid")
    readonly property real borderWidth: Math.max(cartoon ? 3 : 0, gv("borderWidth", skin && skin.borderWidth !== null ? skin.borderWidth : dark ? 1 : 2))
    readonly property bool cornerBrackets: skin && skin.features && skin.features.cornerBrackets !== null
                                           ? skin.features.cornerBrackets : gv("hasCornerBrackets", skin ? !!(frame && frame.brackets) : true)
    readonly property color bracketColor: frame && frame.brackets ? frame.brackets : !skin ? (dark ? amber : ink) : border
    readonly property bool legacyShadow: !!skin && (skin.shadowOffset[0] || skin.shadowOffset[1]) && shadow.a > 0
    readonly property string shadowType: cartoon ? "flat-2d" : geo.hasDropShadow === false ? "none"
        : gv("shadowType", !skin ? (dark ? "glow" : "flat-2d")
                         : legacyShadow ? (skin.shadowBlur > 0 ? "soft" : "flat-2d") : "none")
    readonly property real shadowX: cartoon && !(geo.shadowOffset || [])[0] ? 3 : shadowType === "glow" || shadowType === "none" ? 0
        : (geo.shadowOffset || [])[0] ?? (skin && skin.shadowOffset[0] !== null ? skin.shadowOffset[0] : 2)
    readonly property real shadowY: cartoon && !(geo.shadowOffset || [])[1] ? 3 : shadowType === "glow" || shadowType === "none" ? 0
        : (geo.shadowOffset || [])[1] ?? (skin && skin.shadowOffset[1] !== null ? skin.shadowOffset[1] : 2)
    readonly property real shadowBlur: gv("shadowBlur", skin && skin.shadowBlur !== null ? skin.shadowBlur * 24 : shadowType === "glow" ? 6 : 0)
    function shapeOf(role) { return role === "pill" ? pillShape : role === "gauge" ? ({ segmented: "sharp", flat: "sharp", "analog-dial": "sharp" })[gaugeShape] || gaugeShape : cardShape }
    function radiusOf(role) { return role === "pill" ? pillCornerRadius : role === "gauge" ? 2 : cornerRadius }
    function chamferOf(role) { return role === "card" ? chamferCut : pillChamferCut }

    // A skin names its fonts as a list (skins.js); the first installed one is
    // used, after any the skin ships itself (`fontFiles`) have loaded. Tables
    // stay aligned through tabular figures (`figures`), whatever the font.
    property int fontsLoaded: 0                   // bumped as a skin's own font files load
    readonly property var fontFiles: skin ? skin.fontFiles : []
    readonly property string sans: { fontsLoaded
        return skin ? Skins.resolveFont(skin.fonts, Qt.fontFamilies(), "sans-serif")
                    : dark ? "monospace" : Qt.application.font.family }
    readonly property string mono: { fontsLoaded
        return skin ? Skins.resolveFont(skin.monoFonts.length ? skin.monoFonts : skin.fonts, Qt.fontFamilies(), "monospace")
                    : "monospace" }
    readonly property var figures: ({ "tnum": 1 })
    property var fontLoaders: []                  // FontLoaders for the skin's own files, kept alive here
    onFontFilesChanged: {
        var loaders = []
        fontFiles.forEach(function (url) {
            var known = fontLoaders.find(function (f) { return f.source.toString() === url })
            if (known) { loaders.push(known); return }
            var f = Qt.createQmlObject('import QtQuick; FontLoader {}', theme)
            f.statusChanged.connect(function () { if (f.status === FontLoader.Ready) theme.fontsLoaded++ })
            f.source = url
            if (f.status === FontLoader.Ready) theme.fontsLoaded++      // a local file loads at once
            loaders.push(f)
        })
        fontLoaders = loaders
    }

    // A label in the Guide's own words, or the skin's (its narrative.lexicon)
    // or plain ones: no H2G2 lore shows under a skin.
    function lex(key, h2g2Text, neutralText) {
        if (!skin) return h2g2Text
        return skin.lexicon && skin.lexicon[key] ? skin.lexicon[key] : neutralText
    }

    // The effects layer (ThemeEffectsLayer): a skin turns each on in its
    // `features`; a 1.x skin without them keeps its frame's scanlines and
    // brackets. The Guide's own: the CRT's on the dark terminal.
    function feature(key, legacy) { var v = skin.features ? skin.features[key] : null; return v === null || v === undefined ? legacy : v }
    readonly property var fx: !skin ? { crtScanlines: dark, phosphorDecay: dark, cornerBrackets: dark, glassBlur: false, grid: true } : {
        crtScanlines: feature("crtScanlines", dark && !!frame && !!frame.scanlines),
        phosphorDecay: feature("phosphorDecay", false),
        cornerBrackets: feature("cornerBrackets", !!frame && !!frame.brackets),
        glassBlur: feature("glassBlur", false),
        grid: feature("grid", false)
    }

    // ---- the operating system a skin imitates (skins.js 2.1.0) ----
    // `chrome` the window's title bar, buttons and frame; `sections` cards or
    // Win32 group bands; `controls` meters and graphs; `icons` its own SVGs.
    // The colours in each lie over the skin's own per variant. Unskinned, or
    // with a style left empty, each is the Guide's own look.
    function merged(part) {
        if (!skin || !skin[part]) return { colors: {} }
        var over = variant && variant[part] ? variant[part] : {}
        return Object.assign({}, skin[part], { colors: Object.assign({}, skin[part].colors, over) })
    }
    readonly property var chrome: merged("chrome")
    readonly property string chromeStyle: chrome.style || ""
    function cc(key, fallback) { var v = chrome.colors[key]; return v ? v : fallback }
    readonly property var sections: merged("sections")
    readonly property bool groupBands: sections.style === "groupband"
    readonly property bool gadgets: sections.style === "gadget"          // Vista Sidebar gadgets
    readonly property bool screws: !!sections.screws                     // a mounting screw in each card corner
    // a card's own surface (sections.tints), by its key (cpu, gpu, memory, network, disk)
    function tintOf(key) {
        var v = variant && variant.tints && variant.tints[key] ? variant.tints[key]
              : skin && skin.sections && skin.sections.tints ? skin.sections.tints[key] : ""
        return v ? v : card
    }
    // hero illustrations for the cards' free corners, and characters with speech bubbles
    readonly property var art: skin && skin.art ? skin.art : ({})
    function vignette(at) { return skin && skin.vignettes ? skin.vignettes.find(function (v) { return v.at === at }) || null : null }
    // thick ink outlines and flat offset shadows on everything
    readonly property bool cartoon: !!skin && feature("cartoonOutlines", false) === true
    readonly property bool portalSpin: !!skin && feature("portalSpinners", false) === true
    readonly property bool slimeDrips: !!skin && feature("slimeDrips", false) === true
    readonly property string frameStyle: frame && frame.style ? frame.style : ""     // bezel, handheld, console, scrap
    function sec(key, fallback) { var v = sections.colors[key]; return v ? v : fallback }
    readonly property var controls: merged("controls")
    readonly property string meterStyle: controls.meter || ""
    readonly property string graphStyle: controls.graph || "line"
    function ctl(key, fallback) { var v = controls.colors[key]; return v ? v : fallback }
    readonly property bool blinkCursor: !!controls.cursor
    readonly property string dialStyle: controls.dialStyle || "round"
    readonly property bool coreTraces: skinned && controls.coreGraph === "multi"
    function coreColor(i) { var c = controls.coreColors || []; return c.length ? c[i % c.length] : ink }
    readonly property var icons: skin && skin.icons ? skin.icons : ({})
    function icon(key) { return icons[key] || "" }
    readonly property bool barrel: !!skin && feature("barrel", false) === true
    readonly property string texture: skin && skin.features && skin.features.texture ? skin.features.texture : ""
    // network history and figures: download and upload
    readonly property color netDown: skinned ? ctl("graphDown", sc("netDown", ink)) : ink
    readonly property color netUp:   skinned ? ctl("graphUp", sc("netUp", cool)) : cool
    readonly property bool taskmgr: skinned && graphStyle === "taskmgr"
    // geometry.gaugeShape "analog-dial": a round meter beside the CPU and GPU
    // figures; the bars then draw in controls.meter
    readonly property bool analogDial: skinned && gaugeShape === "analog-dial"

    // ---- gauges ----
    readonly property color gaugeTrack: sc("gaugeTrack", tint(dark ? 0.12 : 0.1))
    readonly property color gaugeUsage: sc("gaugeFillUsage", "transparent")   // transparent: by level (load())
    readonly property color gaugeTemp:  sc("gaugeFillTemp", dark ? amber : mustard)
    readonly property color gaugeHot:   skinned ? sc("gaugeFillTemp", amber) : "#FF8A1A"
    readonly property color gaugeEdge:  sc("gaugeFillEdge", "transparent")
    // Plain Rectangle radii: the Guide's own, or what the skin's shapes imply.
    readonly property real outerRadius: !skin ? (dark ? 4 : 16) : cardShape === "rounded" ? cornerRadius : cardShape === "stadium" ? 16 : 0
    readonly property real pillRadius: !skin ? (dark ? 2 : 10) : pillShape === "rounded" ? pillCornerRadius : pillShape === "stadium" ? stadiumMax : 0
    // 2px 2px solid charcoal, no blur, on the film pages; a skin's own flat-2d offset
    readonly property bool flatShadow: !skin ? !dark : shadowType === "flat-2d" && (shadowX !== 0 || shadowY !== 0)
    // The tube's scanlines and the coordinate grid: a skin's chassis is its own ornament.
    readonly property bool scanlines: fx.crtScanlines
    readonly property real scanlineOpacity: frame && frame.scanlines ? frame.scanlines : skin ? 0.12 : 0.08
    readonly property bool grid: fx.grid

    // Small parts drawn as plain Rectangles (dividers, dots, chips, slider
    // tracks): the terminal's 1px square, the film's 2px round, or the skin's.
    readonly property real line: !skin ? (dark ? 1 : 2) : Math.max(1, borderWidth)
    function small(r) { return !skin ? (dark ? 0 : r) : pillShape === "sharp" || pillShape === "chamfer" ? 0 : r }
    readonly property bool roundCaps: !skin ? !dark : ["stadium", "wavy", "rounded"].indexOf(gaugeShape) >= 0
    readonly property bool terminal: dark && !skin       // the 1981 CRT's own touches

    readonly property int animMs: 180

    // The palette of one look, `d` dark or not, whatever is showing: for previews.
    function look(d) {
        var c = !skin ? {} : skin.variants ? Object.assign({}, skin.colors, skin.variants[d ? "dark" : "light"].colors) : skin.colors
        return {
            bg: c.background || (d ? "#040806" : "#F5F2EB"),
            card: c.cardBackground || (d ? "#07110C" : "#EDE8DC"),
            ink: c.textPrimary || (d ? "#00FF66" : "#1B2028"),
            accent: c.accent || (d ? "#FFB000" : "#FFBE1A"),
            pill: (d ? c.accent : c.accentSecondary) || (d ? "#3300FF66" : "#FF6B4A"),
            good: c.accentGood || c.accentTertiary || (d ? "#00FF66" : "#26A69A")
        }
    }

    function tint(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // Text straight on `bg` (the masthead, the status line). A skin's cards
    // carry its text colours, but its background may not: Luna's royal blue
    // under Explorer's dark grey text. The skin's textOnBackground wins; else
    // the colour asked for if it reads there (4.5:1), else black or white.
    function luminance(c) {
        var f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }
    function contrast(a, b) {
        var x = luminance(a), y = luminance(b)
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
    }
    function onBg(c, a) {
        if (!skinned) return withAlpha(c, a === undefined ? c.a : a)
        var pick = skinColors.textOnBackground ? Qt.color(skinColors.textOnBackground)
                 : contrast(c, bg) >= 4.5 ? c
                 : contrast(Qt.rgba(1, 1, 1, 1), bg) >= contrast(Qt.rgba(0, 0, 0, 1), bg) ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1)
        return withAlpha(pick, a === undefined ? 1 : a)
    }
    // Load-style level: higher is worse.
    function load(p) { return p >= 85 ? low : p >= 50 ? mid : high }
    // Battery-style level: higher is better.
    function level(p) { return p >= 50 ? high : p >= 20 ? mid : low }
    // A gauge's fill by load: a skin's usage colour while nominal, then busy and hot.
    function gaugeLoad(p) { return p >= 85 ? low : p >= 50 ? mid : gaugeUsage.a > 0 ? gaugeUsage : high }
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
