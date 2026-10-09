import SwiftUI

enum GraphViewport {
    static let scaleRange: ClosedRange<CGFloat> = 0.15...2.5
    static func bounds(positions: [CGPoint]) -> CGRect {
        guard let first = positions.first else { return .zero }
        let firstCard = CGRect(x: first.x - 110, y: first.y - 49, width: 220, height: 98)
        return positions.dropFirst().reduce(firstCard) { rect, point in
            rect.union(CGRect(x: point.x - 110, y: point.y - 49, width: 220, height: 98))
        }
    }
    static func fit(bounds: CGRect, viewport: CGSize) -> (scale: CGFloat, offset: CGSize) {
        guard bounds.width > 0, bounds.height > 0, viewport.width > 0, viewport.height > 0 else { return (1, .zero) }
        let widthScale = (viewport.width - 80) / bounds.width
        let heightScale = (viewport.height - 100) / bounds.height
        let scale = min(1, max(scaleRange.lowerBound, min(widthScale, heightScale)))
        return (scale, CGSize(width: viewport.width / 2 - bounds.midX * scale, height: viewport.height / 2 - bounds.midY * scale))
    }
    static func zoomOffset(from oldScale: CGFloat, to newScale: CGFloat, offset: CGSize, anchor: CGPoint) -> CGSize {
        let ratio = newScale / oldScale
        return CGSize(width: anchor.x - (anchor.x - offset.width) * ratio,
                      height: anchor.y - (anchor.y - offset.height) * ratio)
    }
    /// Include the source when both cards fit at a readable scale. Distant
    /// branches must not force a huge zoom-out or move the current card offscreen.
    static func follow(target: CGPoint, source: CGPoint?, viewport: CGSize) -> (scale: CGFloat, offset: CGSize) {
        let scale = min(0.9, max(0.1, min((viewport.width - 48) / 220, (viewport.height - 48) / 98)))
        var center = target
        if let source {
            let related = bounds(positions: [source, target])
            if related.width * scale <= viewport.width - 48, related.height * scale <= viewport.height - 48 {
                center = CGPoint(x: related.midX, y: related.midY)
            }
        }
        return (scale, CGSize(width: viewport.width / 2 - center.x * scale, height: viewport.height / 2 - center.y * scale))
    }
    /// Routes reversed edges around the cards rather than folding them into a loop.
    static func edgeControlPoints(start: CGPoint, end: CGPoint, mode: GraphLayoutMode) -> (control1: CGPoint, control2: CGPoint) {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y

        switch mode {
        case .horizontal:
            if deltaX > 0 {
                // Give tall branches a wider bend.
                let dx = min(deltaX * 0.85, max(30, deltaX / 2 + min(60, abs(deltaY) * 0.12)))
                return (
                    CGPoint(x: start.x + dx, y: start.y),
                    CGPoint(x: end.x - dx, y: end.y)
                )
            } else {
                // Reversed edges still leave the right side and enter the left.
                let cx = max(40, min(100, abs(deltaX) * 0.2 + 40))
                if abs(deltaY) < 50 {
                    // Bend below cards in the same row.
                    let arc: CGFloat = 70
                    return (
                        CGPoint(x: start.x + cx, y: start.y + arc),
                        CGPoint(x: end.x - cx, y: end.y + arc)
                    )
                } else {
                    let sign: CGFloat = deltaY >= 0 ? 1 : -1
                    let cy = abs(deltaY) * 0.35
                    return (
                        CGPoint(x: start.x + cx, y: start.y + sign * cy),
                        CGPoint(x: end.x - cx, y: end.y - sign * cy)
                    )
                }
            }

        case .waterfall:
            if deltaY > 0 {
                // Give wide branches a deeper bend.
                let dy = min(deltaY * 0.85, max(20, deltaY / 2 + min(50, abs(deltaX) * 0.12)))
                return (
                    CGPoint(x: start.x, y: start.y + dy),
                    CGPoint(x: end.x, y: end.y - dy)
                )
            } else {
                // Reversed edges leave the bottom and enter the top.
                let cy = max(30, min(80, abs(deltaY) * 0.2 + 30))
                if abs(deltaX) < 50 {
                    // Bend to the right of cards in the same column.
                    let arc: CGFloat = 70
                    return (
                        CGPoint(x: start.x + arc, y: start.y + cy),
                        CGPoint(x: end.x + arc, y: end.y - cy)
                    )
                } else {
                    let sign: CGFloat = deltaX >= 0 ? 1 : -1
                    let cx = abs(deltaX) * 0.35
                    return (
                        CGPoint(x: start.x + sign * cx, y: start.y + cy),
                        CGPoint(x: end.x - sign * cx, y: end.y - cy)
                    )
                }
            }
        }
    }

    static func edgePath(from source: CGPoint, to target: CGPoint, mode: GraphLayoutMode) -> Path {
        var path = Path()
        let start: CGPoint
        let end: CGPoint
        switch mode {
        case .horizontal:
            start = CGPoint(x: source.x + 110, y: source.y)
            end = CGPoint(x: target.x - 110, y: target.y)
        case .waterfall:
            start = CGPoint(x: source.x, y: source.y + 49)
            end = CGPoint(x: target.x, y: target.y - 49)
        }
        let (control1, control2) = edgeControlPoints(start: start, end: end, mode: mode)
        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)
        return path
    }
}
