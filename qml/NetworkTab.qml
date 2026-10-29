import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"

// Throughput of the active link over the last 90 seconds as a two-way
// curve, its addresses (click to copy), and a card per interface.
ColumnLayout {
    id: tab

    property bool shown: false
    readonly property var net: telemetry.data.net || {}
    readonly property var nh: telemetry.data.netHistory || {}
    readonly property real peak: Math.max(1024, Math.max.apply(null, (nh.rx || []).concat(nh.tx || []).concat([0])))
    readonly property var active: (net.interfaces || []).find(i => i.active) || {}

    spacing: 16

    GuideCard {
        Layout.fillWidth: true
        Layout.preferredHeight: 330
        title: "THROUGHPUT  //  " + (tab.net.iface || "NO ACTIVE LINK").toUpperCase()
        subtitle: "LAST " + Math.round(60 * telemetry.interval / 1000) + " S  ·  SCALE " + Theme.rate(tab.peak)
        header: [
            ReadoutLabel { label: "▼ DOWNLOAD"; value: Theme.rate(tab.net.rx); valueSize: 22 },
            ReadoutLabel { label: "▲ UPLOAD"; value: Theme.rate(tab.net.tx); valueSize: 22; valueColor: Theme.cool }
        ]

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Repeater {   // horizontal rules at quarters of the scale
                model: 5
                Rectangle {
                    required property int index
                    width: parent.width; height: 1
                    y: index * (parent.height - 1) / 4
                    color: Theme.tint(index === 2 ? 0.35 : 0.1)
                }
            }
            SparklineGraph {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: parent.height / 2
                capacity: 60
                lineWidth: 2
                historyData: Theme.norm(tab.nh.rx, tab.peak)
                strokeColor: Theme.netDown
            }
            SparklineGraph {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height / 2
                capacity: 60
                lineWidth: 2
                inverted: true
                historyData: Theme.norm(tab.nh.tx, tab.peak)
                strokeColor: Theme.netUp
            }
            Text { x: 4; y: 4; text: "▼ RX"; color: Theme.netDown; font { family: Theme.mono; features: Theme.figures; pixelSize: 10; bold: true } }
            Text { x: 4; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: "▲ TX"; color: Theme.netUp
                   font { family: Theme.mono; features: Theme.figures; pixelSize: 10; bold: true } }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 16

        GuideCard {
            Layout.preferredWidth: 420
            Layout.fillHeight: true
            title: Theme.lex("identityTitle", "SUB-ETHA IDENTITY", "ADDRESSES")
            subtitle: "CLICK AN ADDRESS TO COPY IT"
            CopyableValue { Layout.fillWidth: true; label: "LAN IPv4"; value: tab.net.lan || "" }
            CopyableValue {
                Layout.fillWidth: true
                label: "WAN IP"
                value: telemetry.wanState === "ok" ? telemetry.wanIp : telemetry.wanState === "offline" ? "OFFLINE" : "RESOLVING..."
            }
            CopyableValue { Layout.fillWidth: true; label: "IPv6"; value: (tab.active.ipv6 || [])[0] || "" }
            CopyableValue { Layout.fillWidth: true; label: "MAC"; value: tab.active.mac || ""; copyable: value !== "" }
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                ReadoutLabel { Layout.fillWidth: true; label: "RECEIVED"; value: Theme.bytes(tab.net.rxTotal, 1) }
                ReadoutLabel { Layout.fillWidth: true; label: "SENT"; value: Theme.bytes(tab.net.txTotal, 1) }
            }
            GuideButton { text: "RE-RESOLVE WAN"; onClicked: telemetry.refreshWan() }
            Item { Layout.fillHeight: true }
        }

        GuideCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "INTERFACES"
            subtitle: (tab.net.interfaces || []).length + " LINKS"

            ListView {
                id: ifaces
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: tab.net.interfaces || []
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: GuideScrollBar {}
                delegate: Rectangle {
                    id: iface
                    required property var modelData
                    width: ifaces.width - 10
                    height: ifaceCol.implicitHeight + 16
                    radius: Theme.pillRadius
                    color: modelData.active ? Theme.tint(0.06) : "transparent"
                    border.width: 1
                    border.color: modelData.active ? Theme.accent : Theme.tint(0.25)
                    ColumnLayout {
                        id: ifaceCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                        spacing: 3
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Rectangle { width: 8; height: 8; radius: Theme.small(4); color: iface.modelData.up ? Theme.high : Theme.tint(0.3) }
                            Text {
                                text: iface.modelData.name
                                color: Theme.ink
                                font { family: Theme.mono; features: Theme.figures; pixelSize: 13; bold: true }
                            }
                            Text {
                                text: "[" + iface.modelData.kind.toUpperCase() + "]" + (iface.modelData.active ? "  DEFAULT ROUTE" : "")
                                color: iface.modelData.active ? Theme.accent : Theme.tint(0.5)
                                font { family: Theme.mono; features: Theme.figures; pixelSize: 10; bold: true }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "▼ " + Theme.rate(iface.modelData.rx) + "   ▲ " + Theme.rate(iface.modelData.tx)
                                color: Theme.ink
                                font { family: Theme.mono; features: Theme.figures; pixelSize: 11; bold: true }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: [(iface.modelData.ipv4 || []).join(", ") || "NO IPv4",
                                   iface.modelData.mac ? "MAC " + iface.modelData.mac : "",
                                   "MTU " + iface.modelData.mtu,
                                   iface.modelData.speed > 0 ? iface.modelData.speed + " Mb/s" : "",
                                   "RX " + Theme.bytes(iface.modelData.rxTotal, 1) + " / TX " + Theme.bytes(iface.modelData.txTotal, 1)]
                                  .filter(s => s).join("  ·  ")
                            color: Theme.tint(0.6)
                            elide: Text.ElideRight
                            font { family: Theme.mono; features: Theme.figures; pixelSize: 10 }
                        }
                    }
                }
            }
        }
    }
}
