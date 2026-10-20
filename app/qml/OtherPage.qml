import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import MchoseV9

// "Other settings": power management, firmware versions, factory reset.
Item {
    id: page

    required property Headset headset

    function shutdownLabel(min) {
        return min < 0 ? Theme.dash : min === 0 ? Lang.tr("shutdown.never") : Lang.tr("shutdown.minutes").arg(min)
    }

    PageTitle { id: heading; text: Lang.tr("nav.other") }

    HeadsetImage {
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -(column.width / 2 + 16)
        size: Math.min(320, page.width - column.width - 120)
        visible: size > 120
    }

    ColumnLayout {
        id: column
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Math.max(Theme.gutter, (page.width - 1096) / 2 + 116)
        width: 512
        spacing: 16

        Box {
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                BoxTitle { text: Lang.tr("other.power") }
                Icon {
                    name: "help"
                    size: 14
                    color: Theme.textDim
                    HoverHandler { id: powerHelp }
                    ToolTip.visible: powerHelp.hovered
                    ToolTip.text: Lang.tr("shutdown.desc")
                }
                Item { Layout.fillWidth: true }
                RowLayout {
                    id: shutdownPicker
                    spacing: 6
                    Text {
                        text: Lang.tr("other.smartPowerOff") + "  " + page.shutdownLabel(page.headset.autoShutdownMin)
                        font.family: Theme.font
                        font.pixelSize: 14
                        color: Theme.text
                    }
                    Icon { name: "chevronDown"; size: 14; color: Theme.textDim }
                    TapHandler {
                        enabled: page.headset.connected
                        onTapped: shutdownMenu.open()
                    }
                    HoverHandler { cursorShape: page.headset.connected ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    McMenu {
                        id: shutdownMenu
                        x: shutdownPicker.width - width
                        y: shutdownPicker.height + 8
                        Repeater {
                            model: [15, 30, 45, 0]
                            delegate: McMenuItem {
                                required property int modelData
                                text: page.shutdownLabel(modelData)
                                checked: page.headset.autoShutdownMin === modelData
                                onTriggered: if (!checked) page.headset.setAutoShutdownOnDevice(modelData)
                            }
                        }
                    }
                }
            }
        }

        Box {
            BoxTitle { text: Lang.tr("fw.headset") + ": " + (page.headset.firmwareHeadset || Theme.dash) }
            BoxDesc { text: Lang.tr("fw.note") }
        }

        Box {
            BoxTitle { text: Lang.tr("fw.dongle") + ": " + (page.headset.firmwareDongle || Theme.dash) }
            BoxDesc { text: Lang.tr("fw.note") }
        }

        Box {
            RowLayout {
                Layout.fillWidth: true
                spacing: 32
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    BoxTitle { text: Lang.tr("other.restore") }
                    BoxDesc { text: Lang.tr("other.restoreDesc") }
                }
                McButton {
                    text: Lang.tr("other.restoreButton")
                    enabled: false
                }
            }
        }
    }

    component Box: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 48
        radius: Theme.radiusPanel
        color: Theme.card
        ColumnLayout {
            id: inner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 32
            anchors.rightMargin: 32
            spacing: 6
        }
    }

    component BoxTitle: Text {
        font.family: Theme.font
        font.pixelSize: 16
        font.weight: Font.DemiBold
        color: Theme.text
    }

    component BoxDesc: Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.family: Theme.font
        font.pixelSize: 13
        color: Theme.textDim
    }
}
