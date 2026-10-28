import QtQuick
import QtQuick.Layouts
import "."

// The frameless window's own title bar: the planet, the console's name and
// DON'T PANIC on the left, a drag strip across the middle (double-click
// maximizes), the theme picker (the Guide's own look or an installed skin),
// the dark / light switch and the three window controls on the right.
// The move starts once the pointer has travelled a few pixels, not on press:
// a compositor that grabs the pointer for the move would otherwise eat the
// second click of a double-click.
Item {
    id: bar

    required property var window
    readonly property bool maximized: window.visibility === Window.Maximized
    property var themeChoices: []        // [{ value, label }]
    property string currentTheme: ""
    signal themePicked(string id)
    signal toggleTheme()
    signal minimizeRequested()
    signal closeRequested()

    function toggleMaximize() {
        if (window.visibility === Window.Maximized) window.showNormal()
        else window.showMaximized()
    }

    implicitHeight: 38

    MouseArea {   // behind everything: the whole bar drags
        id: drag
        anchors.fill: parent
        property point pressAt
        onPressed: mouse => pressAt = Qt.point(mouse.x, mouse.y)
        onPositionChanged: mouse => {
            if (pressed && Math.abs(mouse.x - pressAt.x) + Math.abs(mouse.y - pressAt.y) > 4)
                bar.window.startSystemMove()
        }
        onDoubleClicked: bar.toggleMaximize()
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 22; rightMargin: 0 }
        spacing: 10

        Image {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            source: "../../assets/subetha-icon.svg"
            sourceSize: Qt.size(40, 40)
        }
        Text {
            text: "SUB-ETHA HOST DIAGNOSTICS // ZZ9-CONSOLE"
            color: Theme.ink
            elide: Text.ElideRight
            Layout.preferredWidth: implicitWidth
            Layout.minimumWidth: 60
            font { family: Theme.mono; pixelSize: 12; bold: true; letterSpacing: 1.4 }
        }
        DontPanicPill { pixelSize: 9 }
        Image {   // a skin's logo, beside the name
            visible: source != ""
            Layout.preferredHeight: 18
            Layout.preferredWidth: 18 * (implicitWidth / Math.max(1, implicitHeight))
            source: Theme.frame && Theme.frame.logo ? Theme.frame.logo : ""
            sourceSize.height: 36
            fillMode: Image.PreserveAspectFit
        }

        Item { Layout.fillWidth: true }   // the drag strip shows through here

        GuideCombo {
            id: picker
            implicitWidth: 230
            implicitHeight: 26
            font.pixelSize: 10
            textRole: "label"
            valueRole: "value"
            model: bar.themeChoices
            function sync() { currentIndex = indexOfValue(bar.currentTheme) }
            onModelChanged: sync()
            Component.onCompleted: sync()
            Connections { target: bar; function onCurrentThemeChanged() { picker.sync() } }
            onActivated: bar.themePicked(currentValue)
        }
        GuideButton {
            text: Theme.dark ? "DARK / light" : "dark / LIGHT"
            enabled: !Theme.skin || !!Theme.skin.variants || Theme.skin.isDark === null
            pixelSize: 10
            tone: Theme.dark ? Theme.amber : Theme.coral
            onClicked: bar.toggleTheme()
        }
        Item { implicitWidth: 6 }

        Row {
            Layout.fillHeight: true
            WindowButton { kind: "minimize"; onClicked: bar.minimizeRequested() }
            WindowButton { kind: bar.maximized ? "restore" : "maximize"; onClicked: bar.toggleMaximize() }
            WindowButton { kind: "close"; onClicked: bar.closeRequested() }
        }
    }

    component WindowButton: Item {
        id: wb
        property string kind
        signal clicked()
        readonly property bool danger: kind === "close"
        readonly property bool hot: area.containsMouse
        readonly property color glyph: hot && danger ? "#FFFFFF" : hot ? Theme.ink : Theme.tint(0.75)
        width: 46
        height: bar.height

        Rectangle {
            anchors.fill: parent
            visible: wb.hot
            // Close floods red; the others glow faintly.
            color: wb.danger ? (Theme.skinned ? Theme.red : Theme.dark ? "#FF3333" : "#FF4A4A")
                 : Theme.dark ? Theme.withAlpha(Theme.phosphor, area.pressed ? 0.28 : 0.16)
                 : Theme.withAlpha(Theme.mustard, area.pressed ? 0.75 : 0.5)
        }
        // Minimize: an underscore
        Rectangle {
            visible: wb.kind === "minimize"
            width: 11; height: 1.5
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: 4 }
            color: wb.glyph
        }
        // Maximize: one box
        Rectangle {
            visible: wb.kind === "maximize"
            width: 10; height: 10
            anchors.centerIn: parent
            color: "transparent"
            border { width: 1.5; color: wb.glyph }
        }
        // Restore: two overlapping boxes
        Item {
            visible: wb.kind === "restore"
            width: 12; height: 12
            anchors.centerIn: parent
            // The back box shows only where the front one does not cover it.
            Rectangle { x: 3; y: 0; width: 9; height: 1.5; color: wb.glyph }
            Rectangle { x: 10.5; y: 0; width: 1.5; height: 9; color: wb.glyph }
            Rectangle { x: 3; y: 0; width: 1.5; height: 3; color: wb.glyph }
            Rectangle { x: 9; y: 7.5; width: 3; height: 1.5; color: wb.glyph }
            Rectangle { x: 0; y: 3; width: 9; height: 9; color: "transparent"; border { width: 1.5; color: wb.glyph } }
        }
        // Close: a cross
        Repeater {
            model: wb.kind === "close" ? [45, -45] : []
            Rectangle {
                required property int modelData
                width: 14; height: 1.5
                anchors.centerIn: parent
                rotation: modelData
                antialiasing: true
                color: wb.glyph
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: wb.clicked()
        }
    }
}
