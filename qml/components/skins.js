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

var colorKeys = ["background", "cardBackground", "cardBackgroundHover", "textPrimary", "textSecondary",
                 "accent", "accentSecondary", "accentTertiary", "accentGood", "border", "shadowColor",
                 "gaugeTrack", "gaugeFillUsage", "gaugeFillTemp", "sparkline", "sparklineFill",
                 "netDown", "netUp", "gaugeFillEdge", "sparklineDanger", "sparklineHot", "commentary"]
var quipKeys = ["nominal", "moderate", "highLoad", "critical", "night"]
var frameColorKeys = ["dpad", "brackets", "slash", "watermarkColor", "rivets", "dials"]

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
function asset(dir, rel) {
    if (typeof rel !== "string" || !/^[A-Za-z0-9_-]+(\/[A-Za-z0-9_-][A-Za-z0-9_.-]*)*\.(svg|png)$/.test(rel)) return ""
    return "file://" + encodeURI(dir + "/" + rel)
}

function oneOf(v, options) { return options.indexOf(v) >= 0 ? v : "" }
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
        gaugeShape: oneOf(g.gaugeShape, ["flat", "stadium", "segmented", "chamfer"]),
        cornerRadius: number(g.cornerRadius, 0, 40),
        pillRadius: number(g.pillRadius, 0, 40),
        chamferCut: number(g.chamferCut, 0, 24),
        pillChamferCut: number(g.pillChamferCut, 0, 16),
        borderStyle: oneOf(g.borderStyle, ["solid", "dashed", "tech-brackets", "double"]),
        borderWidth: number(g.borderWidth, 0, 6),
        hasCornerBrackets: typeof g.hasCornerBrackets === "boolean" ? g.hasCornerBrackets : null,
        hasDropShadow: typeof g.hasDropShadow === "boolean" ? g.hasDropShadow : null,
        shadowType: oneOf(g.shadowType, ["flat-2d", "glow", "soft", "none"]),
        shadowOffset: [number(offset[0], -8, 8), number(offset[1], -8, 8)],
        shadowBlur: number(g.shadowBlur, 0, 32)                // px
    }
}

function colorMap(c, keys) {
    var out = {}
    keys.forEach(k => { var v = color((c || {})[k]); if (v) out[k] = v })
    return out
}
// One of `variants.light` / `variants.dark`: colours (the `colors` keys,
// laid over them), the badge's, and the frame's and ground line's
// colours. The Guide's light / dark / Solar Auto setting picks one.
function parseVariant(v) {
    if (!v || typeof v !== "object") return null
    var frame = v.frame || {}
    return {
        colors: colorMap(v.colors || v, colorKeys),       // nested under "colors" or flat
        badgeColor: color(v.badgeColor),
        badgeTextColor: color(v.badgeTextColor),
        frame: Object.assign(colorMap(frame, frameColorKeys),
                             Array.isArray(frame.buttons) ? { buttons: frame.buttons.slice(0, 4).map(color).filter(b => b) } : {},
                             Array.isArray(frame.hazard) ? { hazard: frame.hazard.slice(0, 2).map(color).filter(b => b) } : {},
                             frame.button && color(frame.button.color) ? { buttonColor: color(frame.button.color) } : {}),
        ground: colorMap(v.ground, ["color", "alertColor"])
    }
}

function parseStyle(json, dir) {
    var c = json.colors || {}
    var colors = colorMap(c, colorKeys)
    var quips = {}
    quipKeys.forEach(k => { var v = text((json.commentaryTemplates || {})[k], 160); if (v) quips[k] = v })
    var clockQuips = {}
    ;["nominal", "stress"].forEach(k => { var v = text((json.clockQuips || {})[k], 120); if (v) clockQuips[k] = v })
    // `narrativeAssets`: a short form of the badge, the walkers and the
    // storm's falling hazards. The long forms (badgeText, roamers) win.
    var story = json.narrativeAssets && typeof json.narrativeAssets === "object" ? json.narrativeAssets : {}
    var walkers = Array.isArray(json.roamers) ? json.roamers
                : ["primaryRoamer", "secondaryRoamer"].filter(k => story[k]).map((k, i) => ({ frames: [story[k]], follow: i ? 10 : 0 }))
    var variants = json.variants && typeof json.variants === "object" ? json.variants : {}
    var frame = json.frame || {}
    var faces = {}
    ;["idle", "happy", "stressed"].forEach(k => { var v = asset(dir, (json.faces || {})[k]); if (v) faces[k] = v })
    var offset = Array.isArray(c.shadowOffset) ? c.shadowOffset : []
    return {
        isDark: typeof json.isDark === "boolean" ? json.isDark : null,     // ignored when there are variants
        variants: parseVariant(variants.light) && parseVariant(variants.dark)
                  ? { light: parseVariant(variants.light), dark: parseVariant(variants.dark) } : null,
        clockQuips: clockQuips,
        aiQuip: text(json.aiQuip, 120),
        // tumbling down the weather hero in rain and thunder, in place of the whale and the petunias
        hazards: [asset(dir, story.fallingSkyHazard), asset(dir, story.hazardSecondary)].filter(v => v),
        font: /^[A-Za-z0-9 _-]{1,64}$/.test(json.fontFamily || "") ? json.fontFamily : "",
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
        badgeText: text(json.badgeText, 40) || text(story.badgeText, 40),
        badgeColor: color(json.badgeColor) || color(story.badgeColor),
        badgeTextColor: color(json.badgeTextColor),
        quips: quips,
        frame: frame.style === "handheld" ? {
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
