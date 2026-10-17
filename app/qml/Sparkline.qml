import QtQuick
import "eqpath.js" as EqPath

// Mini EQ curve for preset cards (88×46 in the original).
Canvas {
    id: spark

    property var values: []
    property real rangeDb: 12
    property color color: Theme.textDim

    implicitWidth: 88
    implicitHeight: 46
    onValuesChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (values.length < 2)
            return
        const pad = 3
        const pts = values.map((v, i) => [
            pad + i * (width - 2 * pad) / (values.length - 1),
            height / 2 - v / rangeDb * (height / 2 - pad)
        ])
        ctx.beginPath()
        EqPath.trace(ctx, pts)
        ctx.strokeStyle = color
        ctx.lineWidth = 1
        ctx.stroke()
    }
}
