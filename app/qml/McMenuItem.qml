import QtQuick
import QtQuick.Controls.Basic

MenuItem {
    id: item
    implicitHeight: 36
    leftPadding: 12
    rightPadding: 12

    indicator: Icon {
        visible: item.checked
        x: item.width - width - 10
        anchors.verticalCenter: parent.verticalCenter
        name: "check"
        size: 16
        color: Theme.accent
    }

    contentItem: Text {
        text: item.text
        rightPadding: 24
        font.family: Theme.font
        font.pixelSize: 14
        color: item.checked ? Theme.accent : Theme.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: 6
        color: item.highlighted ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
    }
}
