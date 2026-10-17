import QtQuick
import QtQuick.Layouts

// Grid of EffectCards ("Playback settings", "Microphone settings").
// `effects`: [{key, intensity: bool, def: int, on: bool}]; texts come from "<key>.title/.desc/.low/.high".
Item {
    id: page

    property string title
    property var effects: []

    PageTitle { id: heading; text: page.title }

    GridLayout {
        anchors.top: heading.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.gutter
        anchors.rightMargin: Theme.gutter
        columns: 2
        columnSpacing: 16
        rowSpacing: 16

        Repeater {
            model: page.effects
            delegate: EffectCard {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                title: Lang.tr(modelData.key + ".title")
                description: Lang.tr(modelData.key + ".desc")
                hasIntensity: modelData.intensity
                lowLabel: modelData.intensity ? Lang.tr(modelData.key + ".low") : ""
                highLabel: modelData.intensity ? Lang.tr(modelData.key + ".high") : ""
                defaultValue: modelData.def || 0
                on: modelData.on || false
            }
        }
    }
}
