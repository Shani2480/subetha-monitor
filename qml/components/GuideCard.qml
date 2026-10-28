import QtQuick
import QtQuick.Layouts
import "."

// A card on the Guide's page: cream paper with a hard 2px charcoal shadow, or
// CRT black with a glowing phosphor rule and amber L-shaped reticles in the
// corners; under a skin, its card shape, border, brackets and shadow
// (ThemeShapeContainer). An optional title row (title, subtitle, `header` items on the
// right) sits over the content, which stacks in a column. A card that
// tracks alerts (`alertTracked`) shows a SeverityBadge before its title, and
// at a warning or critical `alertLevel` an AlertGlowContainer haloes it.
Item {
    id: card

    property string title: ""
    property string subtitle: ""
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

    AlertGlowContainer {
        anchors.fill: parent
        alertLevel: card.alertLevel
        animate: Alerts.motion && card.live
    }

    ThemeShapeContainer {
        id: shaped
        visible: Theme.skinned
        anchors.fill: parent
        fillColor: Theme.card
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
        border.width: Theme.skinned ? 0 : Theme.dark ? 1 : 2
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

    ColumnLayout {
        id: column
        anchors { fill: surface; margins: card.padding }
        spacing: 10

        RowLayout {
            visible: card.title !== "" || headerSlot.children.length > 0
            Layout.fillWidth: true
            spacing: 10
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
                        text: card.title
                        color: Theme.ink
                        elide: Text.ElideRight
                        font { family: Theme.sans; pixelSize: 14; bold: true; letterSpacing: 1.2 }
                    }
                }
                Text {
                    visible: card.subtitle !== ""
                    Layout.fillWidth: true
                    text: card.subtitle
                    color: Theme.skinned ? Theme.inkSoft : Theme.tint(0.6)
                    elide: Text.ElideRight
                    font { family: Theme.mono; pixelSize: 11 }
                }
            }
            Row { id: headerSlot; spacing: 14; Layout.alignment: Qt.AlignTop | Qt.AlignRight }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
        }
    }
}
