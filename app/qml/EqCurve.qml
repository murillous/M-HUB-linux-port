import QtQuick

// Frequency response of the onboard parametric EQ (sum of peaking biquads, RBJ cookbook).
// Filter type 0 is assumed to be "peaking" [inf].
Canvas {
    id: canvas

    property var points: []
    property color lineColor: theme.accent
    property real rangeDb: 12
    readonly property real fs: 48000

    onPointsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function responseDb(f) {
        let total = 0
        const w = 2 * Math.PI * f / fs
        const cw = Math.cos(w), sw = Math.sin(w), c2 = Math.cos(2 * w), s2 = Math.sin(2 * w)
        for (const p of points) {
            if (!p.enable || p.gain === 0) continue
            const A = Math.pow(10, p.gain / 40)
            const w0 = 2 * Math.PI * p.fc / fs
            const alpha = Math.sin(w0) / (2 * Math.max(p.q, 0.1))
            const b0 = 1 + alpha * A, b1 = -2 * Math.cos(w0), b2 = 1 - alpha * A
            const a0 = 1 + alpha / A, a1 = b1, a2 = 1 - alpha / A
            const nr = b0 + b1 * cw + b2 * c2, ni = -(b1 * sw + b2 * s2)
            const dr = a0 + a1 * cw + a2 * c2, di = -(a1 * sw + a2 * s2)
            total += 10 * Math.log10((nr * nr + ni * ni) / (dr * dr + di * di))
        }
        return total
    }

    function xOf(f) { return width * Math.log(f / 20) / Math.log(20000 / 20) }
    function yOf(db) { return height / 2 - db / rangeDb * (height / 2 - 6) }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()

        // grid
        ctx.strokeStyle = theme.grid
        ctx.lineWidth = 1
        ctx.font = "10px sans-serif"
        ctx.fillStyle = theme.textDim
        for (const f of [50, 100, 200, 500, 1000, 2000, 5000, 10000]) {
            const x = Math.round(xOf(f)) + 0.5
            ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
            ctx.fillText(f >= 1000 ? (f / 1000) + "k" : f, x + 3, height - 4)
        }
        for (const db of [-rangeDb, -rangeDb / 2, 0, rangeDb / 2, rangeDb]) {
            const y = Math.round(yOf(db)) + 0.5
            ctx.globalAlpha = db === 0 ? 1 : 0.6
            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
        }
        ctx.globalAlpha = 1
        if (points.length === 0) return

        // curve + fill
        const steps = Math.max(64, Math.floor(width / 3))
        const path = []
        for (let i = 0; i <= steps; i++) {
            const f = 20 * Math.pow(1000, i / steps)
            path.push([xOf(f), yOf(Math.max(-rangeDb, Math.min(rangeDb, responseDb(f))))])
        }
        const grad = ctx.createLinearGradient(0, 0, 0, height)
        grad.addColorStop(0, Qt.alpha(lineColor, 0.35))
        grad.addColorStop(1, Qt.alpha(lineColor, 0))
        ctx.beginPath()
        ctx.moveTo(path[0][0], yOf(0))
        for (const [x, y] of path) ctx.lineTo(x, y)
        ctx.lineTo(path[path.length - 1][0], yOf(0))
        ctx.closePath()
        ctx.fillStyle = grad
        ctx.fill()

        ctx.beginPath()
        ctx.moveTo(path[0][0], path[0][1])
        for (const [x, y] of path) ctx.lineTo(x, y)
        ctx.strokeStyle = lineColor
        ctx.lineWidth = 2.5
        ctx.stroke()

        // band markers
        for (const p of points) {
            if (!p.enable) continue
            ctx.beginPath()
            ctx.arc(xOf(p.fc), yOf(Math.max(-rangeDb, Math.min(rangeDb, p.gain))), 4, 0, 2 * Math.PI)
            ctx.fillStyle = theme.surface
            ctx.fill()
            ctx.strokeStyle = lineColor
            ctx.lineWidth = 2
            ctx.stroke()
        }
    }
}
