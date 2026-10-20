import QtQuick
import QtQuick.Layouts

// Grid of EffectCards ("Playback settings", "Microphone settings").
// `effects`: [{key, intensity: bool, def: int, on: bool}]; texts come from "<key>.title/.desc/.low/.high".
// `controlled`: {key: {on, enabled, note}} for effects whose state lives outside the page;
// clicking their switch only emits `switched`.
Item {
    id: page

    property string title
    property var effects: []
    property var controlled: ({})

    signal switched(string key, bool on)

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
                readonly property var ctl: page.controlled[modelData.key]
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                title: Lang.tr(modelData.key + ".title")
                description: Lang.tr(modelData.key + ".desc")
                hasIntensity: modelData.intensity
                lowLabel: modelData.intensity ? Lang.tr(modelData.key + ".low") : ""
                highLabel: modelData.intensity ? Lang.tr(modelData.key + ".high") : ""
                defaultValue: modelData.def || 0
                on: ctl ? ctl.on : (modelData.on || false)
                controlled: ctl !== undefined
                switchEnabled: ctl ? ctl.enabled : true
                note: ctl ? ctl.note : ""
                onSwitched: on => page.switched(modelData.key, on)
            }
        }
    }
}
