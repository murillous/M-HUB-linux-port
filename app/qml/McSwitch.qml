import QtQuick

// 40×20 pill switch with a 16 px knob.
Rectangle {
    id: sw

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 40
    implicitHeight: 20
    radius: 10
    color: checked ? Theme.accent : Theme.switchOff
    opacity: enabled ? 1 : 0.5
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        y: 2
        x: sw.checked ? sw.width - width - 2 : 2
        width: 16
        height: 16
        radius: 8
        color: "white"
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            sw.checked = !sw.checked
            sw.toggled(sw.checked)
        }
    }
}
