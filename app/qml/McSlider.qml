import QtQuick
import QtQuick.Controls.Basic

// 4 px runway, accent bar, 16 px handle with a white ring that grows on hover.
Slider {
    id: control

    property bool dim: false   // drawn without bar/handle, like the original when the feature is off

    implicitHeight: 24
    padding: 0
    opacity: enabled ? 1 : 0.6

    background: Item {
        x: control.leftPadding
        width: control.availableWidth
        height: control.height

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: control.dim ? Theme.divider : Theme.track

            Rectangle {
                visible: !control.dim
                width: control.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }
    }

    handle: Rectangle {
        visible: !control.dim
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: (control.height - height) / 2
        width: 16
        height: 16
        radius: 8
        color: Theme.accent
        border.color: "white"
        border.width: 1
        scale: control.pressed || control.hovered ? 1.2 : 1
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }
}
