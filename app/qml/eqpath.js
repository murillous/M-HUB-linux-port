.pragma library

// Port of ECharts' smooth polyline (smooth = 0.5 with smoothConstraint): control points are
// clamped to the box of each neighbour pair, so peaks flatten instead of overshooting.
// `pts` is [[x, y], ...]; the path is added to `ctx` starting with moveTo.
function trace(ctx, pts) {
    const smooth = 0.5
    ctx.moveTo(pts[0][0], pts[0][1])
    let cpx0 = pts[0][0], cpy0 = pts[0][1]
    for (let i = 1; i < pts.length; i++) {
        const prevX = pts[i - 1][0], prevY = pts[i - 1][1]
        const x = pts[i][0], y = pts[i][1]
        let cpx1 = x, cpy1 = y, nextCpx0 = x, nextCpy0 = y
        if (i < pts.length - 1) {
            const nextX = pts[i + 1][0], nextY = pts[i + 1][1]
            let vx = nextX - prevX, vy = nextY - prevY
            const lenPrev = Math.hypot(x - prevX, y - prevY)
            const lenNext = Math.hypot(nextX - x, nextY - y)
            const ratio = lenNext / (lenNext + lenPrev)
            nextCpx0 = x + vx * smooth * ratio
            nextCpy0 = y + vy * smooth * ratio
            nextCpx0 = Math.max(Math.min(nextCpx0, Math.max(nextX, x)), Math.min(nextX, x))
            nextCpy0 = Math.max(Math.min(nextCpy0, Math.max(nextY, y)), Math.min(nextY, y))
            vx = nextCpx0 - x
            vy = nextCpy0 - y
            cpx1 = x - vx * lenPrev / lenNext
            cpy1 = y - vy * lenPrev / lenNext
            cpx1 = Math.max(Math.min(cpx1, Math.max(prevX, x)), Math.min(prevX, x))
            cpy1 = Math.max(Math.min(cpy1, Math.max(prevY, y)), Math.min(prevY, y))
            vx = x - cpx1
            vy = y - cpy1
            nextCpx0 = x + vx * lenNext / lenPrev
            nextCpy0 = y + vy * lenNext / lenPrev
        }
        ctx.bezierCurveTo(cpx0, cpy0, cpx1, cpy1, x, y)
        cpx0 = nextCpx0
        cpy0 = nextCpy0
    }
}

function formatGain(v) {
    return (v > 0 ? "+" : "") + v.toFixed(1)
}

function formatFreq(fc) {
    return fc >= 1000 ? (fc / 1000) + "KHz" : fc + "Hz"
}
