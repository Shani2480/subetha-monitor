import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Shapes
import "."

// A card on the Guide's page: cream paper with a hard 2px charcoal shadow, or
// CRT black with a glowing phosphor rule and amber L-shaped reticles in the
// corners; under a skin, its card shape, border, brackets and shadow
// (ThemeShapeContainer). An optional title row (title, subtitle, `header` items on the
// right) sits over the content, which stacks in a column. A card that
// tracks alerts (`alertTracked`) shows a SeverityBadge before its title, and
// at a warning or critical `alertLevel` an AlertGlowContainer haloes it.
// `icon` names the skin's icon for it (Theme.icons), shown before the title.
// Under a skin with sections.style "groupband" the card is a Win32 group: a
// flat band across its top holding the title in bold capitals and `status`
// to the right, a hairline rule under the band. Under "gadget" it is a Vista
// Sidebar gadget: a glass panel with a curved gloss over its top, the title
// in white capitals with a black shadow, a gear (Settings) and a close box
// (which folds the card to its title) at the top right. Under a glass skin
// (features.enableGlassBlur) the card is a translucent pane with a rim.
// `section` (cpu, gpu, memory, network, disk) picks the skin's own pieces for
// the card: its tint (sections.tints), its hero illustration (art), shown at
// the title row's right, and a character with a speech bubble (vignettes) in
// its bottom-right corner. sections.screws puts a screw in each corner.
Item {
    id: card

    property string title: ""
    property string subtitle: ""
    property string status: ""            // right of the title, in regular weight
    property string icon: ""              // a key of Theme.icons
    property bool collapsed: false        // a gadget folded by its close box
    property string section: ""           // cpu, gpu, memory, network, disk
    // the card's surface and text that reads on it (a tint may be darker than the skin's text expects)
    readonly property color face: section ? Theme.tintOf(section) : Theme.card
    function readable(c) {
        if (!section || Theme.contrast(c, face) >= 4.5) return c
        var white = Qt.rgba(1, 1, 1, 1), black = Qt.rgba(0, 0, 0, 1)
        return Theme.contrast(white, face) >= Theme.contrast(black, face) ? white : black
    }
    readonly property bool glass: Theme.fx.glassBlur || Theme.gadgets
    property real padding: 16
    property bool reticles: true
    property bool alertTracked: false     // show the severity badge, a dot while nominal
    property int alertLevel: 0            // 0 nominal, 1 warning, 2 critical
    property string alertFigure: ""       // the reading in [CRITICAL: ...]
    property bool live: true              // on screen: gates the halo's breathing and the badge's blink
    property color borderColor: Theme.skinned ? Theme.border : Theme.dark ? Theme.tint(0.55) : Theme.ink
    default property alias content: body.data
    property alias header: headerSlot.data
    property alias spacing: body.spacing

    implicitWidth: column.implicitWidth + padding * 2 + 2
    implicitHeight: column.implicitHeight + padding * 2 + 2

    // a Sidebar gadget's small bevelled button: the skin's art, or drawn
    component GadgetKnob: Rectangle {
        id: knob
        property string art: ""
        property string tip: ""
        property bool red: false
        signal clicked()
        width: 15; height: 15
        radius: 3
        color: art !== "" ? "transparent" : red ? "#C8442E" : Qt.rgba(1, 1, 1, 0.18)
        border { width: art !== "" ? 0 : 1; color: Qt.rgba(0, 0, 0, 0.5) }
        opacity: knobArea.containsMouse ? 1 : 0.85
        Image { anchors.fill: parent; visible: knob.art !== ""; source: knob.art; sourceSize: Qt.size(30, 30) }
        MouseArea {
            id: knobArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: knob.clicked()
            ToolTip.visible: containsMouse && knob.tip !== ""
            ToolTip.delay: 500
            ToolTip.text: knob.tip
        }
    }

    AlertGlowContainer {
        anchors.fill: parent
        alertLevel: card.alertLevel
        animate: Alerts.motion && card.live
    }

    ThemeShapeContainer {
        id: shaped
        visible: Theme.skinned
        anchors.fill: parent
        fillColor: card.glass ? Theme.withAlpha(Theme.card, Theme.gadgets ? 0.82 : 0.72) : card.section ? Theme.tintOf(card.section) : Theme.card
        strokeColor: card.borderColor
        cornerBrackets: card.reticles && Theme.cornerBrackets
    }

    Rectangle {   // flat offset shadow (light)
        visible: Theme.flatShadow && !Theme.skinned
        x: 2; y: 2
        width: surface.width; height: surface.height
        radius: surface.radius
        color: Theme.ink
    }

    Rectangle {
        id: surface
        // The content's frame; under a skin only that, the shape drawn above.
        anchors {
            fill: parent
            rightMargin: Theme.skinned ? Math.max(0, shaped.shadowOffsetX) : 2
            bottomMargin: Theme.skinned ? Math.max(0, shaped.shadowOffsetY) : 2
            leftMargin: Theme.skinned ? Math.max(0, -shaped.shadowOffsetX) : 0
            topMargin: Theme.skinned ? Math.max(0, -shaped.shadowOffsetY) : 0
        }
        radius: Theme.outerRadius
        color: Theme.skinned ? "transparent" : Theme.card
        border.width: Theme.skinned ? 0 : Theme.line
        border.color: card.borderColor

        Rectangle {   // phosphor glow: a soft second rule outside the first
            visible: Theme.dark && !Theme.skinned
            anchors { fill: parent; margins: -3 }
            radius: parent.radius + 3
            color: "transparent"
            border.width: 3
            border.color: Theme.withAlpha(Theme.phosphor, 0.06)
        }

        Repeater {   // L-shaped reticles
            model: card.reticles && !Theme.skinned ? 4 : 0
            Item {
                required property int index
                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index >= 2
                readonly property real inset: Theme.dark ? 5 : 9   // clear of the film's round corners
                width: 10; height: 10
                x: atRight ? surface.width - width - inset : inset
                y: atBottom ? surface.height - height - inset : inset
                Rectangle { width: parent.width; height: 1.5; y: parent.atBottom ? parent.height - height : 0; color: Theme.reticle }
                Rectangle { width: 1.5; height: parent.height; x: parent.atRight ? parent.width - width : 0; color: Theme.reticle }
            }
        }
    }

    Item {   // glass: a specular rim along the top; a gadget's curved gloss
        visible: card.glass
        anchors.fill: surface
        Rectangle {
            visible: !Theme.gadgets
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 1
                      leftMargin: Theme.outerRadius; rightMargin: Theme.outerRadius }
            height: 1
            color: Qt.rgba(1, 1, 1, Theme.dark ? 0.28 : 0.75)
        }
        Shape {
            id: gloss
            visible: Theme.gadgets
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real r: Math.min(Theme.outerRadius, height / 2)
            readonly property real g: height * (Theme.sections.gloss ?? 0.45)
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: gloss.g
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.32) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.02) }
                }
                startX: gloss.r; startY: 1
                PathLine { x: card.width - gloss.r - 2; y: 1 }
                PathQuad { x: card.width - 3; y: gloss.r + 1; controlX: card.width - 3; controlY: 1 }
                PathLine { x: card.width - 3; y: gloss.g * 0.55 }
                PathQuad { x: 1; y: gloss.g; controlX: card.width * 0.55; controlY: gloss.g * 0.62 }
                PathLine { x: 1; y: gloss.r + 1 }
                PathQuad { x: gloss.r; y: 1; controlX: 1; controlY: 1 }
            }
        }
    }

    Rectangle {   // the Win32 group's band and the rule under it
        id: band
        visible: Theme.groupBands && titleRow.visible
        anchors { left: surface.left; right: surface.right; top: surface.top; margins: Math.max(1, Theme.borderWidth) }
        height: titleRow.height + card.padding * 0.5 + (card.padding - Math.max(1, Theme.borderWidth))
        color: Theme.sec("bandColor", Qt.darker(Theme.card, 1.04))
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.sec("rule", Theme.tint(0.2))
        }
    }

    ColumnLayout {
        id: column
        anchors { fill: surface; margins: card.padding }
        spacing: 10

        RowLayout {
            id: titleRow
            visible: card.title !== "" || headerSlot.children.length > 0
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.groupBands ? card.padding * 0.5 : 0
            spacing: 10
            Image {
                visible: source != ""
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Theme.groupBands ? 20 : 24
                Layout.preferredHeight: Layout.preferredWidth
                source: card.icon ? Theme.icon(card.icon) : ""
                sourceSize: Qt.size(48, 48)
                fillMode: Image.PreserveAspectFit
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SeverityBadge {
                        visible: card.alertTracked
                        Layout.alignment: Qt.AlignVCenter
                        level: card.alertLevel
                        figure: card.alertFigure
                        live: card.live
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (Theme.groupBands || Theme.gadgets) && Theme.sections.uppercase !== false ? card.title.toUpperCase() : card.title
                        color: Theme.groupBands ? Theme.sec("bandText", Theme.ink) : Theme.gadgets ? Theme.sec("bandText", "#FFFFFF") : card.readable(Theme.ink)
                        elide: Text.ElideRight
                        style: Theme.gadgets ? Text.Raised : Text.Normal
                        styleColor: "#000000"
                        font {
                            family: Theme.sans; bold: true
                            pixelSize: Theme.groupBands ? (Theme.sections.titleSize || 11) : 14
                            letterSpacing: Theme.groupBands ? 0 : 1.2
                        }
                    }
                    Text {
                        visible: card.status !== ""
                        text: card.status
                        color: Theme.groupBands ? Theme.sec("bandStatus", Theme.inkSoft) : Theme.inkSoft
                        font { family: Theme.sans; pixelSize: Theme.groupBands ? (Theme.sections.titleSize || 11) : 12 }
                    }
                }
                Text {
                    visible: card.subtitle !== ""
                    Layout.fillWidth: true
                    text: card.subtitle
                    color: Theme.skinned ? Theme.withAlpha(card.readable(Theme.inkSoft), 0.85) : Theme.tint(0.6)
                    elide: Text.ElideRight
                    font { family: Theme.mono; features: Theme.figures; pixelSize: 11 }
                }
            }
            Image {   // the skin's hero illustration for this card
                visible: source != ""
                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                Layout.preferredHeight: 96
                Layout.preferredWidth: Math.min(160, 96 * implicitWidth / Math.max(1, implicitHeight))
                source: card.section && Theme.art[card.section] ? Theme.art[card.section] : ""
                sourceSize.height: 192
                fillMode: Image.PreserveAspectFit
            }
            Row { id: headerSlot; spacing: 14; Layout.alignment: Qt.AlignTop | Qt.AlignRight }
            Row {   // a gadget's gear and close box
                visible: Theme.gadgets
                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                spacing: 3
                GadgetKnob {
                    art: Theme.sections.gear || ""
                    tip: "Settings"
                    onClicked: Theme.settingsRequested()
                    Text { visible: parent.art === ""; anchors.centerIn: parent; text: "⚙"; color: "#FFFFFF"; font.pixelSize: 11 }
                }
                GadgetKnob {
                    art: Theme.sections.close || ""
                    tip: card.collapsed ? "Expand" : "Collapse"
                    red: true
                    onClicked: card.collapsed = !card.collapsed
                    Text { visible: parent.art === ""; anchors.centerIn: parent; text: card.collapsed ? "+" : "✕"; color: "#FFFFFF"; font { pixelSize: 9; bold: true } }
                }
            }
        }

        ColumnLayout {
            id: body
            visible: !card.collapsed
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
        }
    }

    Repeater {   // mounting screws (sections.screws)
        model: Theme.screws ? 4 : 0
        Rectangle {
            required property int index
            width: 8; height: 8; radius: 4
            x: index % 2 ? surface.x + surface.width - width - 5 : surface.x + 5
            y: index >= 2 ? surface.y + surface.height - height - 5 : surface.y + 5
            color: Qt.lighter(Theme.border, 1.6)
            border { width: 1; color: Theme.border }
            Rectangle {   // the slot
                anchors.centerIn: parent
                width: parent.width - 2; height: 1.4
                rotation: 35 + parent.index * 50
                color: Theme.border
            }
        }
    }

    SlimeDrips {   // ooze from the card's top edge (features.slimeDrips)
        anchors { left: surface.left; right: surface.right; top: surface.top; leftMargin: 18; rightMargin: 18; topMargin: Math.max(1, Theme.borderWidth) - 1 }
        height: 14
        count: 2 + Math.min(2, Math.floor(width / 220))
    }

    CharacterVignette {   // a character and its line, bottom right
        vignette: card.section ? Theme.vignette(card.section) : null
        anchors { right: surface.right; bottom: surface.bottom; margins: 6 }
    }
}
