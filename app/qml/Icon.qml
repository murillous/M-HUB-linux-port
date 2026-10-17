import QtQuick
import QtQuick.Shapes

// Line icons drawn for this project (24×24 viewBox, stroked). Not taken from the MCHOSE app.
Item {
    id: icon

    property string name
    property color color: Theme.text
    property real size: 20
    property real stroke: 1.6
    property bool filled: false

    implicitWidth: size
    implicitHeight: size

    readonly property var paths: ({
        "sliders": "M4 7h9 M17 7h3 M4 17h3 M11 17h9 M15 4.5v5 M9 14.5v5 M4 12h5 M13 12h7",
        "wave": "M4 10v4 M7.5 7v10 M11 4v16 M14.5 8v8 M18 6v12 M21 10.5v3",
        "mic": "M12 3a3 3 0 0 1 3 3v6a3 3 0 0 1 -6 0v-6a3 3 0 0 1 3 -3z M5.5 11.5a6.5 6.5 0 0 0 13 0 M12 18v3",
        "hexagon": "M12 2.8l8 4.6v9.2l-8 4.6l-8 -4.6v-9.2z M12 9a3 3 0 1 1 0 6a3 3 0 1 1 0 -6z",
        "battery": "M9.5 3.5h5 M8 5.5h8a1.5 1.5 0 0 1 1.5 1.5v12a1.5 1.5 0 0 1 -1.5 1.5h-8a1.5 1.5 0 0 1 -1.5 -1.5v-12a1.5 1.5 0 0 1 1.5 -1.5z",
        "wifi": "M3.5 9.5a12 12 0 0 1 17 0 M6.5 12.8a7.7 7.7 0 0 1 11 0 M9.5 16a3.4 3.4 0 0 1 5 0 M12 19.2v0.1",
        "cable": "M9 3v4 M15 3v4 M7 7h10v4a5 5 0 0 1 -10 0z M12 16v5",
        "eq": "M6 4v16 M12 4v16 M18 4v16 M4 14h4 M10 8h4 M16 16h4",
        "undo": "M9 14l-5 -5l5 -5 M4 9h10.5a5.5 5.5 0 0 1 0 11h-3.5",
        "redo": "M15 14l5 -5l-5 -5 M20 9h-10.5a5.5 5.5 0 0 0 0 11h3.5",
        "restore": "M4 4v5h5 M4.6 15a8 8 0 1 0 1.2 -8l-1.8 2",
        "chevronDown": "M6 9l6 6l6 -6",
        "chevronUp": "M6 15l6 -6l6 6",
        "pencil": "M4 20h4l11 -11a2.8 2.8 0 0 0 -4 -4l-11 11z M13.5 6.5l4 4",
        "help": "M12 3a9 9 0 1 1 0 18a9 9 0 1 1 0 -18z M9.6 9.5a2.5 2.5 0 1 1 3.4 2.3c-0.6 0.3 -1 0.8 -1 1.5v0.7 M12 16.6v0.1",
        "speaker": "M4 9.5h3.5l4.5 -4v13l-4.5 -4h-3.5z M15.5 9a4 4 0 0 1 0 6 M18 6.5a7.5 7.5 0 0 1 0 11",
        "refresh": "M20 11a8 8 0 0 0 -14.6 -4.4 M4 4v3.5h3.5 M4 13a8 8 0 0 0 14.6 4.4 M20 20v-3.5h-3.5",
        "globe": "M12 3a9 9 0 1 1 0 18a9 9 0 1 1 0 -18z M3 12h18 M12 3c-2.6 2.6 -3.6 5.6 -3.6 9s1 6.4 3.6 9 M12 3c2.6 2.6 3.6 5.6 3.6 9s-1 6.4 -3.6 9",
        "check": "M5 12.5l4.5 4.5l9.5 -10",
        "save": "M5 4h11l3 3v12a1 1 0 0 1 -1 1h-12a1 1 0 0 1 -1 -1v-14a1 1 0 0 1 1 -1z M8 4v4h7v-4 M8 20v-6h8v6",
        "flat": "M3 12h18",
        "note": "M9 18v-12l11 -2v12 M9 18a3 3 0 1 1 -6 0a3 3 0 1 1 6 0z M20 16a3 3 0 1 1 -6 0a3 3 0 1 1 6 0z",
        "target": "M12 3a9 9 0 1 1 0 18a9 9 0 1 1 0 -18z M12 8a4 4 0 1 1 0 8a4 4 0 1 1 0 -8z M12 1v4 M12 19v4 M1 12h4 M19 12h4",
        "voice": "M12 3a3 3 0 0 1 3 3v5a3 3 0 0 1 -6 0v-5a3 3 0 0 1 3 -3z M4 10v1 M20 10v1 M7 8v5 M17 8v5",
        "bass": "M4 16c2 -6 4 -9 6 -9s3 5 5 5s3 -2 5 -4",
        "treble": "M4 14c3 0 5 1 7 1s3 -7 5 -9s3 1 4 3"
    })

    Shape {
        width: 24
        height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: icon.color
            strokeWidth: icon.stroke
            fillColor: icon.filled ? icon.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.paths[icon.name] || "" }
        }
    }
}
