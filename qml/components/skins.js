.pragma library

// Parsing a community skin's skin.json into the look SubEthaTheme (the
// widget) and Theme.qml (the Sub-Etha System Monitor) draw from. The same
// file ships in both: edit it here and copy it to the monitor's
// qml/components/skins.js, so the two apps read every skin alike.
//
// A skin is data, never code: skin.json names colours, the geometry of cards,
// pills and gauges (see parseGeometry), a font, the badge and commentary
// lines, and SVGs inside the skin's own folder for the built-in pieces that
// draw them (HandheldChassis.qml, BezelDecor.qml, weather/SpriteRoamers.qml).
// Anything malformed is dropped here, so the views can trust what they get.
//
// Schema 2.0.0 adds, all optional and read alongside the older keys:
//   "fontFamily": "Tahoma, Arial, sans-serif"   a CSS-style list; the first installed family wins
//   "fonts": ["assets/fonts/X.ttf"]             font files the skin ships, loaded before the list is resolved
//   "features": { enableCrtScanlines, enablePhosphorDecay, enableCornerBrackets, enableGlassBlur, enableGrid }
//   "variants": { "dark": { background, …, gaugeUsage, gaugeTemp, badgeBackground, badgeText } }   flat keys
//   "narrative": { badgeLabel, weatherSkyHazard, weatherSkyHazardSecondary, roamerPrimary,
//                  roamerSecondary, quips: { nominal, critical, … }, lexicon: { <key>: <label> } }
//
// Schema 2.1.0 adds the operating system a skin imitates, drawn by built-in
// renderers the data only selects (see parseChrome and friends):
//   "chrome":   the window's title bar, buttons and frame
//   "sections": card panels, or Win32 group bands with a rule under each title
//   "controls": the meter and graph styles (bevel, ascii, gadget, angled; taskmgr)
//   "icons":    the skin's own SVG for each metric (cpu, ram, swap, gpu, …)
//   "art":      hero illustrations for the CPU, GPU, memory, network, disk and weather cards
//   "features": also enableBarrel (CRT glass curvature) and texture ("carbon")
// Colours in chrome / sections / controls may be overridden per variant.
// Under any skin the Guide's own lore (the towel, the whale, "DON'T PANIC")
// never shows: what the skin leaves out falls back to plain labels.

var colorKeys = ["background", "cardBackground", "cardBackgroundHover", "textPrimary", "textSecondary",
                 "accent", "accentSecondary", "accentTertiary", "accentGood", "border", "shadowColor",
                 "gaugeTrack", "gaugeFillUsage", "gaugeFillTemp", "sparkline", "sparklineFill",
                 "netDown", "netUp", "gaugeFillEdge", "sparklineDanger", "sparklineHot", "commentary",
                 "textOnBackground",           // text drawn straight on `background` (mastheads); default: whichever reads
                 "borderActive"]               // the border of the card in focus (hovered, or the open section)
var quipKeys = ["nominal", "moderate", "highLoad", "critical", "night"]
var frameColorKeys = ["dpad", "brackets", "slash", "watermarkColor", "rivets", "dials", "plaque", "plaqueText", "plaqueSubtext", "slime", "rim"]

// "#RRGGBB", "#AARRGGBB", "rgb(r, g, b)" or "rgba(r, g, b, a)" as "#AARRGGBB"; "" if none of those.
function color(v) {
    if (typeof v !== "string") return ""
    if (/^#([0-9a-f]{6}|[0-9a-f]{8})$/i.test(v)) return v
    var m = v.match(/^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*([\d.]+)\s*)?\)$/)
    if (!m) return ""
    var hex = n => ("0" + Math.max(0, Math.min(255, Math.round(n))).toString(16)).slice(-2)
    return "#" + hex(255 * (m[4] === undefined ? 1 : Math.min(1, parseFloat(m[4])))) + hex(m[1]) + hex(m[2]) + hex(m[3])
}
function number(v, min, max) { return typeof v === "number" && isFinite(v) ? Math.max(min, Math.min(max, v)) : null }
function text(v, max) { return typeof v === "string" ? v.slice(0, max) : "" }
// An image inside the skin's folder, as a file URL; "" for anything that could leave it.
function asset(dir, rel, kinds) {
    var re = new RegExp("^[A-Za-z0-9_-]+(\\/[A-Za-z0-9_-][A-Za-z0-9_.-]*)*\\.(" + (kinds || "svg|png") + ")$")
    if (typeof rel !== "string" || !re.test(rel)) return ""
    return "file://" + encodeURI(dir + "/" + rel)
}

