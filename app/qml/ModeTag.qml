import QtQuick

// "Mode 1" outlined tag.
Rectangle {
    property alias text: label.text

    implicitWidth: label.implicitWidth + 10
    implicitHeight: 20
    radius: 4
    color: "transparent"
    border.width: 1
    border.color: Theme.textDim

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.font
        font.pixelSize: 12
        color: Theme.text
    }
}
