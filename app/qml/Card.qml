import QtQuick

// Card inside the main panel: #1a1a1b, radius 12, padding 24.
Rectangle {
    id: card

    property int padding: Theme.gutter
    default property alias content: body.data

    radius: Theme.radiusPanel
    color: Theme.card

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: card.padding
    }
}
