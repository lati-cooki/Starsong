import CoreGraphics
import Foundation
import Observation

/// Everything the keepsake knows: the fifty stars, which year is showing, what
/// has already been read, and playback. The view is a pure function of this,
/// the same way `ContentView` is a pure function of `SkyModel`.
///
/// It is a model rather than a pile of `@State` for one concrete reason beyond
/// tidiness: the playback loop has to hold a reference across `await`s, and a
/// class can be captured weakly where a view struct cannot be captured at all.
@MainActor
@Observable
final class KeepsakeModel {
    let name: String
    let life: [Keepsake.Year]
    let tuning: Music.Tuning
    let voice: Instrument

    private(set) var stars: [Star] = []
    private(set) var pulses: [Pulse] = []
    /// The year on the card, by age. `nil` between years — which is when the
    /// dedication, or the closing message, has the screen to itself.
    private(set) var showing: Int?
    private(set) var isPlaying = false

    private var progress: KeepsakeProgress
    private var playback: Task<Void, Never>?

    init(name: String = Keepsake.name,
         life: [Keepsake.Year] = Keepsake.life,
         tuning: Music.Tuning = Keepsake.tuning,
         voice: Instrument = Keepsake.voice,
         defaults: UserDefaults = .standard) {
        self.name = name
        self.life = life
        self.tuning = tuning
        self.voice = voice
        self.progress = KeepsakeProgress(name: name, defaults: defaults)
        refresh()
    }

    // MARK: - What the view asks

    var read: Set<Int> { progress.read }
    var isComplete: Bool { progress.isComplete(of: life.count) }
    var year: Keepsake.Year? { showing.flatMap { age in life.first { $0.age == age } } }
    var cursor: Star? { showing.flatMap { stars.indices.contains($0) ? stars[$0] : nil } }

    /// The dedication until she has opened something, then how far she has got.
    /// One line that changes rather than two, one of which is always dead.
    var caption: String {
        read.isEmpty
            ? Keepsake.dedication.uppercased()
            : "\(read.count) of \(life.count) opened".uppercased()
    }

    /// What VoiceOver reads for the sky as a whole.
    var spoken: String {
        year?.spoken
            ?? "\(life.count) years. Swipe up to begin at \(Keepsake.birthYear)."
    }

    // MARK: - Opening a year

    func touch(at point: CGPoint, in size: CGSize) {
        guard let age = FiftySky.year(nearest: point, in: stars, size: size),
              age != showing else { return }
        stop()
        show(age)
    }

    /// Walks the years one at a time — what the adjustable accessibility
    /// gesture drives, and the reason the melody and the life are in the same
    /// order: moving through the sky and moving through her life agree.
    func step(by move: Int) {
        guard !life.isEmpty else { return }
        let next = min(max((showing ?? -1) + move, 0), life.count - 1)
        guard next != showing else { return }
        stop()
        show(next)
    }

    /// Opening a year sounds it, rings it, and remembers it was read.
    func show(_ age: Int, sounding: Bool = true) {
        guard stars.indices.contains(age) else { return }
        let star = stars[age]
        if sounding {
            Synth.shared.ping(Music.pitch(forY: star.y, in: tuning),
                              instrument: voice, duration: 1.6)
            pulses.append(Pulse(position: CGPoint(x: star.x, y: star.y),
                                start: .now, line: 0))
        }
        showing = age
        progress.markRead(age)
        refresh()
    }

    /// The stars carry the gold, so they are rebuilt from the read set rather
    /// than being mutated in two places that could disagree.
    private func refresh() {
        stars = FiftySky.stars(count: life.count, name: name, lit: progress.read)
    }

    // MARK: - Playing

    /// Her name, as a phrase.
    func sing() {
        SkyModel.preview([NameSong.stars(in: name)], tuning: tuning, voices: [voice])
    }

    /// One note when the keepsake opens, quietly — enough to say the app has a
    /// voice, not enough to be a fanfare.
    func greet() {
        guard let first = NameSong.stars(in: name).first else { return }
        Synth.shared.ping(Music.pitch(forY: first.y, in: tuning),
                          instrument: voice, delay: 0.35, duration: 2.4, volume: 0.18)
    }

    /// The whole life in order, with the card following along — so pressing
    /// play is a way of reading it as much as of hearing it.
    ///
    /// The notes all go onto the audio clock in one go, the way `SkyModel` does
    /// it, so the melody keeps its rhythm however busy the main thread is. The
    /// loop below only has to move the card.
    func play() {
        guard !stars.isEmpty else { return }
        stop()
        isPlaying = true

        let starts = Music.schedule(for: stars)
        let durations = Music.durations(for: stars)
        let now = Date()
        for (age, star) in stars.enumerated() {
            Synth.shared.ping(Music.pitch(forY: star.y, in: tuning),
                              instrument: voice,
                              delay: starts[age],
                              duration: durations[age],
                              volume: Keepsake.isMilestone(age: age) ? 0.28 : 0.22)
            pulses.append(Pulse(position: CGPoint(x: star.x, y: star.y),
                                start: now.addingTimeInterval(starts[age]),
                                line: 0))
        }

        playback = Task { [weak self] in
            let began = Date()
            for (age, start) in starts.enumerated() {
                // Measured from the downbeat rather than accumulated, so a slow
                // frame shifts one caption instead of everything after it.
                let wait = start - Date().timeIntervalSince(began)
                if wait > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                }
                guard !Task.isCancelled, let self, self.isPlaying else { return }
                self.show(age, sounding: false)
            }
            try? await Task.sleep(nanoseconds: UInt64(Music.loopRest * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            // Ending on the fiftieth year would leave its card up and put the
            // closing message somewhere she has to go looking for.
            self.showing = nil
            self.isPlaying = false
        }
    }

    func stop() {
        playback?.cancel()
        playback = nil
        isPlaying = false
    }

    // MARK: - Housekeeping

    /// Reaps faded rings. The sky animates from the timeline, not from this.
    func advance(to now: Date) {
        pulses.removeAll { $0.hasFaded(at: now) }
    }
}
