import SwiftUI

/// A kept constellation drawn on its own, scaled to fill the space it's given.
/// Used in the log and on the share card.
struct ConstellationThumbnail: View {
    /// The lines, each in order.
    let constellations: [[Star]]
    /// The rest of the sky, drawn dimly behind it. Empty at small sizes.
    var field: [Star] = []
    var lineWidth: CGFloat = 1.2
    var nodeRadius: CGFloat = 2.4

    init(constellations: [[Star]], field: [Star] = [], lineWidth: CGFloat = 1.2, nodeRadius: CGFloat = 2.4) {
        self.constellations = constellations
        self.field = field
        self.lineWidth = lineWidth
        self.nodeRadius = nodeRadius
    }

    init(sky: SavedSky, showsField: Bool = false, lineWidth: CGFloat = 1.2, nodeRadius: CGFloat = 2.4) {
        self.init(constellations: sky.constellations,
                  field: showsField ? sky.stars.filter { !$0.isLit } : [],
                  lineWidth: lineWidth,
                  nodeRadius: nodeRadius)
    }

    var body: some View {
        Canvas { context, size in
            let inset = nodeRadius * 3 + 6
            // One transform for every line, so their positions stay true to
            // each other rather than each being fitted on its own.
            guard let frame = Self.transform(for: constellations.flatMap { $0 },
                                             in: size, inset: inset) else { return }
            drawField(in: context, size: size, frame: frame)

            for (index, stars) in constellations.enumerated() where stars.count > 1 {
                let colour = Palette.line(index)
                let points = stars.map(frame.point)

                var line = Path()
                line.move(to: points[0])
                for point in points.dropFirst() { line.addLine(to: point) }

                var glowing = context
                glowing.addFilter(.shadow(color: colour.opacity(0.8), radius: lineWidth * 5))
                glowing.stroke(line,
                               with: .color(colour.opacity(0.75)),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                for point in points {
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x - nodeRadius, y: point.y - nodeRadius,
                                               width: nodeRadius * 2, height: nodeRadius * 2)),
                        with: .color(colour)
                    )
                }
            }
        }
    }

    /// The neighbours the figure was actually drawn among, dimmed. Uses the
    /// same transform as the constellation, so the card is a window onto that
    /// patch of sky rather than two unrelated coordinate spaces stacked up.
    private func drawField(in context: GraphicsContext, size: CGSize, frame: Layout) {
        let bounds = CGRect(origin: .zero, size: size)
        for star in field {
            let point = frame.point(star)
            guard bounds.contains(point) else { continue }
            let r = star.radius * 0.9
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                with: .color(Palette.starlight.opacity(0.45))
            )
        }
    }

    /// Maps sky fractions into the space the thumbnail was given.
    struct Layout {
        let scale: CGFloat
        let origin: CGPoint
        let minX: CGFloat
        let minY: CGFloat

        func point(_ star: Star) -> CGPoint {
            CGPoint(x: origin.x + (star.x - minX) * scale,
                    y: origin.y + (star.y - minY) * scale)
        }
    }

    /// Fits the constellation's bounding box into `size`, preserving its shape.
    /// A perfectly straight line has a zero-width box, so both axes get a floor.
    static func transform(for stars: [Star], in size: CGSize, inset: CGFloat) -> Layout? {
        guard !stars.isEmpty else { return nil }
        let xs = stars.map(\.x), ys = stars.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let spanX = max(maxX - minX, 0.0001)
        let spanY = max(maxY - minY, 0.0001)

        let box = CGSize(width: max(size.width - inset * 2, 1),
                         height: max(size.height - inset * 2, 1))
        let scale = min(box.width / spanX, box.height / spanY)
        let drawn = CGSize(width: spanX * scale, height: spanY * scale)

        return Layout(scale: scale,
                      origin: CGPoint(x: (size.width - drawn.width) / 2,
                                      y: (size.height - drawn.height) / 2),
                      minX: minX,
                      minY: minY)
    }

    static func layout(_ stars: [Star], in size: CGSize, inset: CGFloat) -> [CGPoint] {
        guard let frame = transform(for: stars, in: size, inset: inset) else { return [] }
        return stars.map(frame.point)
    }
}
