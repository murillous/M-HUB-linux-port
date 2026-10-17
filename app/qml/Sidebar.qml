import QtQuick
import QtQuick.Layouts
import MchoseV9

// Left column: device name, battery/connection, navigation.
Item {
    id: sidebar

    required property Headset headset
    property int current: 0
    property var items: []   // [{icon, text}]

    implicitWidth: Theme.sidebarWidth

    ColumnLayout {
        id: head
        x: Theme.gutter
        y: 16
        width: parent.width - 2 * Theme.gutter
        spacing: 12

        Text {
            text: "V9 Pro 2"
            font.family: Theme.font
            font.pixelSize: 26
            font.weight: Font.Bold
            color: Theme.text
        }

        RowLayout {
            spacing: 16
            visible: sidebar.headset.connected

            Meta {
                icon: "battery"
                text: sidebar.headset.batteryPercent >= 0 ? sidebar.headset.batteryPercent + "%" : Theme.dash
            }
            Meta {
                icon: sidebar.headset.wired ? "cable" : "wifi"
                text: sidebar.headset.wired ? "USB" : "2.4G"
            }
            Meta {
                visible: sidebar.headset.charging || sidebar.headset.asleep
                icon: ""
                text: sidebar.headset.charging ? Lang.tr("battery.charging") : Lang.tr("status.asleep")
                color: Theme.warn
            }
        }

        RowLayout {
            spacing: 8
            visible: !sidebar.headset.connected
            Rectangle {
                width: 8; height: 8; radius: 4
                color: sidebar.headset.busy ? Theme.warn : Theme.danger
                SequentialAnimation on opacity {
                    running: sidebar.headset.busy
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }
            Text {
                text: sidebar.headset.busy ? Lang.tr("status.reading")
                    : sidebar.headset.error !== "" ? Lang.tr("status." + sidebar.headset.error) : ""
                font.family: Theme.font
                font.pixelSize: 14
                color: Theme.textDim
            }
        }
    }

    Column {
        anchors.top: head.bottom
        anchors.topMargin: 28
        x: Theme.gutter
        width: parent.width - 2 * Theme.gutter
        spacing: 16

        Repeater {
            model: sidebar.items
            delegate: Rectangle {
                id: navRow
                required property var modelData
                required property int index
                readonly property bool selected: sidebar.current === index

                width: parent.width
                height: 40
                radius: Theme.radiusRow
                color: selected ? Theme.panel : hover.hovered ? Qt.rgba(1, 1, 1, 0.03) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                HoverHandler { id: hover }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 16
                    spacing: 4
                    Icon {
                        name: navRow.modelData.icon
                        size: 20
                        stroke: navRow.selected ? 2 : 1.6
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: navRow.modelData.text
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sidebar.current = navRow.index
                }
            }
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.gutter
        x: Theme.gutter
        width: parent.width - 2 * Theme.gutter
        wrapMode: Text.WordWrap
        text: Lang.tr("note.readonly")
        font.family: Theme.font
        font.pixelSize: 12
        color: Theme.textFaint
    }

    component Meta: Row {
        property string icon
        property alias text: label.text
        property alias color: label.color
        spacing: 4
        Icon {
            visible: parent.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: parent.icon
            size: 16
        }
        Text {
            id: label
            font.family: Theme.font
            font.pixelSize: 14
            color: Theme.text
        }
    }
}