// "Tahoma, Arial, sans-serif" as ["Tahoma", "Arial", "sans-serif"]: family
// names only, quotes dropped, "-apple-system" and the like skipped.
function fontList(v) {
    if (typeof v !== "string") return []
    return v.split(",").map(f => f.trim().replace(/^["']|["']$/g, ""))
            .filter(f => /^[A-Za-z0-9][A-Za-z0-9 _-]{0,63}$/.test(f)).slice(0, 6)
}
var genericFonts = ["sans-serif", "serif", "monospace", "system-ui", "cursive", "fantasy"]
// The first of `list` that `installed` (Qt.fontFamilies()) holds, matched
// without regard to case; a generic family ends the search, as in CSS.
function resolveFont(list, installed, fallback) {
    var have = {}
    ;(installed || []).forEach(f => { have[String(f).toLowerCase()] = f })
    for (var i = 0; i < list.length; i++) {
        var f = list[i], lower = f.toLowerCase()
        if (genericFonts.indexOf(lower) >= 0) return lower === "system-ui" ? (fallback || "sans-serif") : lower
        if (have[lower]) return have[lower]
    }
    return fallback || "sans-serif"
}
function flag(v) { return typeof v === "boolean" ? v : null }

function oneOf(v, options) { return options.indexOf(v) >= 0 ? v : "" }

var chromeColorKeys = ["titleTop", "titleBottom", "titleText", "titleShadow", "titleInactive", "frameColor",
                       "buttonFace", "buttonGlyph", "closeFace", "closeGlyph"]
var sectionColorKeys = ["bandColor", "bandText", "bandStatus", "rule"]
var controlColorKeys = ["meterTrack", "meterFillTop", "meterFillBottom", "meterInsetDark", "meterInsetLight",
                        "meterSheen", "graphBackground", "graphGrid", "graphDown", "graphUp", "cursor",
                        "dialFace", "dialTicks", "dialLens", "needleUsage", "needleTemp", "dialDanger"]
var iconKeys = ["app", "cpu", "ram", "swap", "gpu", "netDown", "netUp", "disk", "battery", "fan", "weather",
                "clock", "ai", "process", "service", "settings"]

// `chrome`: the window the skin's operating system would draw. The style
// picks a built-in renderer; the rest tunes it.
function parseChrome(ch, dir) {
    ch = ch && typeof ch === "object" ? ch : {}
    var style = oneOf(ch.style, ["luna", "aqua", "aero", "material", "terminal", "kiroshi", "hud", "plain"])
    return {
        style: style,                                                              // "": the Guide's own title bar
        buttons: oneOf(ch.buttons, ["luna", "traffic", "aero", "material", "terminal", "kiroshi", "hud"]) || style,   // hud: flat ≡ – ✕ in the accent
        titleAlign: oneOf(ch.titleAlign, ["left", "center"]) || (style === "aqua" ? "center" : "left"),
        titleHeight: number(ch.titleHeight, 18, 48),
        topRadius: number(ch.topRadius, 0, 24),
        bottomRadius: number(ch.bottomRadius, 0, 24),
        frameWidth: number(ch.frameWidth, 0, 6),
        titleBold: ch.titleBold !== false,
        logo: asset(dir, ch.logo),                                                 // the mark at the title's end
        badge: asset(dir, ch.badge),                                               // hud: a brand badge before the title
        subtitle: text(ch.subtitle, 40),                                           // a second, muted line under the title
        colors: colorMap(ch, chromeColorKeys)
    }
}
// `sections`: how a panel's title sits. "card" is a card with its title
// inside; "groupband" is a Win32 group: a flat band, the title in bold caps
// with a status to the right, a hairline rule under it; "gadget" is a Vista
// Sidebar gadget: a glass panel with a gloss over its top, the title in white
// caps with a shadow, a settings gear and a close box at the top right.
function parseSections(s, dir) {
    s = s && typeof s === "object" ? s : {}
    // "flagtab": a solid accent flag with a 45° right edge holding the
    // section's number and title ("1 — WEATHER"), the fold toggle as an
    // angled pill at the right; `flagMark` is drawn in the flag.
    return { style: oneOf(s.style, ["card", "groupband", "gadget", "flagtab"]) || "card",
             numbered: s.numbered === true,                                        // "1 — WEATHER": the card's place before its title
             flagMark: asset(dir, s.flagMark),
             lights: oneOf(s.lights, ["traffic"]),                                 // card: red, amber, green dots before the title
             toggle: oneOf(s.toggle, ["angled", "glass", "box"]),                  // the fold toggle [ + ] at the top right; flagtab: angled

             screws: s.screws === true,                                            // a mounting screw in each corner
             tints: colorMap(s.tints, ["cpu", "gpu", "memory", "network", "disk", "weather"]),   // a card's own surface
             gear: asset(dir, s.gear),                                             // gadget: the settings button's icon
             close: asset(dir, s.close),                                           // gadget: the close box
             gloss: number(s.gloss, 0, 1),                                         // gadget, card: a curved sheen over this much of the panel's top
             uppercase: s.uppercase !== false,
             titleSize: number(s.titleSize, 8, 18),
             colors: colorMap(s, sectionColorKeys) }
}
// `controls`: meters and graphs in the skin's own idiom. An empty meter
// style leaves the bar to geometry.gaugeShape.
function parseControls(c, dir) {
    c = c && typeof c === "object" ? c : {}
    return { meter: oneOf(c.meter, ["bevel", "ascii", "gadget", "angled", "slime"]),   // slime: a glass tube filling with ooze
             coreGraph: oneOf(c.coreGraph, ["multi"]),                              // multi: one jagged trace per core, a row each
             coreColors: (Array.isArray(c.coreColors) ? c.coreColors : []).slice(0, 16).map(color).filter(v => v),
             coreLabel: text(c.coreLabel, 12),                                      // "UNIT R-" → UNIT R-1, R-2, …
             meterColors: colorMap(c.meterColors, meterKeys),                       // a meter's fill by what it measures, over gaugeUsage
             meterLabel: c.meterLabel === true,                                     // "44%" at the meter's right end
             graph: oneOf(c.graph, ["taskmgr", "line"]) || "line",
             graphFill: c.graphFill !== false,
             cursor: c.cursor === true,                                             // a blinking █ after commentary
             dialRim: asset(dir, c.dialRim),                                        // analog-dial: the bezel ring art
             dialStyle: oneOf(c.dialStyle, ["round", "semicircle"]) || "round",     // semicircle: wedges green→red, a row of three (usage, speed, temp)
             thermometer: c.thermometer === true,                                   // weather: a glass thermometer beside the readout
             dialTempMax: number(c.dialTempMax, 40, 150) || 100,                    // °C at the temperature dial's end
             dialDangerFrom: number(c.dialDangerFrom, 30, 150),                     // °C where its red zone starts
             colors: colorMap(c, controlColorKeys) }
}
var meterKeys = ["cpu", "gpu", "memory", "swap", "disk", "battery"]
// `art`: a hero illustration a card shows in its free corner (the CPU and
// GPU cards, the weather pane), in place of nothing.
var artKeys = ["cpu", "gpu", "memory", "network", "disk", "weather"]
function parseArt(a, dir) {
    var out = {}
    a = a && typeof a === "object" ? a : {}
    artKeys.forEach(k => { var v = asset(dir, a[k]); if (v) out[k] = v })
    return out
}
function parseIcons(ic, dir) {
    var out = {}
    ic = ic && typeof ic === "object" ? ic : {}
    iconKeys.forEach(k => { var v = asset(dir, ic[k]); if (v) out[k] = v })
    return out
}
// The skin's `geometry` block: the shape of cards, pills, gauges and
// buttons, their border and shadow. Anything missing or malformed is ""
// or null and SubEthaTheme falls back to the skin's older colour tokens
// (borderRadius, frame.chamfer, gaugeStyle, shadowOffset), then the Guide's.
function parseGeometry(g) {
    g = g && typeof g === "object" ? g : {}
    var offset = Array.isArray(g.shadowOffset) ? g.shadowOffset : []
    var shapes = ["rounded", "chamfer", "sharp", "stadium"]
    return {
        cardShape: oneOf(g.cardShape === "custom" ? "" : g.cardShape, shapes),   // "custom": the skin's frame decides
        pillShape: oneOf(g.pillShape, shapes),
        gaugeShape: oneOf(g.gaugeShape, ["flat", "stadium", "segmented", "chamfer", "wavy", "analog-dial"]),   // analog-dial: a round meter beside the figures, the bar in controls.meter
        cornerRadius: number(g.cornerRadius, 0, 40),
        pillRadius: number(g.pillRadius, 0, 40),
        chamferCut: number(g.chamferCut, 0, 24),
        pillChamferCut: number(g.pillChamferCut, 0, 16),
        // which corners a chamfer cuts: "tl", "tr", "br", "bl" (default: top-right and bottom-left)
        chamferCorners: (Array.isArray(g.chamferCorners) ? g.chamferCorners : []).filter(c => ["tl", "tr", "br", "bl"].indexOf(c) >= 0),
        segments: number(g.segments, 4, 40),                    // blocks in a segmented bar; default: the bar decides
        borderStyle: oneOf(g.borderStyle, ["solid", "dashed", "tech-brackets", "double"]),
        borderWidth: number(g.borderWidth, 0, 6),
        hasCornerBrackets: typeof g.hasCornerBrackets === "boolean" ? g.hasCornerBrackets : null,
        hasDropShadow: typeof g.hasDropShadow === "boolean" ? g.hasDropShadow : null,
        shadowType: oneOf(g.shadowType, ["flat-2d", "glow", "soft", "none"]),
        shadowOffset: [number(offset[0], -8, 8), number(offset[1], -8, 8)],
        shadowBlur: number(g.shadowBlur, 0, 32)                // px
    }
}

// The 2.0.0 names of colour keys that predate them.
var colorAliases = { gaugeUsage: "gaugeFillUsage", gaugeTemp: "gaugeFillTemp" }
function colorMap(c, keys) {
    var out = {}
    c = c || {}
    Object.keys(colorAliases).forEach(k => { var v = color(c[k]); if (v && keys.indexOf(colorAliases[k]) >= 0) out[colorAliases[k]] = v })
    keys.forEach(k => { var v = color(c[k]); if (v) out[k] = v })
    return out
}
// One of `variants.light` / `variants.dark`: colours (the `colors` keys,
// laid over them), the badge's, and the frame's and ground line's
// colours. The Guide's light / dark / Solar Auto setting picks one.
function parseVariant(v, dir) {
    if (!v || typeof v !== "object") return null
    var frame = v.frame || {}
    return {
        colors: colorMap(v.colors || v, colorKeys),       // nested under "colors" or flat
        badgeColor: color(v.badgeColor) || color(v.badgeBackground) || color((v.colors || {}).badgeBackground),
        badgeTextColor: color(v.badgeTextColor) || color(v.badgeText) || color((v.colors || {}).badgeText),
        frame: Object.assign(colorMap(frame, frameColorKeys),
                             Array.isArray(frame.buttons) ? { buttons: frame.buttons.slice(0, 4).map(color).filter(b => b) } : {},
                             Array.isArray(frame.hazard) ? { hazard: frame.hazard.slice(0, 2).map(color).filter(b => b) } : {},
                             frame.button && color(frame.button.color) ? { buttonColor: color(frame.button.color) } : {}),
        ground: colorMap(v.ground, ["color", "alertColor"]),
        chrome: colorMap(v.chrome, chromeColorKeys),
        sections: colorMap(v.sections, sectionColorKeys),
        tints: colorMap((v.sections || {}).tints, ["cpu", "gpu", "memory", "network", "disk", "weather"]),
        art: parseArt(v.art, dir),                       // this variant's own hero art, over the skin's
        icons: parseIcons(v.icons, dir),                 // and icons (a moon by night, a sun by day)
        name: text(v.variantName, 40),
        controls: colorMap(v.controls, controlColorKeys),
        meterColors: colorMap((v.controls || {}).meterColors, meterKeys)   // over controls.meterColors
    }
}

function parseStyle(json, dir) {
    var c = json.colors || {}
    var colors = colorMap(c, colorKeys)
    var story2 = json.narrative && typeof json.narrative === "object" ? json.narrative : {}
    var quips = {}
    quipKeys.forEach(k => { var v = text((story2.quips || {})[k], 160) || text((json.commentaryTemplates || {})[k], 160); if (v) quips[k] = v })
    var lexicon = {}
    var words = story2.lexicon && typeof story2.lexicon === "object" ? story2.lexicon : {}
    Object.keys(words).slice(0, 64).forEach(k => { var v = text(words[k], 80); if (/^[A-Za-z][A-Za-z0-9]{0,31}$/.test(k) && v) lexicon[k] = v })
    var feats = json.features && typeof json.features === "object" ? json.features : {}
    var clockQuips = {}
    ;["nominal", "stress"].forEach(k => { var v = text((json.clockQuips || {})[k], 120); if (v) clockQuips[k] = v })
    // `narrativeAssets`: a short form of the badge, the walkers and the
    // storm's falling hazards. The long forms (badgeText, roamers) win.
    var story = json.narrativeAssets && typeof json.narrativeAssets === "object" ? json.narrativeAssets : {}
    var walkers = Array.isArray(json.roamers) ? json.roamers
                : story2.roamerPrimary ? [story2.roamerPrimary, story2.roamerSecondary].filter(f => f).map((f, i) => ({ frames: [f], follow: i ? 10 : 0 }))
                : ["primaryRoamer", "secondaryRoamer"].filter(k => story[k]).map((k, i) => ({ frames: [story[k]], follow: i ? 10 : 0 }))
    var variants = json.variants && typeof json.variants === "object" ? json.variants : {}
    var frame = json.frame || {}
    var faces = {}
    ;["idle", "happy", "stressed"].forEach(k => { var v = asset(dir, (json.faces || {})[k]); if (v) faces[k] = v })
    var offset = Array.isArray(c.shadowOffset) ? c.shadowOffset : []
    return {
        isDark: typeof json.isDark === "boolean" ? json.isDark : null,     // ignored when there are variants
        variants: parseVariant(variants.light, dir) && parseVariant(variants.dark, dir)
                  ? { light: parseVariant(variants.light, dir), dark: parseVariant(variants.dark, dir) } : null,
        clockQuips: clockQuips,
        aiQuip: text(json.aiQuip, 120),
        // tumbling down the weather hero in rain and thunder, in place of the whale and the petunias
        hazards: [asset(dir, story2.weatherSkyHazard || story.fallingSkyHazard),
                  asset(dir, story2.weatherSkyHazardSecondary || story.hazardSecondary)].filter(v => v),
        font: fontList(json.fontFamily)[0] || "",                 // the first named; the theme resolves `fonts`
        fonts: fontList(json.fontFamily),
        monoFonts: fontList(json.monoFontFamily),                 // tables and figures; default: the skin's font
        fontFiles: (Array.isArray(json.fonts) ? json.fonts : []).slice(0, 4).map(f => asset(dir, f, "ttf|otf")).filter(v => v),
        features: {
            crtScanlines: flag(feats.enableCrtScanlines),
            phosphorDecay: flag(feats.enablePhosphorDecay),
            cornerBrackets: flag(feats.enableCornerBrackets),
            glassBlur: flag(feats.enableGlassBlur),
            grid: flag(feats.enableGrid),
            barrel: flag(feats.enableBarrel),
            texture: oneOf(feats.texture, ["carbon", "brushed", "noise"]),
            cartoonOutlines: flag(feats.enableCartoonOutlines),      // thick ink outlines on every part, flat offset shadows
            portalSpinners: flag(feats.enablePortalSpinners),        // frame.portal art turns slowly
            slimeDrips: flag(feats.enableSlimeDrips)                 // ooze hangs off the top and bottom edges
        },
        chrome: parseChrome(json.chrome, dir),
        sections: parseSections(json.sections, dir),
        controls: parseControls(json.controls, dir),
        icons: parseIcons(json.icons, dir),
        art: parseArt(json.art, dir),
        // `footer`: a mark and a tracked line along the bottom (the widget's foot, the window's status line)
        footer: json.footer && typeof json.footer === "object"
                ? { mark: asset(dir, json.footer.mark), label: text(json.footer.label, 40), motto: text(json.footer.motto, 80),
                    endMark: asset(dir, json.footer.endMark) } : null,         // a second mark at the far end
        // `narrative.vignettes`: a character in a card's corner with a speech bubble
        vignettes: (Array.isArray(story2.vignettes) ? story2.vignettes : []).slice(0, 6).map(v => ({
            at: oneOf((v || {}).at, ["cpu", "gpu", "weather", "memory", "footer"]),
            art: asset(dir, (v || {}).art),
            text: text((v || {}).text, 80)
        })).filter(v => v.at && v.art),
        lexicon: lexicon,
        colors: colors,
        borderWidth: number(c.borderWidth, 0, 6),
        borderRadius: number(c.borderRadius, 0, 40),
        shadowOffset: [number(offset[0], -8, 8), number(offset[1], -8, 8)],
        shadowBlur: number(c.shadowBlur, 0, 1),
        gaugeStyle: ["slot", "tube"].indexOf(c.gaugeStyle) >= 0 ? c.gaugeStyle : "blocks",
        gaugeEdgeWidth: number(c.gaugeEdgeWidth, 0, 4),
        geometry: parseGeometry(json.geometry),
        tempPulseC: number(c.tempPulseC, 30, 120),
        sparklineStyle: c.sparklineStyle === "stepped" ? "stepped" : "line",
        sparklineWidth: number(c.sparklineWidth, 0.5, 4),
        sparklineDangerAbove: number(c.sparklineDangerAbove, 0, 1),
        sparklineHotAbove: number(c.sparklineHotAbove, 0, 1),
        badgeText: text(story2.badgeLabel, 40) || text(json.badgeText, 40) || text(story.badgeText, 40),
        badgeColor: color(json.badgeColor) || color(story.badgeColor),
        badgeTextColor: color(json.badgeTextColor),
        quips: quips,
        frame: frame.style === "candy" ? {
            style: "candy",                                       // a pastel candy box: wavy ink border, sweets along the edges
            decorations: asset(dir, frame.decorations),           // tiled along the left, top and bottom edges
            hudLeft: asset(dir, frame.hudLeft),                   // button art at the marquee's left end
            hudRight: asset(dir, frame.hudRight),                 // …and its right end
            plaqueTitle: text(frame.plaqueTitle, 48),
            plaqueSubtitle: text(frame.plaqueSubtitle, 80),
            plaque: color(frame.plaque), plaqueText: color(frame.plaqueText), plaqueSubtext: color(frame.plaqueSubtext),
            rim: color(frame.rim)                                 // the frame's pastel body
        } : frame.style === "scrap" ? {
            style: "scrap",                                       // cobbled garage plating: rivets, welded seams
            portal: asset(dir, frame.portal),                     // spun on both sides of the marquee title
            toolbelt: asset(dir, frame.toolbelt),                 // the workbench rail along the bottom
            plaqueTitle: text(frame.plaqueTitle, 48),
            plaqueSubtitle: text(frame.plaqueSubtitle, 120),
            plaque: color(frame.plaque), plaqueText: color(frame.plaqueText), plaqueSubtext: color(frame.plaqueSubtext),
            slime: color(frame.slime), rivets: color(frame.rivets)
        } : frame.style === "console" ? {
            style: "console",                                     // a cartoon lab mainframe around the widget / window
            tubes: asset(dir, frame.tubes),                       // art on the top rail, left and right
            siren: asset(dir, frame.siren),                       // top centre; flashes on a critical reading
            plaqueTitle: text(frame.plaqueTitle, 32),             // the bevelled name plate
            plaqueSubtitle: text(frame.plaqueSubtitle, 32),
            pillars: frame.pillars !== false,                     // side wings of switches, buttons and bulbs
            rail: frame.rail !== false,                           // the bottom conduit of LED segments
            plaque: color(frame.plaque), plaqueText: color(frame.plaqueText), plaqueSubtext: color(frame.plaqueSubtext)
        } : frame.style === "handheld" ? {
            style: "handheld",
            dpad: color(frame.dpad),
            buttons: (Array.isArray(frame.buttons) ? frame.buttons : []).slice(0, 4).map(color).filter(v => v),
            vents: number(frame.vents, 0, 6)
        } : frame.style === "bezel" ? {
            style: "bezel",
            chamfer: number(frame.chamfer, 0, 24) || 0,           // 45° cuts, top-right and bottom-left
            brackets: color(frame.brackets),                      // L corner brackets on every frame
            ticks: frame.ticks === true,                          // calibration ticks down the left edge
            slash: color(frame.slash),                            // 45° accent tab over the top-right corner
            logo: asset(dir, frame.logo),                         // beside the Guide's title
            alertIcon: asset(dir, frame.alertIcon),               // blinks on a critical reading
            watermark: text(frame.watermark, 60),
            mark: asset(dir, frame.mark),                         // a small icon before the watermark
            watermarkColor: color(frame.watermarkColor),
            scanlines: number(frame.scanlines, 0, 0.5),
            glitch: frame.glitch === true,
            hazard: Array.isArray(frame.hazard) ? frame.hazard.slice(0, 2).map(color).filter(v => v) : [],   // stripe colours along the top rail
            rivets: color(frame.rivets),                          // bolts in the four corners
            button: frame.button ? { text: text(frame.button.text, 20), color: color(frame.button.color) } : null,
            dials: color(frame.dials)                             // two analog meters (load, heat); the needle colour
        } : null,
        labels: {
            rx: text((json.labels || {}).rx, 24), tx: text((json.labels || {}).tx, 24),
            lan: text((json.labels || {}).lan, 32), wan: text((json.labels || {}).wan, 32),
            lanTag: text((json.labels || {}).lanTag, 16), wanTag: text((json.labels || {}).wanTag, 16)
        },
        netGlyph: json.netGlyph === "chevron" ? "chevron" : "arrow",
        ground: json.ground ? {
            color: color(json.ground.color),
            alertColor: color(json.ground.alertColor),
            width: number(json.ground.width, 0.5, 4) || 1.5,
            ledge: json.ground.ledge === true,                    // a drop shadow under the line
            pulses: json.ground.pulses === true                   // dots trailing the walkers
        } : null,
        faces: faces,
        roamers: walkers.slice(0, 3).map(r => ({
            name: text(r.name, 24),
            frames: (Array.isArray(r.frames) ? r.frames : []).slice(0, 8).map(f => asset(dir, f)).filter(v => v),
            idleFrame: asset(dir, r.idleFrame),
            vaultFrame: asset(dir, r.vaultFrame),                 // now and then mid-stride, with a hop
            alertFrame: asset(dir, r.alertFrame),                 // during havoc (hover or a load spike)
            havoc: r.havoc === true,                              // this one hops forward to cause it
            width: number(r.width, 8, 64) || 24,
            height: number(r.height, 8, 64) || 32,
            follow: number(r.follow, 0, 80) || 0,
            stride: number(r.stride, 2, 40) || 7,
            bob: r.bob === true,
            stretch: r.stretch === true,
            notes: r.notes === true,
            waves: r.waves === true
        })).filter(r => r.frames.length > 0)
    }
}

// An installed skin's entry: { id, name, author, version, description, dir, style }.
function entry(id, dir, json) {
    return { id: id, name: text(json.name, 80) || id,
             author: text(json.author, 80), version: text(json.version, 24) || "0",
             description: text(json.description, 400), dir: dir,
             style: parseStyle(json, dir) }
}
