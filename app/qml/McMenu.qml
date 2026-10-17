import QtQuick
import QtQuick.Controls.Basic

// Dark popup menu (#303134, radius 8, soft shadow).
Menu {
    id: menu
    padding: 6

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }

    background: Rectangle {
        implicitWidth: 200
        radius: Theme.radiusRow
        color: Theme.popup
        border.width: 1
        border.color: Theme.track
    }
}
