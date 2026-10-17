import QtQuick
import QtQuick.Shapes

// Stylised headset drawn for this project (stands in for the product photo of the original).
Item {
    id: art

    property real size: 220
    readonly property color gold: "#c9a27a"

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 200
        height: 200
        scale: art.size / 200
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        // floor shadow
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: 100; centerY: 186; centerRadius: 70
                focalX: 100; focalY: 186
                GradientStop { position: 0; color: "#80000000" }
                GradientStop { position: 1; color: "#00000000" }
            }
            PathSvg { path: "M 30 186 a 70 9 0 1 0 140 0 a 70 9 0 1 0 -140 0" }
        }

        // headband
        ShapePath {
            strokeColor: "#262626"
            strokeWidth: 15
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 42 104 C 42 26, 158 26, 158 104" }
        }
        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.06)
            strokeWidth: 2
            fillColor: "transparent"
            PathSvg { path: "M 36 100 C 37 20, 163 20, 164 100" }
        }
        ShapePath {
            strokeColor: art.gold
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 2]
            fillColor: "transparent"
            PathSvg { path: "M 48 100 C 48 36, 152 36, 152 100" }
        }

        // sliders
        ShapePath {
            strokeWidth: -1
            fillColor: "#1b1b1b"
            PathSvg { path: "M 34 96 h 16 v 20 h -16 z M 150 96 h 16 v 20 h -16 z" }
        }

        // ear cups
        ShapePath {
            strokeColor: "#333333"
            strokeWidth: 1
            fillGradient: LinearGradient {
                x1: 0; y1: 110; x2: 0; y2: 180
                GradientStop { position: 0; color: "#2c2c2c" }
                GradientStop { position: 1; color: "#121212" }
            }
            PathSvg {
                path: "M 18 145 a 24 36 0 1 0 48 0 a 24 36 0 1 0 -48 0"
                    + " M 134 145 a 24 36 0 1 0 48 0 a 24 36 0 1 0 -48 0"
            }
        }
        ShapePath {
            strokeColor: art.gold
            strokeWidth: 3
            fillColor: "transparent"
            PathSvg {
                path: "M 25 145 a 17 28 0 1 0 34 0 a 17 28 0 1 0 -34 0"
                    + " M 141 145 a 17 28 0 1 0 34 0 a 17 28 0 1 0 -34 0"
            }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: "#161616"
            PathSvg {
                path: "M 29 145 a 13 23 0 1 0 26 0 a 13 23 0 1 0 -26 0"
                    + " M 145 145 a 13 23 0 1 0 26 0 a 13 23 0 1 0 -26 0"
            }
        }

        // mic boom
        ShapePath {
            strokeColor: "#1e1e1e"
            strokeWidth: 4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 30 168 C 26 186, 48 192, 70 186" }
        }
        ShapePath {
            strokeColor: "#3a3a3a"
            strokeWidth: 1
            fillColor: "#242424"
            PathSvg { path: "M 66 186 a 6 5 0 1 0 12 0 a 6 5 0 1 0 -12 0" }
        }
    }
}
