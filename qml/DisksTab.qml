import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"

// One drawer card per mounted filesystem: capacity meter, filesystem and
// drive badges, every mount point of the device (btrfs subvolumes share one),
// and live read / write dials with their recent history.
Flickable {
    id: tab

    property bool shown: false
    readonly property var disks: telemetry.data.disks || []
    readonly property var dh: telemetry.data.diskHistory || {}

    contentWidth: width
    contentHeight: flow.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: GuideScrollBar {}

    GridLayout {
        id: flow
        width: tab.width - 10
        columns: tab.width >= 1100 ? 2 : 1
        columnSpacing: 16
        rowSpacing: 16

        Repeater {
            model: tab.disks
            GuideCard {
                id: drive
                required property var modelData
                readonly property var h: tab.dh[modelData.device] || { read: [], write: [] }
                readonly property real peak: Math.max(1048576, Math.max.apply(null, h.read.concat(h.write).concat([0])))
                readonly property int level: Alerts.loadLevel("disk", modelData.percent)
                alertTracked: true
                alertLevel: level
                alertFigure: Theme.pct(modelData.percent)
                live: tab.shown
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                title: (modelData.mount === "/" ? "ROOT" : modelData.label.toUpperCase()) + "  //  " + modelData.mount
                subtitle: modelData.device + (modelData.mounts.length > 1 ? "  ·  ALSO AT " + modelData.mounts.slice(1).join(", ") : "")
                header: [
                    Rectangle {
                        width: fsText.implicitWidth + 14; height: fsText.implicitHeight + 6
                        radius: height / 2
                        color: Theme.dark ? "transparent" : Theme.teal
                        border.width: Theme.line
                        border.color: Theme.dark ? Theme.cool : Theme.charcoal
                        Text { id: fsText; anchors.centerIn: parent; text: drive.modelData.fstype.toUpperCase()
                               color: Theme.dark ? Theme.cool : Theme.cream; font { family: Theme.mono; features: Theme.figures; pixelSize: 10; bold: true } }
                    },
                    Rectangle {
                        width: kindText.implicitWidth + 14; height: kindText.implicitHeight + 6
                        radius: height / 2
                        color: Theme.dark ? "transparent" : Theme.mustard
                        border.width: Theme.line
                        border.color: Theme.dark ? Theme.amber : Theme.charcoal
                        Text { id: kindText; anchors.centerIn: parent; text: drive.modelData.kind.toUpperCase()
                               color: Theme.dark ? Theme.amber : Theme.charcoal; font { family: Theme.mono; features: Theme.figures; pixelSize: 10; bold: true } }
                    }
                ]

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: Theme.pct(drive.modelData.percent)
                                color: Theme.levelInk(drive.level, Theme.load(drive.modelData.percent))
                                font { family: Theme.mono; features: Theme.figures; pixelSize: 34; bold: true }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 8
                                spacing: 2
                                Text {
                                    text: Theme.bytes(drive.modelData.used, 1) + " USED"
                                    color: Theme.ink
                                    font { family: Theme.mono; features: Theme.figures; pixelSize: 13; bold: true }
                                }
                                Text {
                                    text: Theme.bytes(drive.modelData.free, 1) + " FREE OF " + Theme.bytes(drive.modelData.total, 1)
                                    color: Theme.level(100 - drive.modelData.percent)
                                    font { family: Theme.mono; features: Theme.figures; pixelSize: 11; bold: true }
                                }
                            }
                        }
                        SegmentBar {
                            Layout.fillWidth: true
                            fraction: drive.modelData.percent / 100
                            fill: drive.level === 2 ? Theme.critColor : Theme.load(drive.modelData.percent)
                            segments: 32
                            segmentHeight: 14
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46
                            SparklineGraph { anchors.fill: parent; historyData: Theme.norm(drive.h.read, drive.peak); strokeColor: Theme.ink }
                            SparklineGraph { anchors.fill: parent; historyData: Theme.norm(drive.h.write, drive.peak)
                                             strokeColor: Theme.cool; fillColor: "transparent"; backdrop: false }
                        }
                        Text {
                            text: "I/O HISTORY, SCALE " + Theme.rate(drive.peak) + "  ·  " + drive.modelData.kname
                            color: Theme.tint(0.45)
                            font { family: Theme.mono; features: Theme.figures; pixelSize: 9 }
                        }
                    }
                    ArcGauge {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 104
                        label: "READ"
                        bytesPerSec: drive.modelData.read
                        tone: Theme.ink
                    }
                    ArcGauge {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 104
                        label: "WRITE"
                        bytesPerSec: drive.modelData.write
                        tone: Theme.cool
                    }
                }
            }
        }
    }
}
