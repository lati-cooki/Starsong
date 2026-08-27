import Combine
import SwiftUI

struct ContentView: View {
    @State private var model = SkyModel()
    @State private var log = SkyLog()
    /// One sheet at a time. Stacking several `.sheet` modifiers on the same
    /// view does not reliably work — the third one silently never presented —
    /// so which sheet is up is a single piece of state.
    @State private var sheet: Sheet?

    enum Sheet: String, Identifiable {
        case voices, atlas, log, profile
        var id: String { rawValue }
    }
    @State private var skySize: CGSize = .zero
    /// The keepsake is a whole screen of its own rather than a sheet — it is
    /// not a panel of this app, it is a different one wearing the same sky.
    @State private var showingKeepsake = false
    /// Raised when "Name it" would replace a name that was settled on purpose.
    @State private var askBeforeRenaming = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let birth = Date()

    /// Ambient housekeeping — reaping faded effects, launching the occasional
    /// shooting star. The sky animates from the timeline, not from this.
    private let heartbeat = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                sky(in: geo.size)

                overlay
            }
            .onAppear {
                skySize = geo.size
                if model.stars.isEmpty { model.newSky(for: geo.size) }
            }
            .onChange(of: geo.size) { _, size in skySize = size }
            .onChange(of: model.myth) { _, _ in updateKeptStory() }
            .onReceive(heartbeat) { now in
                model.advance(to: now, spawnChance: reduceMotion ? 0 : 0.09)
            }
            .background(Palette.nightTop)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .sensoryFeedback(.impact(weight: .light), trigger: model.connections)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: model.notePulse)
        .sensoryFeedback(.success, trigger: model.myth?.name)
        .confirmationDialog("Replace \(model.myth?.name ?? "this name")?",
                            isPresented: $askBeforeRenaming,
                            titleVisibility: .visible) {
            Button("Ask for a new name") { model.nameIt() }
            Button("Keep this name", role: .cancel) { }
        } message: {
            Text("Claude will suggest a different name and story for this constellation.")
        }
        .fullScreenCover(isPresented: $showingKeepsake) {
            KeepsakeView { showingKeepsake = false }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .voices:
                InstrumentView(current: model.instrument,
                               inUse: model.lines.map(\.instrument)) { voice in
                    model.setInstrument(voice)
                }
            case .atlas:
                AtlasView { figure in model.place(figure, for: skySize) }
            case .log:
                SkyLogView(log: log) { sky in model.restore(sky) }
            case .profile:
                ProfileView()
            }
        }
    }

    // MARK: - The sky itself

    /// Split out from `body` deliberately: with the gesture and the whole
    /// accessibility surface inline, the type checker gives up.
    private func sky(in size: CGSize) -> some View {
        SkyCanvas(stars: model.stars,
                  constellations: model.lines.indices.map { model.stars(on: $0) },
                  activeLine: model.activeLine,
                  pulses: model.pulses,
                  shooters: model.shooters,
                  birth: birth,
                  cursor: model.cursorStar.map { model.stars[$0] },
                  isStill: reduceMotion)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { model.connect(at: $0.location, in: size) }
            )
            .modifier(SkyAccessibility(model: model, announce: announceConnection))
    }

    /// Focus stays on the sky when a star is added, so the change has to be
    /// spoken rather than left to a value update nobody is listening for.
    private func announceConnection(_ didConnect: Bool) {
        guard didConnect, let index = model.path.last else { return }
        let note = Music.noteName(forY: model.stars[index].y, in: model.tuning)
        let count = model.path.count
        AccessibilityNotification.Announcement(
            "\(note) added. \(count) star\(count == 1 ? "" : "s") on the line."
        ).post()
    }

    // MARK: - Chrome

    private var overlay: some View {
        VStack(spacing: 0) {
            title
            tuningCaption
            if model.path.isEmpty { hint }
            Spacer(minLength: 12)
            // The card is also the only place to type a name, so it appears as
            // soon as there is a constellation to name — otherwise a sky with no
            // key and no suggestion offers nowhere to write one.
            if let myth = model.myth {
                MythCard(myth: myth) { model.rename($0) }
                    .id(myth.name)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if model.path.count >= 2 {
                MythCard(myth: Namer.Myth(name: "", myth: "")) { model.rename($0) }
                    .id("unnamed")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            keepButton
            controls
        }
        .foregroundStyle(Palette.ink)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .animation(.easeInOut(duration: 0.6), value: model.myth)
        .animation(.easeInOut(duration: 0.3), value: model.keptID)
        .animation(.easeInOut(duration: 0.3), value: log.count)
        .animation(.easeInOut(duration: 0.4), value: model.tuning)
        .animation(.easeInOut(duration: 0.3), value: model.path.count >= 2)
    }

    private var title: some View {
        HStack {
            (Text("Star").fontWeight(.light)
                + Text("song").fontWeight(.semibold).foregroundColor(Palette.gold))
                .font(.system(size: 32, design: .serif))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            keepsakeButton
            voicesButton
            atlasButton
            profileButton
            if !log.isEmpty { logButton }
        }
        .padding(.top, 60)
        .padding(.horizontal, 22)
    }

    /// Hers. Named rather than iconographic, because "gift" on its own is a
    /// guess and her name is not.
    private var keepsakeButton: some View {
        Button { showingKeepsake = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "gift").font(.system(size: 12))
                Text(Keepsake.name).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18)))
            .foregroundStyle(Palette.rose)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Keepsake.name)'s fifty")
        .accessibilityHint("Opens her keepsake: fifty stars, one for every year.")
    }

    private var voicesButton: some View {
        Button { sheet = .voices } label: {
            Image(systemName: "waveform")
                .font(.system(size: 14))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.18)))
                .foregroundStyle(Palette.line(model.activeLine))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Voices")
        .accessibilityValue(model.instrument.name)
    }

    private var atlasButton: some View {
        Button { sheet = .atlas } label: {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 14))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.18)))
                .foregroundStyle(Palette.gold)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Real constellations")
    }

    /// Dimmed until a key is present, so "Name it" not inventing anything is
    /// visible up here rather than only discoverable by pressing it.
    private var profileButton: some View {
        Button { sheet = .profile } label: {
            Image(systemName: Namer.isConfigured ? "person.crop.circle.fill" : "person.crop.circle.badge.plus")
                .font(.system(size: 14))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.18)))
                .foregroundStyle(Namer.isConfigured ? Palette.aqua : Palette.ink.opacity(0.45))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
        .accessibilityValue(Namer.isConfigured ? "Key installed" : "No key. Naming is offline.")
    }

    /// Only appears once there's something to look back at.
    private var logButton: some View {
        Button { sheet = .log } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles").font(.system(size: 12))
                Text("\(log.count)").font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18)))
            .foregroundStyle(Palette.gold)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Kept skies")
        .accessibilityValue("\(log.count) constellations")
        .transition(.opacity.combined(with: .scale))
    }

    @ViewBuilder
    private var keepButton: some View {
        if model.path.count >= 2 {
            let kept = model.keptID != nil
            Button { keep() } label: {
                Label(kept ? "Kept" : (model.lines.count > 1 ? "Keep these lines" : "Keep this one"),
                      systemImage: kept ? "sparkles" : "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.gold.opacity(kept ? 0.5 : 0.9))
            }
            .buttonStyle(.plain)
            .disabled(kept)
            .padding(.bottom, 14)
            .transition(.opacity)
        }
    }

    private func keep() {
        guard let sky = model.snapshot() else { return }
        log.keep(sky)
        model.markKept(sky)
    }

    /// Naming a constellation you already kept updates its stored story rather
    /// than filing a second copy of the same drawing.
    private func updateKeptStory() {
        guard let id = model.keptID, let sky = model.snapshot(id: id) else { return }
        log.keep(sky)
    }

    /// This night's key signature. It changes with every new sky.
    private var tuningCaption: some View {
        HStack {
            Text("\(model.instrument.name) · \(model.tuning.name)".uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.8)
                .foregroundStyle(Palette.ink.opacity(0.35))
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 2)
        .accessibilityLabel("\(model.instrument.name), tuned to \(model.tuning.name)")
    }

    private var hint: some View {
        Text("Tap or drag across stars to draw a constellation.\nHigher stars sing higher.")
            .font(.system(size: 15, weight: .regular, design: .default).leading(.standard))
            .multilineTextAlignment(.center)
            .opacity(0.6)
            .padding(.top, 12)
            .padding(.horizontal, 28)
            .transition(.opacity)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            PillButton("Undo") {
                model.undo()
                AccessibilityNotification.Announcement(
                    model.path.isEmpty ? "Line cleared." : "Removed. \(model.path.count) stars on the line."
                ).post()
            }
                .disabled(model.path.isEmpty && model.lines.count == 1)
            PillButton("New sky") { withAnimation { model.newSky(for: skySize) } }
            PillButton(model.isPlaying ? "Stop" : "Play", isPrimary: true) {
                model.isPlaying ? model.stop() : model.play()
            }
            .disabled(!model.canPlay && !model.isPlaying)
            PillButton(model.isNaming ? "Listening…" : "Name it") {
                // Only asks when there is a decision to lose.
                if model.nameIsMine { askBeforeRenaming = true } else { model.nameIt() }
            }
                .disabled(!model.canName)
        }
        .padding(.bottom, 36)
        .padding(.horizontal, 12)
    }
}

