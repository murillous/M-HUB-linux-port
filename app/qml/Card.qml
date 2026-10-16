import QtQuick
import QtQuick.Layouts

// Rounded panel with a title, an optional description and free content.
Rectangle {
    id: card

    property string title
    property string description
    default property alias content: body.data

    radius: 18
    color: theme.surface
    border.color: theme.border
    border.width: 1
    implicitHeight: column.implicitHeight + 40

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 20
        spacing: 6

        Text {
            text: card.title
            color: theme.text
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        Text {
            visible: card.description !== ""
            text: card.description
            color: theme.textDim
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Item {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 10
            implicitHeight: childrenRect.height
        }
    }
}
