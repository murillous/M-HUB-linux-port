import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtCore
import MchoseV9

// Window laid out like the MCHOSE HUB headset page: top bar, sidebar, rounded main panel.
ApplicationWindow {
    id: window
    width: 1440
    height: 840
    minimumWidth: 1180
    minimumHeight: 720
    visible: true
    title: Lang.tr("app.title")
    color: Theme.window
    font.family: Theme.font

    Headset { id: headset }

    Settings {
        id: uiSettings
        category: "ui"
        property string language: "en"
    }
    Component.onCompleted: {
        Lang.i18n.language = uiSettings.language
        headset.refresh()
    }

    readonly property var eqModes: {
        try { return JSON.parse(headset.eqJson) } catch (e) { return [] }
    }
    property bool editorOpen: false
    property int editorMode: 0

    Timer { interval: 60000; running: true; repeat: true; onTriggered: headset.refresh() }

    Rectangle {
        id: root
        anchors.fill: parent
        color: Theme.window

        // ── Top bar ──────────────────────────────────────────────────────
        Item {
            id: topBar
            width: parent.width
            height: Theme.topBarHeight

            Text {
                x: Theme.gutter
                anchors.verticalCenter: parent.verticalCenter
                text: Lang.tr("app.title")
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.gutter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 32

                BarButton {
                    icon: "refresh"
                    tip: Lang.tr("action.refresh")
                    spinning: headset.busy
                    onClicked: if (!headset.busy) headset.refresh()
                }
                BarButton {
                    id: langButton
                    icon: "globe"
                    tip: Lang.tr("settings.language")
                    onClicked: langMenu.open()
                    McMenu {
                        id: langMenu
                        x: langButton.width - width
                        y: langButton.height + 12
                        Repeater {
                            model: [{ code: "en", label: "English" }, { code: "pt_BR", label: "Português (Brasil)" }]
                            delegate: McMenuItem {
                                required property var modelData
                                text: modelData.label
                                checked: Lang.i18n.language === modelData.code
                                onTriggered: {
                                    Lang.i18n.language = modelData.code
                                    uiSettings.language = modelData.code
                                }
                            }
                        }
                    }
                }
            }
        }

        Sidebar {
            id: sidebar
            anchors.top: topBar.bottom
            anchors.bottom: parent.bottom
            headset: headset
            items: [
                { icon: "sliders", text: Lang.tr("nav.common") },
                { icon: "wave", text: Lang.tr("nav.playback") },
                { icon: "mic", text: Lang.tr("nav.mic") },
                { icon: "hexagon", text: Lang.tr("nav.other") }
            ]
        }

        // ── Main panel ───────────────────────────────────────────────────
        Rectangle {
            id: panel
            anchors.top: topBar.bottom
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: Theme.gutter
            anchors.bottomMargin: Theme.gutter
            radius: Theme.radiusPanel
            color: Theme.panel
            clip: true

            StackLayout {
                anchors.fill: parent
                currentIndex: sidebar.current

                Item {
                    CommonPage {
                        anchors.fill: parent
                        headset: headset
                        modes: window.eqModes
                        opacity: window.editorOpen ? 0 : 1
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        onEditEq: mode => {
                            window.editorMode = mode
                            window.editorOpen = true
                        }
                    }
                    Loader {
                        anchors.fill: parent
                        active: window.editorOpen
                        opacity: window.editorOpen ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        sourceComponent: EqEditor {
                            modes: window.eqModes
                            modeIndex: window.editorMode
                            activeMode: headset.eqMode
                            onCollapse: window.editorOpen = false
                        }
                    }
                }

                EffectsPage {
                    title: Lang.tr("nav.playback")
                    effects: [
                        { key: "treble", intensity: true, def: 10 },
                        { key: "bassBoost", intensity: true, def: 10 },
                        { key: "volBalance", intensity: true, def: 0 },
                        { key: "vocalBoost", intensity: true, def: 0 }
                    ]
                }

                EffectsPage {
                    title: Lang.tr("nav.mic")
                    effects: [
                        { key: "micLevel", intensity: true, def: 24 },
                        { key: "micClarity", intensity: true, def: 0 },
                        { key: "micNr", intensity: false },
                        { key: "micMonitor", intensity: false }
                    ]
                }

                OtherPage { headset: headset }
            }

            // Not connected
            Rectangle {
                anchors.fill: parent
                visible: !headset.connected && !headset.busy && headset.error !== ""
                color: Qt.rgba(0.08, 0.08, 0.08, 0.92)
                MouseArea { anchors.fill: parent }

                Column {
                    anchors.centerIn: parent
                    width: Math.min(420, parent.width - 48)
                    spacing: 16
                    HeadsetArt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 160
                        opacity: 0.5
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Lang.tr("status." + headset.error)
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: Lang.tr("status.hint") + (headset.errorDetail !== "" ? "\n" + headset.errorDetail : "")
                        font.pixelSize: 13
                        color: Theme.textDim
                    }
                    McButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Lang.tr("action.refresh")
                        onClicked: headset.refresh()
                    }
                }
            }
        }
    }

    // Dev aid: `--shot <dir>` saves a PNG of every view (for comparing with the original) and quits.
    Timer {
        id: shotTour
        readonly property int argIndex: Qt.application.arguments.indexOf("--shot")
        readonly property string dir: argIndex >= 0 ? Qt.application.arguments[argIndex + 1] : ""
        readonly property var steps: [
            ["common", () => { sidebar.current = 0; window.editorOpen = false }],
            ["eq", () => { window.editorMode = Math.max(0, headset.eqMode); window.editorOpen = true }],
            ["playback", () => { window.editorOpen = false; sidebar.current = 1 }],
            ["mic", () => { sidebar.current = 2 }],
            ["other", () => { sidebar.current = 3 }]
        ]
        property int step: -1
        property bool grabbing: false
        running: dir !== "" && !headset.busy && headset.connected
        interval: 900
        repeat: true
        // Alternate ticks: switch view, then grab it (grabToImage renders on a later frame).
        onTriggered: {
            if (grabbing) {
                root.grabToImage(r => r.saveToFile(dir + "/" + steps[step][0] + ".png"))
            } else if (step + 1 < steps.length) {
                steps[++step][1]()
            } else {
                stop()
                Qt.quit()
            }
            grabbing = !grabbing
        }
    }

    component BarButton: Item {
        id: bb
        property string icon
        property string tip
        property bool spinning: false
        signal clicked()
        width: 24
        height: 24
        Icon {
            id: glyph
            anchors.centerIn: parent
            name: bb.icon
            size: 24
            opacity: mouse.containsMouse ? 1 : 0.85
            RotationAnimator on rotation {
                running: bb.spinning
                from: 0; to: 360; duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running) glyph.rotation = 0
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bb.clicked()
        }
        ToolTip.visible: mouse.containsMouse
        ToolTip.text: bb.tip
        ToolTip.delay: 500
    }
}
