import QtQuick
import QtQuick.Layouts

// Preset entry in the EQ library pane: icon, name, sparkline and Apply.
Rectangle {
    id: card

    property string name
    property string icon: "eq"
    property color iconColor: Theme.accent
    property var values: []
    property bool removable: false
    signal apply()
    signal remove()

    implicitHeight: 124
    radius: Theme.radiusRow
    color: Theme.card
    border.width: 1
    border.color: hover.hovered ? Theme.track : "transparent"
    Behavior on border.color { ColorAnimation { duration: 200 } }

    HoverHandler { id: hover }

    RowLayout {
        anchors.left: parent.left
        anchors.right: spark.left
        anchors.top: parent.top
        anchors.leftMargin: 16
        anchors.rightMargin: 8
        anchors.topMargin: 20
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            radius: 12
            color: card.iconColor
            Icon {
                anchors.centerIn: parent
                name: card.icon
                size: 14
                stroke: 2
                color: "white"
            }
        }
        Text {
            Layout.fillWidth: true
            text: card.name
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.text
        }
    }

    Sparkline {
        id: spark
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 16
        anchors.topMargin: 20
        values: card.values
    }

    McButton {
        visible: card.removable
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.bottomMargin: 28
        flat: true
        text: Lang.tr("eq.delete")
        onClicked: card.remove()
    }

    McButton {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        implicitWidth: 68
        text: Lang.tr("eq.apply")
        onClicked: card.apply()
    }
}
