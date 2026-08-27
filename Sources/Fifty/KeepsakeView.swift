import Combine
import SwiftUI

/// One screen, and nothing to navigate.
///
/// Her name, a spiral of fifty stars, and a card that says what a year held.
/// Touch a star and it sings the note it sits at and opens its year; press play
/// and the whole life runs past in order. Everything here is Starsong's — the
/// same canvas, the same five voices, the same rule that height is pitch — so
/// this is a room built out of the house rather than a second house.
struct KeepsakeView: View {
    /// Set when the keepsake is shown over Starsong. `nil` when it *is* the
    /// app, in which case there is nowhere to close it to.
    let onClose: (() -> Void)?

    /// Written out rather than left to the memberwise initialiser, which a
    /// `private` piece of state makes private too — and then Starsong cannot
    /// open the keepsake from the next file over.
    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    @State private var model = KeepsakeModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let birth = Date()

    private let heartbeat = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                sky(in: geo.size)
                overlay
            }
            .onAppear { model.greet() }
            .onReceive(heartbeat) { now in model.advance(to: now) }
            .background(Palette.nightTop)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .light), trigger: model.showing)
        .onDisappear { model.stop() }
    }

    // MARK: - The sky

    /// Split out of `body` for the reason `ContentView` splits its own: the
    /// gesture and the accessibility surface inline defeat the type checker.
    private func sky(in size: CGSize) -> some View {
        SkyCanvas(stars: model.stars,
                  constellations: [model.stars],
                  pulses: model.pulses,
                  shooters: [],
                  birth: birth,
                  cursor: model.cursor,
                  isStill: reduceMotion)
            .contentShape(Rectangle())
            // A drag rather than a tap, so running a finger round the spiral
            // plays the years it passes — the gesture Starsong draws with.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { model.touch(at: $0.location, in: size) }
            )
            .modifier(KeepsakeAccessibility(model: model, announce: announce))
    }

    /// Focus stays on the sky as she moves through the years, so what arrived
    /// has to be spoken rather than left to a value nobody is listening for.
    private func announce() {
        guard let year = model.year else { return }
        AccessibilityNotification.Announcement(year.spoken).post()
    }

    // MARK: - Chrome

    private var overlay: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 12)
            card
            controls
        }
        .foregroundStyle(Palette.ink)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .animation(.easeInOut(duration: 0.45), value: model.showing)
        .animation(.easeInOut(duration: 0.45), value: model.read.count)
    }

    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                Button { model.sing() } label: {
                    Text(model.name)
                        .font(.system(size: 40, weight: .light, design: .serif))
                        .foregroundStyle(Palette.gold)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(model.name)
                .accessibilityHint("Plays the melody of her name.")

                Spacer()

                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(9)
                            .background(Color.white.opacity(0.08), in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.18)))
                            .foregroundStyle(Palette.ink.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }

            HStack {
                Text(model.caption)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(Palette.ink.opacity(0.35))
                Spacer()
            }
        }
        .padding(.top, 60)
        .padding(.horizontal, 22)
    }

    @ViewBuilder
    private var card: some View {
        if let year = model.year {
            YearCard(year: year)
                .id(year.age)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else if model.isComplete {
            Text(Keepsake.closing)
                .font(.system(size: 17, design: .serif))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Palette.gold)
                .padding(.horizontal, 30)
                .padding(.bottom, 18)
                .transition(.opacity)
        } else {
            Text("\(model.life.count) stars, one for every year.\nTouch one.")
                .font(.system(size: 15).leading(.standard))
                .multilineTextAlignment(.center)
                .opacity(0.6)
                .padding(.horizontal, 30)
                .padding(.bottom, 18)
                .transition(.opacity)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            PillButton("Her name") { model.sing() }
            PillButton(model.isPlaying ? "Stop" : "Play her life", isPrimary: true) {
                model.isPlaying ? model.stop() : model.play()
            }
        }
        .padding(.bottom, 36)
        .padding(.horizontal, 12)
    }
}

/// A year, as she reads it.
private struct YearCard: View {
    let year: Keepsake.Year

    var body: some View {
        VStack(spacing: 8) {
            Text(year.heading)
                .font(.system(size: 13, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(Palette.gold.opacity(0.75))
            if year.hasLine {
                Text(year.line)
                    .font(.system(size: 19, design: .serif).leading(.standard))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Still to be written.")
                    .font(.system(size: 17, design: .serif))
                    .opacity(0.4)
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 18)
    }
}

/// The sky is a `Canvas`, so VoiceOver sees one rectangle. Exposing fifty
/// separate elements would technically expose every year, and nobody swipes
/// through fifty dots to find 1996.
///
/// So it is one adjustable element that walks the years in order — swipe up for
/// the next year, down for the one before — sounding and reading each as it
/// arrives. This is the same shape `SkyAccessibility` gives the main sky, for
/// the same reason.
struct KeepsakeAccessibility: ViewModifier {
    let model: KeepsakeModel
    let announce: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityElement()
            .accessibilityLabel("\(model.name)'s sky")
            .accessibilityValue(model.spoken)
            .accessibilityHint("Swipe up or down to move through the years and hear each one. Double tap to read the year again.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: step(1)
                case .decrement: step(-1)
                @unknown default: break
                }
            }
            .accessibilityAction { announce() }
            // The same moves again as named actions: adjustable is the better
            // gesture, but only if you think to try it, and a named action can
            // be found by reading the rotor.
            .accessibilityAction(named: "Next year") { step(1) }
            .accessibilityAction(named: "Previous year") { step(-1) }
            .accessibilityAction(named: "Read this year") { announce() }
    }

    private func step(_ move: Int) {
        model.step(by: move)
        announce()
    }
}

#Preview {
    KeepsakeView(onClose: {})
}
