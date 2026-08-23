import SwiftUI

/// Pure rendering: everything here is a function of the state handed in plus the
/// timeline's current date. No drawing pass ever mutates state.
struct SkyCanvas: View {
    let stars: [Star]
    /// Every line, in order. The active one is drawn brightest.
    let constellations: [[Star]]
    var activeLine = 0
    let pulses: [Pulse]
    let shooters: [Shooter]
    let birth: Date
    /// The star assistive navigation is sitting on, drawn as a ring.
    var cursor: Star?
    /// Reduce Motion: the sky holds still. Pulses stay — they are brief
    /// feedback for something you just did, not ambient movement.
    var isStill = false

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let elapsed = isStill ? 0 : now.timeIntervalSince(birth)

            Canvas(opaque: true, rendersAsynchronously: false) { context, size in
                drawNight(in: context, size: size)
                drawShooters(in: context, size: size, now: now)
                drawStars(in: context, size: size, elapsed: elapsed)
                drawConstellations(in: context, size: size)
                drawCursor(in: context, size: size)
                drawPulses(in: context, size: size, now: now)
            }
        }
    }

    // MARK: - Layers

    private func drawNight(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(Gradient(colors: [Palette.nightTop, Palette.nightBottom]),
                                  startPoint: .zero,
                                  endPoint: CGPoint(x: 0, y: size.height))
        )
        let glow = CGRect(x: size.width * 0.2, y: size.height * 0.1,
                          width: size.width, height: size.width)
        context.fill(
            Path(ellipseIn: glow),
            with: .radialGradient(Gradient(colors: [Palette.nebula.opacity(0.08), .clear]),
                                  center: CGPoint(x: size.width * 0.7, y: size.height * 0.35),
                                  startRadius: 0,
                                  endRadius: size.width * 0.5)
        )
    }

    private func drawShooters(in context: GraphicsContext, size: CGSize, now: Date) {
        for shooter in shooters {
            let life = shooter.life(at: now)
            guard life > 0 else { continue }
            let head = shooter.position(at: now)
            let tailLength = 0.06
            let tail = CGPoint(x: head.x - shooter.velocity.dx * tailLength,
                               y: head.y - shooter.velocity.dy * tailLength)
            var path = Path()
            path.move(to: CGPoint(x: head.x * size.width, y: head.y * size.height))
            path.addLine(to: CGPoint(x: tail.x * size.width, y: tail.y * size.height))
            context.stroke(path,
                           with: .linearGradient(
                               Gradient(colors: [.white.opacity(life * 0.85), .clear]),
                               startPoint: CGPoint(x: head.x * size.width, y: head.y * size.height),
                               endPoint: CGPoint(x: tail.x * size.width, y: tail.y * size.height)),
                           style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
    }

    private func drawStars(in context: GraphicsContext, size: CGSize, elapsed: Double) {
        for star in stars {
            let twinkle = star.twinkle(at: elapsed)
            let radius = star.drawnRadius
            let point = star.point(in: size)
            let color = star.isProminent
                ? Palette.gold.opacity(twinkle)
                : Palette.starlight.opacity(twinkle * 0.8)

            if star.isProminent {
                let halo = radius * 3.2
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - halo, y: point.y - halo,
                                           width: halo * 2, height: halo * 2)),
                    with: .radialGradient(
                        Gradient(colors: [Palette.gold.opacity(twinkle * 0.22), .clear]),
                        center: point, startRadius: 0, endRadius: halo)
                )
            }

            context.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(color)
            )
        }
    }

    private func drawConstellations(in context: GraphicsContext, size: CGSize) {
        for (index, line) in constellations.enumerated() where line.count > 1 {
            let colour = Palette.line(index)
            let isActive = index == activeLine
            var path = Path()
            path.move(to: line[0].point(in: size))
            for star in line.dropFirst() { path.addLine(to: star.point(in: size)) }

            var glowing = context
            glowing.addFilter(.shadow(color: colour.opacity(isActive ? 0.9 : 0.5),
                                      radius: isActive ? 8 : 5))
            glowing.stroke(path,
                           with: .color(colour.opacity(isActive ? 0.7 : 0.42)),
                           style: StrokeStyle(lineWidth: isActive ? 1.5 : 1.2,
                                              lineCap: .round, lineJoin: .round))
        }
    }

    /// Where star-by-star navigation is. Visible to everyone — it is also how
    /// someone using Switch Control or a keyboard sees where they are.
    private func drawCursor(in context: GraphicsContext, size: CGSize) {
        guard let cursor else { return }
        let point = cursor.point(in: size)
        let radius = max(cursor.drawnRadius * 2.6, 13)
        context.stroke(
            Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                   width: radius * 2, height: radius * 2)),
            with: .color(Palette.mist.opacity(0.9)),
            style: StrokeStyle(lineWidth: 1.6, dash: [3, 3])
        )
    }

    private func drawPulses(in context: GraphicsContext, size: CGSize, now: Date) {
        for pulse in pulses {
            let progress = pulse.progress(at: now)
            guard progress >= 0, progress < 1 else { continue }
            let radius = 6 + progress * 40
            let center = CGPoint(x: pulse.position.x * size.width,
                                 y: pulse.position.y * size.height)
            let color = (pulse.line.map(Palette.line) ?? Palette.mist).opacity(1 - progress)
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(color),
                lineWidth: 2
            )
        }
    }
}
