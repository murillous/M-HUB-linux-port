import QtQuick

// Panel title ("Common parameters", "Playback settings"…), 16 px semibold at the top-left.
Text {
    x: Theme.gutter
    height: 60
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: 16
    font.weight: Font.DemiBold
    color: Theme.text
}
