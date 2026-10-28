import QtQuick
import QtQuick.Layouts
import "."

// A card on the Guide's page: cream paper with a hard 2px charcoal shadow, or
// CRT black with a glowing phosphor rule and amber L-shaped reticles in the
// corners. An optional title row (title, subtitle, `header` items on the
// right) sits over the content, which stacks in a column.
Item {
    id: card

    property string title: ""
    property string subtitle: ""
    property real padding: 16
    property bool reticles: true
    property color borderColor: Theme.dark ? Theme.tint(0.55) : Theme.ink
    default property alias content: body.data
    property alias header: headerSlot.data
    property alias spacing: body.spacing

    implicitWidth: column.implicitWidth + padding * 2 + 2
    implicitHeight: column.implicitHeight + padding * 2 + 2

    Rectangle {   // flat offset shadow (light)
        visible: Theme.flatShadow
        x: 2; y: 2
        width: surface.width; height: surface.height
        radius: surface.radius
        color: Theme.ink
    }

    Rectangle {
        id: surface
        anchors { fill: parent; rightMargin: 2; bottomMargin: 2 }
        radius: Theme.outerRadius
        color: Theme.card
        border.width: Theme.dark ? 1 : 2
        border.color: card.borderColor

        Rectangle {   // phosphor glow: a soft second rule outside the first
            visible: Theme.dark
            anchors { fill: parent; margins: -3 }
            radius: parent.radius + 3
            color: "transparent"
            border.width: 3
            border.color: Theme.withAlpha(Theme.phosphor, 0.06)
        }

        Repeater {   // L-shaped reticles
            model: card.reticles ? 4 : 0
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
                Text {
                    Layout.fillWidth: true
                    text: card.title
                    color: Theme.ink
                    elide: Text.ElideRight
                    font { family: Theme.sans; pixelSize: 14; bold: true; letterSpacing: 1.2 }
                }
                Text {
                    visible: card.subtitle !== ""
                    Layout.fillWidth: true
                    text: card.subtitle
                    color: Theme.tint(0.6)
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
