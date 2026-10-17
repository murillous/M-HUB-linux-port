import QtQuick
import QtQuick.Layouts

// Buttons of the original UI. `flat` = text/icon only (EQ toolbar); otherwise the bordered dark button.
Rectangle {
    id: btn

    property string text
    property string icon
    property bool flat: false
    property color textColor: flat ? Theme.textDim : Theme.text
    property int fontSize: 13
    property bool bold: false
    property bool iconRight: false
    signal clicked()

    readonly property bool hovered: mouse.containsMouse && enabled

    implicitWidth: flat ? content.implicitWidth : Math.max(104, content.implicitWidth + 32)
    implicitHeight: flat ? Math.max(16, content.implicitHeight) : 40
    radius: Theme.radiusRow
    color: flat ? "transparent" : hovered ? "#2a2a2a" : Theme.row
    border.width: flat ? 0 : 1
    border.color: Theme.buttonBorder
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 4
        layoutDirection: btn.iconRight ? Qt.RightToLeft : Qt.LeftToRight

        Icon {
            visible: btn.icon !== ""
            name: btn.icon
            size: 16
            color: label.color
        }
        Text {
            id: label
            text: btn.text
            visible: text !== ""
            font.family: Theme.font
            font.pixelSize: btn.fontSize
            font.weight: btn.bold ? Font.DemiBold : Font.Normal
            color: btn.flat && btn.hovered ? Qt.lighter(btn.textColor, 1.6) : btn.textColor
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (btn.enabled) btn.clicked()
    }
}
