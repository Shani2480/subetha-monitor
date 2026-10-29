import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "."

// The frameless window's own title bar: the planet, the console's name and
// DON'T PANIC on the left, a drag strip across the middle (double-click
// maximizes), the theme picker (the Guide's own look or an installed skin),
// the dark / light switch and the three window controls on the right.
// The move starts once the pointer has travelled a few pixels, not on press:
// a compositor that grabs the pointer for the move would otherwise eat the
// second click of a double-click.
//
// A skin's chrome (Theme.chromeStyle) redraws it as its operating system's:
// Luna's blue gradient bar with the app icon and a shadowed title, the logo
// and bevelled buttons at the right; macOS's frosted bar, the traffic lights
// at the left and the title centred; Vista's teal glass with its gloss;
// Material's tonal bar; a terminal's [ TITLE ]; Kiroshi's angled tabs; a
// tactical HUD's brand badge, title and muted subtitle with flat ≡ – ✕. The
// theme picker and the dark / light switch stay at the right in every one.
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

    readonly property string chrome: Theme.chromeStyle
    readonly property bool os: chrome !== "" && chrome !== "plain"
    readonly property bool lightsLeft: Theme.chrome.buttons === "traffic" || chrome === "aqua"
    readonly property bool centred: Theme.chrome.titleAlign === "center"
    // without a chrome a built frame may still bring its own buttons
    readonly property string buttonStyle: ({ traffic: "aqua" })[Theme.chrome.buttons] || Theme.chrome.buttons || chrome
                                        || (["scrap", "candy"].indexOf(Theme.frameStyle) >= 0 ? Theme.frameStyle : "")
    readonly property bool hud: chrome === "hud"
    implicitHeight: Theme.chrome.titleHeight || ({ luna: 30, aqua: 30, aero: 30, material: 40, terminal: 30, kiroshi: 36, hud: 42 })[chrome] || 38

    // ---- the chrome's bar ----
    readonly property color titleInk: Theme.cc("titleText", ({ luna: "#FFFFFF", aero: "#000000",
                                                                aqua: Theme.dark ? "#DDDDDD" : "#4D4D4D" })[chrome] || Theme.ink)
    Loader {
        anchors.fill: parent
        active: bar.os
        sourceComponent: ({ luna: lunaBar, aqua: aquaBar, aero: aeroBar, kiroshi: kiroshiBar })[bar.chrome] || plainBar
    }
    Component {
        id: lunaBar
        Rectangle {
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.cc("titleTop", "#0058EE") }
                GradientStop { position: 0.12; color: Qt.lighter(Theme.cc("titleTop", "#0058EE"), 1.15) }
                GradientStop { position: 1; color: Theme.cc("titleBottom", "#2E8BFA") }
            }
            Rectangle {   // the inner specular line along the top
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 1; leftMargin: 6; rightMargin: 6 }
                height: 1
                color: Qt.rgba(1, 1, 1, 0.55)
            }
        }
    }
    Component {
        id: aquaBar
        Rectangle {
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.cc("titleTop", Theme.dark ? "#3A3A3C" : "#EDEDED") }
                GradientStop { position: 1; color: Theme.cc("titleBottom", Theme.dark ? "#2C2C2E" : "#D9D9D9") }
            }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Qt.rgba(0, 0, 0, Theme.dark ? 0.5 : 0.18) }
        }
    }
    Component {
        id: aeroBar
        Item {
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.cc("titleTop", "#D9A9D6E4") }
                    GradientStop { position: 1; color: Theme.cc("titleBottom", "#D94E8EA6") }
                }
            }
            Shape {   // the diagonal gloss over the top third, curving down to the right
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 0; strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: bar.height * 0.6
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.55) }
                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.05) }
                    }
                    startX: 0; startY: 0
                    PathLine { x: bar.width; y: 0 }
                    PathLine { x: bar.width; y: bar.height * 0.18 }
                    PathQuad { x: 0; y: bar.height * 0.55; controlX: bar.width * 0.45; controlY: bar.height * 0.1 }
                    PathLine { x: 0; y: 0 }
                }
            }
        }
    }
    Component {
        id: kiroshiBar
        Rectangle {
            color: Theme.bg
            Rectangle { anchors { left: parent.left; bottom: parent.bottom } width: parent.width * 0.35; height: 2; color: Theme.accent }
        }
    }
    Component {
        id: plainBar
        Rectangle { color: Theme.cc("titleTop", "transparent") }
    }

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

    // macOS centres the title over the whole bar
    Text {
        visible: bar.os && bar.centred
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width * 0.4)
        elide: Text.ElideRight
        text: bar.titleText
        color: bar.titleInk
        font { family: Theme.sans; pixelSize: 13; bold: Theme.chrome.titleBold !== false }
    }
    readonly property string titleText: chrome === "terminal" ? "[ " + Theme.lex("appTitle", "", "System Monitor").toUpperCase() + " ]"
                                      : chrome === "kiroshi" ? Theme.lex("appTitle", "", "System Monitor").toUpperCase()
                                      : Theme.lex("appTitle", "", "System Monitor")

    RowLayout {
        anchors { fill: parent; leftMargin: bar.os ? (bar.lightsLeft ? 12 : 8) : 22; rightMargin: bar.buttonStyle !== "" && bar.buttonStyle !== "plain" && bar.chrome !== "terminal" ? 6 : 0 }
        spacing: bar.os ? 8 : 10

        Row {   // macOS: the traffic lights first
            visible: bar.os && bar.lightsLeft
            spacing: 8
            HoverHandler { id: lightsHover }
            ChromeButton { style: "aqua"; kind: "close"; groupHot: lightsHover.hovered; onClicked: bar.closeRequested() }
            ChromeButton { style: "aqua"; kind: "minimize"; groupHot: lightsHover.hovered; onClicked: bar.minimizeRequested() }
            ChromeButton { style: "aqua"; kind: bar.maximized ? "restore" : "maximize"; groupHot: lightsHover.hovered; onClicked: bar.toggleMaximize() }
        }
        Image {   // the skin's application icon
            visible: bar.os && !bar.centred && !bar.hud && source != ""
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            source: Theme.icon("app")
            sourceSize: Qt.size(32, 32)
        }
        Image {   // the HUD's brand badge
            visible: bar.hud && source != ""
            Layout.preferredHeight: 22
            Layout.preferredWidth: 22 * implicitWidth / Math.max(1, implicitHeight)
            source: Theme.chrome.badge || ""
            sourceSize.height: 44
            fillMode: Image.PreserveAspectFit
        }
        Column {  // the HUD's title and muted subtitle
            visible: bar.hud
            Layout.alignment: Qt.AlignVCenter
            spacing: 1
            Text {
                text: Theme.lex("appTitle", "", "System Monitor")
                color: bar.titleInk
                font { family: Theme.sans; pixelSize: 14; bold: true }
            }
            Text {
                visible: text !== ""
                text: (Theme.chrome.subtitle || "").toUpperCase()
                color: Theme.inkSoft
                font { family: Theme.sans; pixelSize: 8; bold: true; letterSpacing: 1.2 }
            }
        }
        Item {    // the title, with Luna's soft drop shadow
            visible: bar.os && !bar.centred && !bar.hud
            Layout.preferredWidth: osTitle.implicitWidth + 1
            Layout.minimumWidth: 60
            Layout.fillHeight: true
            Text {
                visible: bar.chrome === "luna"
                x: 1; y: 1
                width: osTitle.width; height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: osTitle.text; elide: Text.ElideRight
                color: Theme.cc("titleShadow", "#0A246A")
                opacity: 0.7
                font: osTitle.font
            }
            Text {
                id: osTitle
                width: parent.width - 1; height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: bar.titleText
                elide: Text.ElideRight
                color: bar.titleInk
                font {
                    family: bar.chrome === "terminal" || bar.chrome === "kiroshi" ? Theme.mono : Theme.sans
                    pixelSize: bar.chrome === "material" ? 15 : 13
                    bold: Theme.chrome.titleBold !== false
                    letterSpacing: bar.chrome === "kiroshi" ? 2 : 0
                }
            }
        }

        Image {   // the Guide's planet; a skin's own logo follows the name instead
            visible: !Theme.skinned
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            source: "../../assets/subetha-icon.svg"
            sourceSize: Qt.size(40, 40)
        }
        Text {
            visible: !bar.os
            text: Theme.lex("consoleTitle", "SUB-ETHA HOST DIAGNOSTICS // ZZ9-CONSOLE", "HOST DIAGNOSTICS")
            color: Theme.ink
            elide: Text.ElideRight
            Layout.preferredWidth: implicitWidth
            Layout.minimumWidth: 60
            font { family: Theme.mono; features: Theme.figures; pixelSize: 12; bold: true; letterSpacing: 1.4 }
        }
        DontPanicPill { visible: !bar.os || bar.centred || bar.chrome === "terminal" || bar.chrome === "kiroshi"; pixelSize: 9 }
        Image {   // a skin's logo, beside the name
            visible: !bar.os && source != ""
            Layout.preferredHeight: 18
            Layout.preferredWidth: 18 * (implicitWidth / Math.max(1, implicitHeight))
            source: Theme.frame && Theme.frame.logo ? Theme.frame.logo : ""
            sourceSize.height: 36
            fillMode: Image.PreserveAspectFit
        }

        Item { Layout.fillWidth: true }   // the drag strip shows through here

        DontPanicPill { visible: bar.os && !bar.centred && bar.chrome !== "terminal" && bar.chrome !== "kiroshi"; pixelSize: 9 }

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
            tone: Theme.accent
            onClicked: bar.toggleTheme()
        }
        Image {   // Luna: the logo before the buttons
            visible: bar.os && source != ""
            Layout.preferredHeight: 18
            Layout.preferredWidth: 18 * (implicitWidth / Math.max(1, implicitHeight))
            source: Theme.chrome.logo || ""
            sourceSize.height: 36
            fillMode: Image.PreserveAspectFit
        }
        Item { implicitWidth: bar.os ? 2 : 6 }

        Row {
            visible: !(bar.os && bar.lightsLeft)
            Layout.fillHeight: bar.buttonStyle === "" || bar.chrome === "terminal"
            Layout.alignment: Qt.AlignVCenter
            spacing: ({ luna: 2, aero: 0, material: 2, kiroshi: 4, hud: 2, scrap: 4, candy: 6 })[bar.buttonStyle] || 0
            ChromeButton { visible: bar.hud; style: "hud"; barHeight: bar.height; kind: "menu"; onClicked: picker.popup.open() }
            ChromeButton { style: bar.buttonStyle; barHeight: bar.height; kind: "minimize"; onClicked: bar.minimizeRequested() }
            ChromeButton { visible: !bar.hud; style: bar.buttonStyle; barHeight: bar.height; kind: bar.maximized ? "restore" : "maximize"; onClicked: bar.toggleMaximize() }
            ChromeButton { style: bar.buttonStyle; barHeight: bar.height; kind: "close"; onClicked: bar.closeRequested() }
        }
    }
}
