import QtQuick
import QtCore

// Product photo of the V9 Pro 2 as used by the MCHOSE HUB. The image is MCHOSE's and is not part
// of the repository: it is read from the app data dir (installed by tools/install-headset-image.py),
// then from the MCHOSE CDN; if neither works, our own drawing (HeadsetArt) is shown.
Item {
    id: root

    property real size: 222

    readonly property var sources: [
        StandardPaths.writableLocation(StandardPaths.AppDataLocation) + "/headset.png",
        "https://cdn.mchose.com.cn/configCenter/static/images/v9pro2Black_78b78392b873.png"
    ]
    property int attempt: 0

    implicitWidth: size
    implicitHeight: size

    Image {
        id: photo
        anchors.fill: parent
        source: root.attempt < root.sources.length ? root.sources[root.attempt] : ""
        sourceSize: Qt.size(640, 640)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        onStatusChanged: if (status === Image.Error) root.attempt++
    }

    HeadsetArt {
        anchors.centerIn: parent
        size: root.size * 0.9
        visible: root.attempt >= root.sources.length
    }
}
