import AVFoundation
import Foundation

/// Renders and schedules notes. The waveforms live in `Instrument`; this owns
/// the engine, the pool of players, and the cache of rendered notes. Voices are
/// attached once and reused round-robin, and notes are scheduled on the audio
/// clock rather than a dispatch timer, so a melody keeps its rhythm even when
/// the main thread is busy drawing.
final class Synth {
    static let shared = Synth()

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let reverb = AVAudioUnitReverb()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0

    /// Rendered buffers, keyed by a quantized tone so repeated notes are free.
    private var cache: [Tone: AVAudioPCMBuffer] = [:]
    private let lock = NSLock()

    /// Configuring and activating an audio session can block for a long time, so
    /// every session and engine lifecycle call is funnelled through this queue
    /// instead of running on whichever thread happened to ask for a note.
    private let sessionQueue = DispatchQueue(label: "com.starsong.synth.session")

    /// A whole cycle is scheduled at once, so each line claims one voice per
    /// note immediately, and a wrapped round-robin would `stop()` a note still
    /// waiting to play. Sized for the worst case with room to ring.
    ///
    /// The worst case used to be three ten-note lines — thirty before anything
    /// had sounded — and 48 covered it. The keepsake's fifty years are one line
    /// of fifty notes, which does not fit: the round-robin wrapped and the first
    /// two years were stopped mid-ring before they had properly begun.
    private static let voiceCount = 64
    /// Bounded by bytes rather than by entries. A 2.4-second note is about
    /// 400 kB, a short one a tenth of that, so counting entries makes the real
    /// ceiling swing by an order of magnitude — and five voices multiply
    /// however many distinct notes are in play.
    private static let cacheBudget = 24 * 1_024 * 1_024
    private var cachedBytes = 0

    private struct Tone: Hashable {
        let instrument: Instrument
        let frequency: Int   // centihertz
        let duration: Int    // milliseconds
        let volume: Int      // 1/1000ths
    }

    private init() {
        engine.attach(mixer)
        engine.attach(reverb)
        reverb.loadFactoryPreset(.largeHall)
        reverb.wetDryMix = 24
        engine.connect(mixer, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        for _ in 0..<Self.voiceCount {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: mixer, format: format)
            voices.append(voice)
        }
        observeAudioNotifications()
        sessionQueue.async { [self] in
            configureSession()
            startEngine()
        }
    }

    // MARK: - Playing

    /// Schedule a note. `delay` is measured from now, on the audio clock.
    func ping(_ frequency: Double,
              instrument: Instrument = .chime,
              delay: TimeInterval = 0,
              duration: Double = 0.9,
              volume: Float = 0.25) {
        guard frequency.isFinite, frequency > 0, frequency < 20_000, duration > 0 else { return }

        // Pin the start time to the audio clock here, before hopping queues, so
        // a busy session queue shifts a phrase rather than smearing its rhythm.
        let when = delay > 0
            ? AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: delay))
            : nil

        sessionQueue.async { [self] in
            startEngine()
            // A player node raises if it is started while the engine is down.
            guard engine.isRunning else { return }

            let buffer = buffer(instrument: instrument, frequency: frequency,
                            duration: duration, volume: volume)
            let voice = checkoutVoice()
            voice.stop()
            voice.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)

            if let when {
                voice.play(at: when)
            } else {
                voice.play()
            }
        }
    }

    /// Stops every voice at once.
    ///
    /// Nothing else needs this: Starsong schedules one cycle at a time, so
    /// cancelling the loop lets the cycle in flight ring out, which is a
    /// pleasant way to stop. The keepsake puts a whole fifty-note life onto the
    /// audio clock in one go, and there cancelling the task that queued it
    /// leaves fifteen seconds of music playing behind a button that says Stop.
    func silence() {
        sessionQueue.async { [self] in
            for voice in voices where voice.isPlaying { voice.stop() }
        }
    }

    private func checkoutVoice() -> AVAudioPlayerNode {
        lock.lock()
        defer { lock.unlock() }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        return voice
    }

    // MARK: - Rendering

    private func buffer(instrument: Instrument, frequency: Double,
                        duration: Double, volume: Float) -> AVAudioPCMBuffer {
        let tone = Tone(instrument: instrument,
                        frequency: Int((frequency * 100).rounded()),
                        duration: Int((duration * 1000).rounded()),
                        volume: Int((volume * 1000).rounded()))

        lock.lock()
        if let cached = cache[tone] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let rendered = render(instrument: instrument, frequency: frequency,
                              duration: duration, volume: volume)
        let bytes = Int(rendered.frameLength) * MemoryLayout<Float>.size

        lock.lock()
        if cachedBytes + bytes > Self.cacheBudget {
            cache.removeAll(keepingCapacity: true)
            cachedBytes = 0
        }
        cache[tone] = rendered
        cachedBytes += bytes
        lock.unlock()

        return rendered
    }

    private func render(instrument: Instrument, frequency: Double,
                        duration: Double, volume: Float) -> AVAudioPCMBuffer {
        let voice = instrument.samples(frequency: frequency, duration: duration,
                                       sampleRate: format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                      frameCapacity: AVAudioFrameCount(max(voice.count, 1)))!
        buffer.frameLength = buffer.frameCapacity

        let samples = buffer.floatChannelData![0]
        for i in 0..<voice.count { samples[i] = voice[i] * volume }
        if voice.isEmpty { samples[0] = 0 }
        return buffer
    }

    // MARK: - Session & engine lifecycle

    /// Must be called on `sessionQueue`: these calls can block, and blocking the
    /// main thread while the session is active makes the UI unresponsive.
    private func configureSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        // .playback so the sky still sings with the ring switch flipped, and
        // .mixWithOthers so it plays politely over whatever else is on.
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        try? engine.start()
    }

    private func observeAudioNotifications() {
        #if os(iOS)
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification,
                           object: AVAudioSession.sharedInstance(),
                           queue: nil) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended,
                  let self else { return }
            sessionQueue.async {
                self.configureSession()
                self.startEngine()
            }
        }
        center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                           object: AVAudioSession.sharedInstance(),
                           queue: nil) { [weak self] _ in
            guard let self else { return }
            sessionQueue.async { self.rebuild() }
        }
        #endif
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange,
                                              object: engine,
                                              queue: nil) { [weak self] _ in
            guard let self else { return }
            sessionQueue.async { self.reconnect() }
        }
    }

    /// A route change tears down connections; rebuild the graph and carry on.
    /// Must be called on `sessionQueue`.
    private func reconnect() {
        engine.connect(mixer, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        for voice in voices {
            engine.connect(voice, to: mixer, format: format)
        }
        startEngine()
    }

    private func rebuild() {
        configureSession()
        reconnect()
    }
}
