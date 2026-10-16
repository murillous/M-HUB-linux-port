import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import MchoseV9

ApplicationWindow {
    id: window
    width: 1000
    height: 720
    minimumWidth: 640
    minimumHeight: 520
    visible: true
    title: tr("app.title")
    color: theme.background

    QtObject {
        id: theme
        readonly property color background: "#0d0f14"
        readonly property color surface: "#161a22"
        readonly property color surfaceHi: "#1e2430"
        readonly property color border: "#252b38"
        readonly property color grid: "#232937"
        readonly property color text: "#eef1f7"
        readonly property color textDim: "#8a93a6"
        readonly property color accent: "#5b8cff"
        readonly property color accent2: "#9d6bff"
        readonly property color ok: "#3ddc97"
        readonly property color warn: "#ffb547"
        readonly property color bad: "#ff5c7a"
    }

    I18n { id: i18n }
    Headset { id: headset }

    // Reading `i18n.language` here makes every binding that calls tr() update on language change.
    function tr(key) { return i18n.language, i18n.tr(key) }

    readonly property var eqModes: {
        try { return JSON.parse(headset.eqJson) } catch (e) { return [] }
    }
    property int shownEq: 0

    function eqName(i) {
        const m = eqModes[i]
        return m && m.name !== "" ? m.name : tr("eq.profile").arg(i + 1)
    }

    Component.onCompleted: headset.refresh()
    Connections {
        target: headset
        function onEqModeChanged() { if (headset.eqMode >= 0) window.shownEq = headset.eqMode }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: headset.refresh() }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 18

            // ── Header ───────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#1a2340" }
                    GradientStop { position: 1; color: "#24173d" }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 32
                    spacing: 24

                    ColumnLayout {
                        spacing: 8
                        Text {
                            text: "V9 Pro 2"
                            color: theme.text
                            font.pixelSize: 32
                            font.weight: Font.Bold
                        }
                        RowLayout {
                            spacing: 8
                            Rectangle {
                                width: 9; height: 9; radius: 5
                                color: headset.busy ? theme.warn : headset.connected ? theme.ok : theme.bad
                                SequentialAnimation on opacity {
                                    running: headset.busy; loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 500 }
                                    NumberAnimation { to: 1; duration: 500 }
                                }
                            }
                            Text {
                                color: theme.textDim
                                font.pixelSize: 13
                                text: headset.busy ? tr("status.reading")
                                    : headset.connected ? (headset.asleep ? tr("status.asleep") : tr("status.connected"))
                                    : headset.error === "" ? "" : tr("status." + headset.error)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // battery ring
                    Item {
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 96
                        visible: headset.connected
                        Canvas {
                            id: ring
                            anchors.fill: parent
                            property real value: Math.max(0, headset.batteryPercent) / 100
                            Behavior on value { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                            onValueChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d"), r = width / 2 - 6
                                ctx.reset()
                                ctx.lineWidth = 8
                                ctx.lineCap = "round"
                                ctx.strokeStyle = "#ffffff18"
                                ctx.beginPath(); ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI); ctx.stroke()
                                ctx.strokeStyle = value < 0.2 ? theme.bad : theme.ok
                                ctx.beginPath()
                                ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + value * 2 * Math.PI)
                                ctx.stroke()
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: headset.batteryPercent >= 0 ? headset.batteryPercent + "%" : tr("battery.unknown")
                                color: theme.text
                                font.pixelSize: 20
                                font.weight: Font.Bold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: headset.charging ? tr("battery.charging") : tr("battery.title")
                                color: theme.textDim
                                font.pixelSize: 10
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 8
                        ComboBox {
                            id: languageBox
                            Layout.preferredWidth: 150
                            model: [{ code: "en", label: "English" }, { code: "pt_BR", label: "Português" }]
                            textRole: "label"
                            valueRole: "code"
                            Component.onCompleted: currentIndex = indexOfValue(i18n.language)
                            onActivated: i18n.language = currentValue
                            ToolTip.visible: hovered
                            ToolTip.text: tr("settings.language")
                        }
                        Button {
                            Layout.preferredWidth: 150
                            text: tr("action.refresh")
                            enabled: !headset.busy
                            onClicked: headset.refresh()
                        }
                    }
                }
            }

            // ── Not connected ───────────────────────────────────────
            Text {
                visible: !headset.connected && !headset.busy && headset.error !== ""
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                wrapMode: Text.WordWrap
                color: theme.textDim
                text: tr("status.hint") + (headset.errorDetail !== "" ? "\n" + headset.errorDetail : "")
            }

            // ── Cards ────────────────────────────────────────────────
            GridLayout {
                visible: headset.connected
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                columns: window.width > 820 ? 3 : 1
                columnSpacing: 18
                rowSpacing: 18

                Card {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    title: tr("prompt.title")
                    description: tr("prompt.desc")
                    ColumnLayout {
                        width: parent.width
                        spacing: 8
                        Text {
                            text: headset.promptVolume >= 0 ? headset.promptVolume + " / " + headset.promptVolumeMax : "—"
                            color: theme.text
                            font.pixelSize: 26
                            font.weight: Font.Bold
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 6; radius: 3
                            color: theme.surfaceHi
                            Rectangle {
                                height: parent.height; radius: 3
                                width: parent.width * Math.max(0, headset.promptVolume) / headset.promptVolumeMax
                                Behavior on width { NumberAnimation { duration: 400 } }
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: theme.accent }
                                    GradientStop { position: 1; color: theme.accent2 }
                                }
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    title: tr("shutdown.title")
                    description: tr("shutdown.desc")
                    Text {
                        text: headset.autoShutdownMin < 0 ? "—"
                            : headset.autoShutdownMin === 0 ? tr("shutdown.never")
                            : tr("shutdown.minutes").arg(headset.autoShutdownMin)
                        color: theme.text
                        font.pixelSize: 26
                        font.weight: Font.Bold
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    title: tr("fw.title")
                    GridLayout {
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 6
                        Text { text: tr("fw.dongle"); color: theme.textDim; font.pixelSize: 13 }
                        Text { text: headset.firmwareDongle || "—"; color: theme.text; font.pixelSize: 13; font.family: "monospace" }
                        Text { text: tr("fw.headset"); color: theme.textDim; font.pixelSize: 13 }
                        Text { text: headset.firmwareHeadset || "—"; color: theme.text; font.pixelSize: 13; font.family: "monospace" }
                    }
                }
            }

            Card {
                visible: headset.connected
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                title: tr("eq.title")
                description: tr("eq.desc")

                ColumnLayout {
                    width: parent.width
                    spacing: 14

                    Row {
                        spacing: 8
                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                required property int index
                                readonly property bool shown: window.shownEq === index
                                height: 34
                                width: label.implicitWidth + 32
                                radius: 17
                                color: shown ? theme.accent : theme.surfaceHi
                                border.color: headset.eqMode === index ? theme.accent : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    id: label
                                    anchors.centerIn: parent
                                    text: eqName(index) + (headset.eqMode === index ? "  •  " + tr("eq.active") : "")
                                    color: shown ? "white" : theme.text
                                    font.pixelSize: 13
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.shownEq = index
                                }
                            }
                        }
                    }

                    EqCurve {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        points: eqModes[window.shownEq] ? eqModes[window.shownEq].points : []
                    }

                    Row {
                        spacing: 6
                        Repeater {
                            model: eqModes[window.shownEq] ? eqModes[window.shownEq].points : []
                            delegate: Rectangle {
                                required property var modelData
                                width: 64; height: 44; radius: 8
                                color: theme.surfaceHi
                                Column {
                                    anchors.centerIn: parent
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: (modelData.gain > 0 ? "+" : "") + modelData.gain.toFixed(1)
                                        color: theme.text; font.pixelSize: 12; font.weight: Font.DemiBold
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.fc >= 1000 ? (modelData.fc / 1000) + "k" : modelData.fc
                                        color: theme.textDim; font.pixelSize: 10
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.leftMargin: 32
                Layout.bottomMargin: 24
                text: tr("note.readonly")
                color: theme.textDim
                font.pixelSize: 11
            }
        }
    }
}
