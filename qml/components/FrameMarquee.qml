import QtQuick
import QtQuick.Effects
import "."

// The name plate a skin's built frame shows across the window's top, under
// the title bar: a dark bevelled plaque (frame.plaque) with the plaqueTitle
// in bold lettering and a plaqueSubtitle line, flanked by the frame's own
// art. Shared by the frame styles that have one:
//   "console"  frame.tubes art at both ends, frame.siren above the plaque,
//              flashing while any reading is critical
//   "scrap"    frame.portal art at both ends, turning while
//              features.portalSpinners; the title's soft neon bloom; ooze
//              hanging from the plaque when features.slimeDrips
//   "candy"    frame.hudLeft / hudRight button art at the ends; bubbly title
Item {
    id: marquee

    readonly property var f: Theme.frame || ({})
    readonly property string style: Theme.frameStyle
    readonly property bool critical: Math.max(Alerts.cpuLevel, Alerts.gpuLevel, Alerts.ram, Alerts.disks) === 2
    readonly property real outline: Theme.cartoon ? 3 : 2
    readonly property string sideArt: style === "console" ? (f.tubes || "") : style === "scrap" ? (f.portal || "") : ""

    visible: ["console", "scrap", "candy"].indexOf(style) >= 0
    implicitHeight: visible ? (style === "console" && f.siren ? 78 : 62) : 0

    // ---- the ends ----
    component EndArt: Image {
        property bool mirrored: false
        height: marquee.height - 10
        width: height * implicitWidth / Math.max(1, implicitHeight)
        anchors.verticalCenter: plaque.verticalCenter
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        mirror: mirrored
        RotationAnimation on rotation {
            running: marquee.style === "scrap" && Theme.portalSpin && marquee.visible
            from: 0; to: mirrored ? -360 : 360; duration: 14000; loops: Animation.Infinite
        }
    }
    EndArt {
        visible: source != ""
        anchors { right: plaque.left; rightMargin: 12 }
        source: marquee.style === "candy" ? (marquee.f.hudLeft || "") : marquee.sideArt
    }
    EndArt {
        visible: source != ""
        anchors { left: plaque.right; leftMargin: 12 }
        mirrored: marquee.style !== "candy"
        source: marquee.style === "candy" ? (marquee.f.hudRight || "") : marquee.sideArt
    }

    // ---- the console's siren ----
    Image {
        id: siren
        visible: marquee.style === "console" && source != ""
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 2 }
        height: 20
        width: height * implicitWidth / Math.max(1, implicitHeight)
        source: marquee.f.siren || ""
        sourceSize.height: 40
        opacity: marquee.critical ? level : 0.55
        property real level: 1
        SequentialAnimation on level {
            running: marquee.critical && marquee.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 260 }
            NumberAnimation { to: 1; duration: 260 }
        }
        layer.enabled: marquee.critical
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#FF2A2A"; shadowBlur: 1.0; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
    }

    // ---- the plaque ----
    Rectangle {
        id: plaque
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
        width: Math.min(parent.width * 0.6, Math.max(title.implicitWidth, sub.implicitWidth) + 48)
        height: 50
        radius: marquee.style === "candy" ? 14 : marquee.style === "scrap" ? 18 : 6
        color: marquee.f.plaque || "#22262B"
        border { width: marquee.outline; color: Theme.border }
        Rectangle {   // the bevel: a lit top edge, a shaded bottom one
            anchors { fill: parent; margins: marquee.outline }
            radius: Math.max(0, parent.radius - marquee.outline)
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.22) }
                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 0.8; color: Qt.rgba(0, 0, 0, 0.0) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.3) }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 1
            Text {
                id: title
                anchors.horizontalCenter: parent.horizontalCenter
                text: marquee.f.plaqueTitle || ""
                color: marquee.f.plaqueText || "#FFFFFF"
                style: marquee.style === "scrap" ? Text.Normal : Text.Raised      // a lettered, slightly 3D look
                styleColor: Qt.darker(color, 2.2)
                font { family: Theme.sans; pixelSize: 20; weight: Font.Black; letterSpacing: marquee.style === "candy" ? 1 : 2 }
                layer.enabled: marquee.style === "scrap"
                layer.effect: MultiEffect {   // the neon bloom
                    shadowEnabled: true
                    shadowColor: title.color
                    shadowBlur: 0.8
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    shadowOpacity: 0.9
                }
            }
            Text {
                id: sub
                visible: text !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: marquee.f.plaqueSubtitle || ""
                color: marquee.f.plaqueSubtext || Qt.rgba(1, 1, 1, 0.7)
                font { family: Theme.sans; pixelSize: 9; bold: true; letterSpacing: 1 }
            }
        }
        SlimeDrips {   // ooze hanging from the plaque
            anchors { left: parent.left; right: parent.right; top: parent.bottom; leftMargin: parent.radius; rightMargin: parent.radius; topMargin: -marquee.outline }
        }
    }
}
