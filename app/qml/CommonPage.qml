import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import MchoseV9

// "Common parameters": volume / sound notification / microphone and the three onboard sound modes.
Item {
    id: page

    required property Headset headset
    required property var modes
    signal editEq(int mode)

    function modeName(i) {
        const m = modes[i]
        return m && m.name !== "" ? m.name : Lang.tr("eq.profile").arg(i + 1)
    }

    PageTitle { id: title; text: Lang.tr("nav.common") }

    HeadsetImage {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: title.bottom
        anchors.bottom: cards.top
        anchors.margins: 16
        size: Math.min(222, height)
        visible: height > 100
    }

    RowLayout {
        id: cards
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.gutter
        height: Math.min(412, page.height - 120)
        spacing: 16

        // ── Levels ──
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                LevelRow {
                    title: Lang.tr("common.volume")
                    icon: "speaker"
                    from: 0; to: 100
                    value: -1
                    tip: Lang.tr("common.mixerSoon")
                }
                LevelRow {
                    Layout.topMargin: 38
                    title: Lang.tr("common.notification")
                    help: Lang.tr("prompt.desc")
                    from: 1; to: page.headset.promptVolumeMax
                    value: page.headset.promptVolume
                }
                LevelRow {
                    Layout.topMargin: 38
                    title: Lang.tr("common.microphone")
                    icon: "mic"
                    from: 0; to: 100
                    value: -1
                    tip: Lang.tr("common.mixerSoon")
                }
            }
        }

        // ── Sound modes ──
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1

            ColumnLayout {
                anchors.fill: parent
                spacing: 16

                ColumnLayout {
                    spacing: 4
                    Text {
                        text: Lang.tr("common.soundMode")
                        font.family: Theme.font
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        text: Lang.tr("common.soundModeTip")
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: Theme.textDim
                    }
                }

                Repeater {
                    model: 3
                    delegate: SoundModeRow {
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.maximumHeight: 91
                        tag: Lang.tr("mode.tag").arg(index + 1)
                        name: page.modeName(index)
                        active: page.headset.eqMode === index
                        onEdit: page.editEq(index)
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }

    // One labelled slider of the levels card.
    component LevelRow: ColumnLayout {
        id: row
        property string title
        property string icon
        property string help
        property string tip
        property real from
        property real to
        property real value: -1

        Layout.fillWidth: true
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: row.title
                font.family: Theme.font
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Icon {
                visible: row.help !== ""
                name: "help"
                size: 14
                color: Theme.textDim
                HoverHandler { id: helpHover }
                ToolTip.visible: helpHover.hovered
                ToolTip.text: row.help
            }
            Item { Layout.fillWidth: true }
            Icon {
                visible: row.icon !== ""
                name: row.icon
                size: 20
                color: Theme.accent
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            McSlider {
                Layout.fillWidth: true
                enabled: false
                opacity: 1
                dim: row.value < 0
                from: row.from
                to: row.to
                value: Math.max(row.from, row.value)
                HoverHandler { id: sliderHover }
                ToolTip.visible: sliderHover.hovered && row.tip !== ""
                ToolTip.text: row.tip
            }
            Text {
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignRight
                text: row.value < 0 ? Theme.dash : row.value
                font.family: Theme.font
                font.pixelSize: 14
                color: Theme.text
            }
        }
    }
}
