import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"

// One process laid open: identity, memory, its family (every ancestor and
// child, each a link to its own properties), the largest memory maps and the
// open file descriptors. Read once on show(); REFRESH reads again. What the
// kernel withholds about another user's process is listed at the bottom.
Popup {
    id: dialog

    property int pid: -1
    property var info: ({})
    readonly property var mem: info.memory || {}

    function show(p) {
        pid = p
        reload()
        open()
    }
    function reload() { info = processes.details(pid) }

    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(900, parent ? parent.width - 60 : 900)
    height: Math.min(720, parent ? parent.height - 60 : 720)
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: Theme.dark ? Qt.rgba(0, 0, 0, 0.7) : Qt.rgba(0.1, 0.12, 0.16, 0.35) }
    background: Item {}
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 } }

    component Heading: Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        color: Theme.accent
        font { family: Theme.mono; pixelSize: 11; bold: true; letterSpacing: 1.4 }
    }
    component Field: RowLayout {
        property string label
        property string value
        Layout.fillWidth: true
        spacing: 10
        Text {
            Layout.preferredWidth: 130
            text: parent.label
            color: Theme.tint(0.55)
            font { family: Theme.mono; pixelSize: 11; bold: true }
        }
        Text {
            Layout.fillWidth: true
            text: parent.value || "--"
            color: Theme.ink
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 3
            elide: Text.ElideRight
            font { family: Theme.mono; pixelSize: 12 }
        }
    }
    component PidLink: Text {
        property var proc: ({})
        property bool here: false
        text: proc.name + " (" + proc.pid + ")"
        color: here ? Theme.accent : linkArea.containsMouse ? Theme.accent : Theme.ink
        font { family: Theme.mono; pixelSize: 12; bold: here; underline: !here && linkArea.containsMouse }
        MouseArea {
            id: linkArea
            anchors.fill: parent
            enabled: !parent.here
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dialog.show(parent.proc.pid)
        }
    }

    contentItem: GuideCard {
        title: dialog.info.gone ? "PID " + dialog.pid + " HAS LEFT THE GALAXY"
                                : "PROPERTIES: " + (dialog.info.name || "?") + " (PID " + dialog.pid + ")"
        subtitle: dialog.info.cmd || ""
        padding: 18
        header: [
            GuideButton { text: "REFRESH"; pixelSize: 10; onClicked: dialog.reload() },
            GuideButton { text: "CLOSE"; pixelSize: 10; onClicked: dialog.close() }
        ]

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !dialog.info.gone
            clip: true
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: GuideScrollBar {}

            ColumnLayout {
                id: body
                width: flick.width - 12
                spacing: 4

                Heading { text: "IDENTITY"; Layout.topMargin: 0 }
                Field { label: "USER"; value: dialog.info.user || "" }
                Field { label: "STATUS"; value: (dialog.info.status || "").toUpperCase() }
                Field {
                    label: "STARTED"
                    value: dialog.info.started ? Qt.formatDateTime(new Date(dialog.info.started * 1000), "yyyy-MM-dd HH:mm:ss") : ""
                }
                Field { label: "CPU TIME"; value: dialog.info.cpu !== undefined ? dialog.info.cpu.toFixed(1) + " s" : "" }
                Field { label: "THREADS"; value: String(dialog.info.threads || 0) }
                Field { label: "NICE"; value: dialog.info.nice !== undefined ? String(dialog.info.nice) : "" }
                Field { label: "EXECUTABLE"; value: dialog.info.exe || "" }
                Field { label: "WORKING DIR"; value: dialog.info.cwd || "" }
                Field { label: "OPEN FDS"; value: dialog.info.fds >= 0 ? String(dialog.info.fds) : "" }

                Heading { text: "MEMORY" }
                Repeater {
                    model: [["rss", "RESIDENT (RSS)"], ["vms", "VIRTUAL (VMS)"], ["shared", "SHARED"],
                            ["uss", "UNIQUE (USS)"], ["pss", "PROPORTIONAL (PSS)"], ["swap", "SWAPPED"]]
                    Field {
                        required property var modelData
                        visible: dialog.mem[modelData[0]] !== undefined
                        label: modelData[1]
                        value: Theme.bytes(dialog.mem[modelData[0]] || 0)
                    }
                }

                Heading { text: "FAMILY" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: dialog.info.parents || []
                        Row {
                            required property var modelData
                            spacing: 6
                            PidLink { proc: parent.modelData }
                            Text { text: "▸"; color: Theme.tint(0.5); font { family: Theme.mono; pixelSize: 12 } }
                        }
                    }
                    PidLink { proc: ({ pid: dialog.pid, name: dialog.info.name || "?" }); here: true }
                }
                Text {
                    text: (dialog.info.children || []).length ? "CHILDREN (" + dialog.info.children.length + "):" : "NO CHILDREN."
                    color: Theme.tint(0.55)
                    font { family: Theme.mono; pixelSize: 11; bold: true }
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14
                    spacing: 14
                    Repeater {
                        model: dialog.info.children || []
                        PidLink { required property var modelData; proc: modelData }
                    }
                }

                Heading {
                    text: "MEMORY MAPS" + (dialog.info.mapCount ? " (" + Math.min(dialog.info.mapCount, (dialog.info.maps || []).length)
                                                                  + " LARGEST OF " + dialog.info.mapCount + ", BY RESIDENT SIZE)" : "")
                }
                Repeater {
                    model: dialog.info.maps || []
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            Layout.preferredWidth: 90
                            horizontalAlignment: Text.AlignRight
                            text: Theme.bytes(modelData.rss)
                            color: Theme.ink
                            font { family: Theme.mono; pixelSize: 11; bold: true }
                        }
                        Text {
                            Layout.preferredWidth: 90
                            horizontalAlignment: Text.AlignRight
                            text: modelData.size ? Theme.bytes(modelData.size) : ""
                            color: Theme.tint(0.5)
                            font { family: Theme.mono; pixelSize: 11 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.path
                            elide: Text.ElideMiddle
                            color: Theme.tint(0.8)
                            font { family: Theme.mono; pixelSize: 11 }
                        }
                    }
                }

                Heading {
                    text: "OPEN FILES" + (dialog.info.fileCount ? " (" + Math.min(dialog.info.fileCount, (dialog.info.files || []).length)
                                                                  + " OF " + dialog.info.fileCount + ")" : "")
                }
                Repeater {
                    model: dialog.info.files || []
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            Layout.preferredWidth: 50
                            horizontalAlignment: Text.AlignRight
                            text: "fd " + modelData.fd
                            color: Theme.tint(0.55)
                            font { family: Theme.mono; pixelSize: 11 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.path
                            elide: Text.ElideMiddle
                            color: Theme.ink
                            font { family: Theme.mono; pixelSize: 11 }
                        }
                    }
                }
                Text {
                    visible: !(dialog.info.files || []).length && !(dialog.info.denied || []).length
                    text: "NO REGULAR FILES OPEN (SOCKETS AND PIPES ARE NOT LISTED)."
                    color: Theme.tint(0.5)
                    font { family: Theme.mono; pixelSize: 11 }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    visible: (dialog.info.denied || []).length > 0
                    wrapMode: Text.Wrap
                    text: "THE KERNEL WITHHOLDS " + (dialog.info.denied || []).join(", ").toUpperCase()
                          + " OF ANOTHER USER'S PROCESS. RUN AS ITS OWNER (OR ROOT) TO SEE THEM."
                    color: Theme.mid
                    font { family: Theme.mono; pixelSize: 11; bold: true }
                }
            }
        }
        Text {
            visible: !!dialog.info.gone
            text: "IT MAY HAVE GONE FOR A TOWEL."
            color: Theme.tint(0.5)
            font { family: Theme.mono; pixelSize: 13 }
        }
    }
}
