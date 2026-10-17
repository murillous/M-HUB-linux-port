import QtQuick
import QtQuick.Layouts

// Playback / microphone effect: title + switch, description, optional intensity slider
// with its two end labels and a reset button. State is local until the PipeWire side exists.
Card {
    id: card

    property string title
    property string description
    property bool hasIntensity: true
    property string lowLabel
    property string highLabel
    property int defaultValue: 0
    property bool on: false
    property int value: defaultValue

    implicitHeight: 200

    RowLayout {
        id: head
        width: parent.width
        Text {
            Layout.fillWidth: true
            text: card.title
            font.family: Theme.font
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: Theme.text
        }
        McSwitch {
            checked: card.on
            onToggled: checked => card.on = checked
        }
    }

    Text {
        anchors.top: head.bottom
        anchors.topMargin: 10
        width: parent.width
        wrapMode: Text.WordWrap
        text: card.description
        font.family: Theme.font
        font.pixelSize: 13
        color: Theme.textDim
    }

    Item {
        visible: card.hasIntensity
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        width: parent.width
        height: 48

        Text {
            id: intensity
            y: 4
            text: Lang.tr("effect.intensity")
            font.family: Theme.font
            font.pixelSize: 13
            color: Theme.textDim
        }

        McSlider {
            id: slider
            x: 80
            width: parent.width - 80 - 76
            height: 24
            from: 0
            to: 100
            stepSize: 1
            enabled: card.on
            opacity: 1
            dim: !card.on
            value: card.value
            onMoved: card.value = value
        }

        // end ticks and labels
        Repeater {
            model: [card.lowLabel, card.highLabel]
            delegate: Item {
                required property string modelData
                required property int index
                x: slider.x + index * slider.width
                y: 28
                Rectangle { x: 0; width: 1; height: 6; color: Theme.textFaint }
                Text {
                    x: -implicitWidth / 2
                    y: 8
                    text: modelData
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.textFaint
                }
            }
        }

        Text {
            anchors.right: reset.left
            anchors.rightMargin: 16
            y: 4
            text: card.value
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: card.on ? Theme.text : Theme.textDim
        }

        Rectangle {
            id: reset
            anchors.right: parent.right
            width: 24
            height: 24
            radius: 4
            color: Theme.divider
            opacity: card.on ? 1 : 0.6
            Icon {
                anchors.centerIn: parent
                name: "undo"
                size: 14
                color: Theme.textDim
            }
            MouseArea {
                anchors.fill: parent
                enabled: card.on
                cursorShape: Qt.PointingHandCursor
                onClicked: card.value = card.defaultValue
            }
        }
    }
}
