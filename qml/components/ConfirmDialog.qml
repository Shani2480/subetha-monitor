import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "."

// A modal question in the Guide's voice. open() with a title, body and
// confirm label; `accepted` fires on CONFIRM (or Enter), Escape cancels.
Popup {
    id: dialog

    property string title: ""
    property string body: ""
    property string confirmText: "CONFIRM"
    property color tone: Theme.alert
    signal accepted()

    function ask(t, b, c) {
        title = t; body = b; confirmText = c || "CONFIRM"
        open()
    }

    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(520, parent ? parent.width - 40 : 520)
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: Theme.dark ? Qt.rgba(0, 0, 0, 0.7) : Qt.rgba(0.1, 0.12, 0.16, 0.35) }
    background: Item {}

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 } }

    contentItem: GuideCard {
        title: dialog.title
        borderColor: dialog.tone
        padding: 20
        focus: true
        Keys.onReturnPressed: { dialog.accepted(); dialog.close() }
        Keys.onEnterPressed: { dialog.accepted(); dialog.close() }

        Text {
            Layout.fillWidth: true
            text: dialog.body
            wrapMode: Text.Wrap
            color: Theme.ink
            textFormat: Text.StyledText
            font { family: Theme.mono; pixelSize: 13 }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: "DON'T PANIC."
                color: Theme.accent
                font { family: Theme.mono; pixelSize: 11; bold: true; letterSpacing: 1 }
            }
            GuideButton { text: "CANCEL"; onClicked: dialog.close() }
            GuideButton {
                text: dialog.confirmText
                tone: dialog.tone
                checked: true
                onClicked: { dialog.accepted(); dialog.close() }
            }
        }
    }
}
