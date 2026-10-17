import QtQuick
import "eqpath.js" as EqPath

// EQ editor chart, rebuilt after the MCHOSE HUB one (ECharts line series, see docs/04):
// ten evenly spaced points, smooth curve, area gradient that fades out at 0 dB,
// drag a point to set its gain, mouse wheel on a point = ±0.1 dB, tooltip with the value.
Item {
    id: chart

    property var values: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var labels: []
    property var bandNames: ["Bass", "Mid", "High"]
    property bool interactive: true

    /// Emitted once before a drag or a burst of wheel steps changes `values` (for undo history).
    signal editBegan()
    /// Emitted after every change made by the user.
    signal edited()

    readonly property real minDb: -12
    readonly property real maxDb: 12
    readonly property real step: 0.1
    readonly property real hitRadius: 12

    // Plot area inside the item (matches the original grid: 24 px on the left so the first point and
    // its labels are not clipped, 73 px for the dB labels on the right, 72 px for the frequency
    // labels, 28 px for the Bass/Mid/High row on top). Place the item 24 px left of the content.
    readonly property real plotLeft: 24
    readonly property real plotTop: 28
    readonly property real plotRight: width - 73
    readonly property real plotBottom: height - 72

    property var shown: values.slice()
    property int hoverIndex: -1
    property int dragIndex: -1
    readonly property int activeIndex: dragIndex >= 0 ? dragIndex : hoverIndex

    property var _from: []
    property var _to: []
    property real _t: 1

    function clampDb(v) {
        return Math.round(Math.min(maxDb, Math.max(minDb, Number(v) || 0)) * 10) / 10
    }

    function fmt(v) {
        return EqPath.formatGain(v)
    }

    /// Replaces all values; `animate` morphs the curve like ECharts' update animation (500 ms).
    function setValues(v, animate) {
        const next = v.map(clampDb)
        if (animate && shown.length === next.length) {
            _from = shown.slice()
            _to = next
            values = next
            morph.restart()
        } else {
            morph.stop()
            values = next
            shown = next.slice()
            canvas.requestPaint()
        }
    }

    function setOne(i, v) {
        const x = clampDb(v)
        if (values[i] === x)
            return
        morph.stop()
        const next = values.slice()
        next[i] = x
        values = next
        shown = next.slice()
        canvas.requestPaint()
        edited()
    }

    function px(i) {
        return plotLeft + i * (plotRight - plotLeft) / Math.max(1, shown.length - 1)
    }
    function py(v) {
        return plotTop + (maxDb - v) / (maxDb - minDb) * (plotBottom - plotTop)
    }
    function dbAt(y) {
        return maxDb - (y - plotTop) / (plotBottom - plotTop) * (maxDb - minDb)
    }

    function hitTest(x, y) {
        let best = -1, bestDist = Infinity
        for (let i = 0; i < shown.length; i++) {
            const d = Math.hypot(x - px(i), y - py(shown[i]))
            if (d <= hitRadius && d < bestDist) {
                best = i
                bestDist = d
            }
        }
        return best
    }

    NumberAnimation {
        id: morph
        target: chart
        property: "_t"
        from: 0
        to: 1
        duration: 500
        easing.type: Easing.InOutCubic
    }
    on_TChanged: {
        if (_from.length !== _to.length)
            return
        shown = _from.map((f, i) => f + (_to[i] - f) * _t)
        canvas.requestPaint()
    }
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    // ── Bass / Mid / High row ────────────────────────────────────────
    Row {
        x: chart.plotLeft
        width: chart.plotRight - chart.plotLeft
        height: 16
        Repeater {
            model: chart.bandNames
            delegate: Item {
                required property string modelData
                required property int index
                width: parent.width / chart.bandNames.length
                height: 16
                Rectangle { width: 1; height: parent.height; color: Theme.divider }
                Rectangle {
                    visible: index === chart.bandNames.length - 1
                    anchors.right: parent.right
                    width: 1; height: parent.height; color: Theme.divider
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.textDim
                }
            }
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const L = chart.plotLeft, R = chart.plotRight
            const v = chart.shown
            const font = "12px \"" + Theme.font + "\""

            // grid every 3 dB
            ctx.lineWidth = 1
            ctx.strokeStyle = Theme.divider
            for (let db = chart.minDb; db <= chart.maxDb; db += 3) {
                const y = Math.round(chart.py(db)) + 0.5
                ctx.beginPath(); ctx.moveTo(L, y); ctx.lineTo(R, y); ctx.stroke()
            }

            // dB labels on the right, every 6 dB
            ctx.font = font
            ctx.fillStyle = Theme.textDim
            ctx.textAlign = "left"
            ctx.textBaseline = "middle"
            for (let db = chart.minDb; db <= chart.maxDb; db += 6)
                ctx.fillText((db > 0 ? "+" : "") + db + " dB", R + 24, chart.py(db))

            // frequency labels
            ctx.textAlign = "center"
            for (let i = 0; i < chart.labels.length && i < v.length; i++)
                ctx.fillText(chart.labels[i], chart.px(i), chart.plotBottom + 40)

            if (v.length < 2)
                return
            const pts = v.map((g, i) => [chart.px(i), chart.py(g)])
            const y0 = chart.py(0)

            // area between the curve and 0 dB; alpha 0.2 at the extremes, 0 at the zero line
            const hi = Math.max(...v), lo = Math.min(...v)
            const top = chart.py(Math.max(hi, 0)), bottom = chart.py(Math.min(lo, 0))
            const grad = ctx.createLinearGradient(0, top, 0, Math.max(bottom, top + 1))
            const a20 = "rgba(34, 107, 238, 0.2)", a0 = "rgba(34, 107, 238, 0)"
            if (lo >= 0) {
                grad.addColorStop(0, a20); grad.addColorStop(1, a0)
            } else if (hi <= 0) {
                grad.addColorStop(0, a0); grad.addColorStop(1, a20)
            } else {
                grad.addColorStop(0, a20); grad.addColorStop(hi / (hi - lo), a0); grad.addColorStop(1, a20)
            }
            ctx.beginPath()
            EqPath.trace(ctx, pts)
            ctx.lineTo(pts[pts.length - 1][0], y0)
            ctx.lineTo(pts[0][0], y0)
            ctx.closePath()
            ctx.fillStyle = grad
            ctx.fill()

            // dashed accent line at 0 dB
            ctx.save()
            ctx.strokeStyle = Theme.accent
            ctx.setLineDash([4, 4])
            ctx.lineDashOffset = 4
            ctx.beginPath()
            ctx.moveTo(L, Math.round(y0) + 0.5); ctx.lineTo(R, Math.round(y0) + 0.5)
            ctx.stroke()
            ctx.restore()

            // curve
            ctx.beginPath()
            EqPath.trace(ctx, pts)
            ctx.strokeStyle = Theme.accent
            ctx.lineWidth = 2
            ctx.stroke()

            // points and their values underneath
            ctx.lineWidth = 1
            ctx.textBaseline = "top"
            for (let i = 0; i < pts.length; i++) {
                const [x, y] = pts[i]
                ctx.beginPath()
                ctx.arc(x, y, 8, 0, 2 * Math.PI)
                ctx.fillStyle = Theme.accent
                ctx.fill()
                ctx.strokeStyle = "#ffffff"
                ctx.stroke()
                ctx.fillStyle = Theme.textDim
                ctx.fillText(chart.fmt(Math.round(v[i] * 10) / 10), x, y + 12)
            }
        }
    }

    // ── Tooltip ──────────────────────────────────────────────────────
    Rectangle {
        id: tip
        readonly property real pointX: chart.activeIndex >= 0 ? chart.px(chart.activeIndex) : 0
        readonly property real pointY: chart.activeIndex >= 0 ? chart.py(chart.shown[chart.activeIndex]) : 0
        width: tipText.implicitWidth + 32
        height: tipText.implicitHeight + 32
        radius: 4
        color: Theme.popup
        opacity: chart.activeIndex >= 0 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 100 } }

        x: {
            let x = pointX - width - 16
            if (x < 16) x = pointX + 16
            return Math.min(x, chart.width - width - 16)
        }
        y: Math.max(16, Math.min(pointY - height / 2, chart.height - height - 16))
        Behavior on x { enabled: chart.dragIndex < 0; NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
        Behavior on y { enabled: chart.dragIndex < 0; NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

        Text {
            id: tipText
            anchors.centerIn: parent
            text: chart.activeIndex >= 0 ? chart.fmt(Math.round(chart.shown[chart.activeIndex] * 10) / 10) + " dB" : ""
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.text
        }
    }

    // ── Interaction ──────────────────────────────────────────────────
    Timer {
        id: wheelSession
        interval: 220
    }

    MouseArea {
        anchors.fill: parent
        enabled: chart.interactive
        hoverEnabled: true
        cursorShape: chart.activeIndex >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPressed: mouse => {
            const i = chart.hitTest(mouse.x, mouse.y)
            if (i < 0)
                return
            chart.editBegan()
            chart.dragIndex = i
        }
        onPositionChanged: mouse => {
            if (chart.dragIndex >= 0)
                chart.setOne(chart.dragIndex, chart.dbAt(mouse.y))
            else
                chart.hoverIndex = chart.hitTest(mouse.x, mouse.y)
        }
        onReleased: mouse => {
            chart.dragIndex = -1
            chart.hoverIndex = chart.hitTest(mouse.x, mouse.y)
        }
        onExited: if (chart.dragIndex < 0) chart.hoverIndex = -1
        onWheel: wheel => {
            const i = chart.hoverIndex
            if (i < 0 || wheel.angleDelta.y === 0) {
                wheel.accepted = false
                return
            }
            if (!wheelSession.running)
                chart.editBegan()
            wheelSession.restart()
            chart.setOne(i, chart.values[i] + (wheel.angleDelta.y > 0 ? chart.step : -chart.step))
        }
    }
}