struct PillButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    var isPrimary = false
    let action: () -> Void

    init(_ title: String, isPrimary: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isPrimary = isPrimary
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isPrimary ? Palette.gold : Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(isPrimary ? 0 : 0.18)))
                .foregroundStyle(isPrimary ? Palette.pressedInk : Palette.ink)
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
        .accessibilityLabel(title)
    }
}

/// The name and its story. The name is editable in place — tap it and type.
///
/// `@State` seeded from the myth is safe because the caller keys this view on
/// the name, so a name arriving from anywhere else rebuilds the card with the
/// new text rather than leaving a stale draft behind.
struct MythCard: View {
    let myth: Namer.Myth
    let onRename: (String) -> Void

    @State private var draft: String
    @FocusState private var editing: Bool

    init(myth: Namer.Myth, onRename: @escaping (String) -> Void) {
        self.myth = myth
        self.onRename = onRename
        _draft = State(initialValue: myth.name)
    }

    var body: some View {
        VStack(spacing: 6) {
            name
            if !myth.myth.isEmpty {
                Text(myth.myth)
                    .font(.system(size: 15))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .opacity(0.9)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
    }

    /// A field styled to read as the heading it replaces, so the card looks the
    /// same until you touch it. The underline only appears while editing —
    /// a permanent one would make every constellation look like a form.
    private var name: some View {
        TextField("Name this constellation", text: $draft)
            .font(.system(size: 26, weight: .semibold, design: .serif))
            .foregroundStyle(Palette.gold)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .focused($editing)
            .onSubmit { commit() }
            // Tapping elsewhere is as much a commit as pressing Done; losing a
            // typed name to a stray tap would be the worst outcome here.
            .onChange(of: editing) { wasEditing, nowEditing in
                if wasEditing && !nowEditing { commit() }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Palette.gold.opacity(editing ? 0.5 : 0))
                    .frame(height: 1)
                    .offset(y: 4)
            }
            .animation(.easeOut(duration: 0.2), value: editing)
            .accessibilityLabel("Constellation name")
            .accessibilityValue(draft.isEmpty ? "Not named yet" : draft)
            .accessibilityHint("Type a name for this constellation.")
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = trimmed
        guard trimmed != myth.name else { return }
        onRename(trimmed)
    }
}

/// The sky is one adjustable control: swipe through the stars by pitch, hear
/// each one, double tap to add it. Seventy separate elements would pass an audit
/// and be unusable.
struct SkyAccessibility: ViewModifier {
    let model: SkyModel
    let announce: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityElement()
            .accessibilityLabel("Night sky")
            .accessibilityValue(model.cursorDescription)
            .accessibilityHint("Swipe up or down to move between stars and hear each note. Double tap to add the current star to your constellation.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: model.moveCursor(by: 1)
                case .decrement: model.moveCursor(by: -1)
                @unknown default: break
                }
            }
            .accessibilityAction { announce(model.connectCursor()) }
            // The same three moves again as named actions. Adjustable is the
            // good gesture, but it is only good if you think to try it; these
            // show up in the Actions rotor where they can be found by reading
            // rather than by guessing.
            .accessibilityAction(named: "Next star, higher") { model.moveCursor(by: 1) }
            .accessibilityAction(named: "Previous star, lower") { model.moveCursor(by: -1) }
            .accessibilityAction(named: "Add this star") { announce(model.connectCursor()) }
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
