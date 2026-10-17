pragma Singleton
import QtQuick

// Design tokens measured from the MCHOSE HUB dark theme (computed styles, see docs/04).
QtObject {
    // surfaces, darkest to lightest
    readonly property color window: "#0c0c0c"
    readonly property color panel: "#141414"        // main panel, selected sidebar row, EQ panes
    readonly property color card: "#1a1a1b"         // cards inside the panel, preset cards
    readonly property color row: "#212121"          // sound-mode rows, secondary buttons
    readonly property color popup: "#303134"        // tooltips, menus
    readonly property color buttonBorder: "#2f2f2f"
    readonly property color divider: "#2b2b2b"      // chart grid lines, pane separators
    readonly property color track: "#414141"        // slider runway
    readonly property color switchOff: "#606166"

    // text
    readonly property color text: "#ffffff"
    readonly property color textDim: Qt.rgba(1, 1, 1, 0.5)
    readonly property color textFaint: Qt.rgba(1, 1, 1, 0.3)

    // accent
    readonly property color accent: "#226bee"
    readonly property color accentArea: Qt.rgba(34 / 255, 107 / 255, 238 / 255, 0.2)
    readonly property color activeRow: Qt.rgba(0, 83 / 255, 226 / 255, 0.1)
    readonly property color activeRowBorder: Qt.rgba(0, 83 / 255, 226 / 255, 0.4)
    readonly property color danger: "#ea5e56"
    readonly property color warn: "#f59c25"
    readonly property color ok: "#32aa70"

    // geometry
    readonly property int radiusPanel: 12
    readonly property int radiusRow: 8
    readonly property int sidebarWidth: 320
    readonly property int topBarHeight: 60
    readonly property int gutter: 24
    readonly property string dash: "—"   // escaped: literal non-ASCII in QML strings came out garbled

    // MiSans is free (Xiaomi); install it for the closest look, otherwise the system font is used.
    readonly property string font: Qt.fontFamilies().indexOf("MiSans") >= 0 ? "MiSans" : Qt.application.font.family
}
