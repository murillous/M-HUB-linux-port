import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

// One onboard EQ mode: tag, name, "Edit EQ"; the active one is tinted with a check in the corner.
Rectangle {
    id: row

    property string tag
    property string name
    property bool active: false
    signal edit()

    implicitHeight: 91
    radius: Theme.radiusRow
    color: active ? Theme.activeRow : Theme.row
    border.width: 1
    border.color: active ? Theme.activeRowBorder : "transparent"
    Behavior on color { ColorAnimation { duration: 200 } }

    ColumnLayout {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 8
        ModeTag { text: row.tag }
        Text {
            text: row.name
            font.family: Theme.font
            font.pixelSize: 14
            color: Theme.text
        }
    }

    McButton {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        flat: true
        icon: "eq"
        text: Lang.tr("common.editEq")
        fontSize: 14
        textColor: Theme.text
        onClicked: row.edit()
    }

    // corner check (triangle following the rounded corner)
    Item {
        visible: row.active
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 24
        height: 24
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: Theme.accent
                PathSvg { path: "M 24 0 L 24 16 A 8 8 0 0 1 16 24 L 0 24 Z" }
            }
        }
        Icon {
            x: 11; y: 11
            name: "check"
            size: 12
            stroke: 2
            color: "white"
        }
    }
}
