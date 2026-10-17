import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtCore
import "eqpath.js" as EqPath

// EQ editor that replaces the "Common parameters" page, like "Edit EQ" in the MCHOSE HUB:
// header with the mode, chart pane on the left, preset library on the right.
// Edits stay local until HID writes are enabled.
Item {
    id: editor

    /// `[{name, points: [{fc, gain, q, type, enable}]}]` as read from the headset.
    property var modes: []
    property int modeIndex: 0
    property int activeMode: -1
    signal collapse()

    property var undoStack: []
    property var redoStack: []
    property var _pending: null   // values before the current drag/wheel gesture

    readonly property var mode: modes[modeIndex] || { name: "", points: [] }
    readonly property var deviceValues: mode.points.map(p => p.gain)
    readonly property bool dirty: JSON.stringify(chart.values) !== JSON.stringify(deviceValues.map(chart.clampDb))

    function modeName(i) {
        const m = modes[i]
        return m && m.name !== "" ? m.name : Lang.tr("eq.profile").arg(i + 1)
    }

    function load(animate) {
        undoStack = []
        redoStack = []
        const v = deviceValues.length ? deviceValues : [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        chart.setValues(v, animate)
    }

    function pushHistory(before) {
        undoStack = undoStack.concat([before])
        redoStack = []
    }

    function applyValues(v) {
        pushHistory(chart.values.slice())
        chart.setValues(v, true)
    }

    function undo() {
        if (!undoStack.length) return
        redoStack = redoStack.concat([chart.values.slice()])
        const v = undoStack[undoStack.length - 1]
        undoStack = undoStack.slice(0, -1)
        chart.setValues(v, true)
    }

    function redo() {
        if (!redoStack.length) return
        undoStack = undoStack.concat([chart.values.slice()])
        const v = redoStack[redoStack.length - 1]
        redoStack = redoStack.slice(0, -1)
        chart.setValues(v, true)
    }

    onModeIndexChanged: load(true)
    Component.onCompleted: load(false)

    // Own presets for the 10 onboard bands (45 Hz … 12 kHz). Not MCHOSE's official presets.
    readonly property var builtIn: [
        { key: "flat", icon: "flat", color: "#226bee", values: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] },
        { key: "bass", icon: "bass", color: "#32aa70", values: [6, 5, 3, 1, 0, 0, 0, 0, 0, 0] },
        { key: "footsteps", icon: "target", color: "#ea5e56", values: [-4, -3, -2, 0, 1, 3, 5, 4, 2, 0] },
        { key: "vocal", icon: "voice", color: "#b500ec", values: [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1] },
        { key: "music", icon: "note", color: "#f59c25", values: [4, 3, 1, 0, -1, 0, 1, 2, 3, 3] },
        { key: "movie", icon: "speaker", color: "#00b8be", values: [5, 4, 2, 0, 0, 1, 2, 2, 3, 2] },
        { key: "treble", icon: "treble", color: "#e26735", values: [0, 0, 0, 0, 0, 1, 3, 4, 5, 5] }
    ]

    Settings {
        id: store
        category: "eq"
        property string myPresets: "[]"
    }
    readonly property var myPresets: {
        try { return JSON.parse(store.myPresets) } catch (e) { return [] }
    }

    function saveMine() {
        const list = myPresets.concat([{ name: Lang.tr("eq.myPresetName").arg(myPresets.length + 1), values: chart.values.slice() }])
        store.myPresets = JSON.stringify(list)
        library.tab = 1
    }

    function removeMine(i) {
        const list = myPresets.slice()
        list.splice(i, 1)
        store.myPresets = JSON.stringify(list)
    }

    // ── Header ───────────────────────────────────────────────────────
    Item {
        id: header
        width: parent.width
        height: 60

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: Theme.gutter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            ModeTag { text: Lang.tr("mode.tag").arg(editor.modeIndex + 1) }
            Text {
                text: editor.modeName(editor.modeIndex)
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Icon {
                    anchors.centerIn: parent
                    name: modeMenu.visible ? "chevronUp" : "chevronDown"
                    size: 16
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modeMenu.open()
                }
                McMenu {
                    id: modeMenu
                    y: parent.height + 8
                    Repeater {
                        model: 3
                        delegate: McMenuItem {
                            required property int index
                            text: Lang.tr("mode.tag").arg(index + 1) + "  ·  " + editor.modeName(index)
                            checked: editor.modeIndex === index
                            onTriggered: editor.modeIndex = index
                        }
                    }
                }
            }
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: Theme.gutter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24

            McButton {
                flat: true
                icon: "restore"
                text: Lang.tr("eq.restoreDefaults")
                fontSize: 14
                textColor: Theme.text
                onClicked: editor.applyValues([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
            }
            McButton {
                flat: true
                icon: "chevronUp"
                iconRight: true
                text: Lang.tr("eq.collapse")
                fontSize: 14
                bold: true
                textColor: Theme.accent
                onClicked: editor.collapse()
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.divider
        }
    }

    // ── Chart pane ───────────────────────────────────────────────────
    Item {
        id: chartPane
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: library.left
        anchors.leftMargin: Theme.gutter
        anchors.rightMargin: Theme.gutter

        RowLayout {
            id: chartHead
            width: parent.width
            height: 48
            spacing: 16

            Text {
                text: Lang.tr("eq.equalizer")
                font.family: Theme.font
                font.pixelSize: 16
                font.weight: Font.Bold
                color: Theme.text
            }
            Item { Layout.fillWidth: true }
            McButton {
                flat: true
                icon: "undo"
                text: Lang.tr("eq.back")
                enabled: editor.undoStack.length > 0
                onClicked: editor.undo()
            }
            McButton {
                flat: true
                icon: "redo"
                text: Lang.tr("eq.forward")
                enabled: editor.redoStack.length > 0
                onClicked: editor.redo()
            }
            McButton {
                flat: true
                icon: "save"
                text: Lang.tr("eq.saveMine")
                textColor: Theme.text
                onClicked: editor.saveMine()
            }
        }

        EqChart {
            id: chart
            anchors.top: chartHead.bottom
            anchors.topMargin: 12
            anchors.bottom: note.top
            anchors.bottomMargin: 8
            x: -24
            width: parent.width + 24
            labels: editor.mode.points.length
                ? editor.mode.points.map(p => EqPath.formatFreq(p.fc))
                : ["45Hz", "100Hz", "250Hz", "400Hz", "1KHz", "2KHz", "4KHz", "6KHz", "8KHz", "12KHz"]
            bandNames: [Lang.tr("eq.bass"), Lang.tr("eq.mid"), Lang.tr("eq.high")]
            onEditBegan: editor.pushHistory(values.slice())
        }

        Text {
            id: note
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            width: parent.width
            wrapMode: Text.WordWrap
            text: editor.dirty ? Lang.tr("eq.localOnly") : ""
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.textFaint
        }
    }

    // ── Preset library ───────────────────────────────────────────────
    Item {
        id: library
        property int tab: 0

        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 384

        Rectangle {
            width: 1
            height: parent.height
            color: Theme.divider
        }

        Text {
            id: libTitle
            x: Theme.gutter
            height: 48
            verticalAlignment: Text.AlignVCenter
            text: Lang.tr("eq.presets")
            font.family: Theme.font
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: Theme.text
        }

        Row {
            id: tabs
            anchors.top: libTitle.bottom
            x: Theme.gutter
            height: 48
            spacing: 16
            Repeater {
                model: [Lang.tr("eq.tabBuiltIn"), Lang.tr("eq.tabMine")]
                delegate: Text {
                    required property string modelData
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: library.tab === index ? Font.DemiBold : Font.Normal
                    color: library.tab === index ? Theme.accent : Theme.text
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: library.tab = index
                    }
                }
            }
        }

        ListView {
            id: presetList
            anchors.top: tabs.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.gutter
            anchors.rightMargin: Theme.gutter
            clip: true
            spacing: 8
            bottomMargin: 16
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            model: library.tab === 0 ? editor.builtIn : editor.myPresets

            delegate: PresetCard {
                required property var modelData
                required property int index
                width: presetList.width
                name: library.tab === 0 ? Lang.tr("preset." + modelData.key) : modelData.name
                icon: modelData.icon || "eq"
                iconColor: modelData.color || Theme.accent
                values: modelData.values
                removable: library.tab === 1
                onApply: editor.applyValues(modelData.values)
                onRemove: editor.removeMine(index)
            }

            Text {
                visible: presetList.count === 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: 40
                text: Lang.tr("eq.noPresets")
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.textDim
            }
        }
    }
}
