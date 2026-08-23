import AVFoundation
import Foundation

/// Tiny additive synth: a triangle with a detuned octave-ish sine on top and a
/// soft exponential envelope. Voices are attached once and reused round-robin,
/// and notes are scheduled on the audio clock rather than a dispatch timer, so
/// a melody keeps its rhythm even when the main thread is busy drawing.
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
    /// note immediately. Three ten-note lines is thirty before anything has
    /// sounded, and a wrapped round-robin would `stop()` a note still waiting
    /// to play. Sized for the worst case with room to ring.
    private static let voiceCount = 48
    private static let cacheLimit = 64

    private struct Tone: Hashable {
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

            let buffer = buffer(frequency: frequency, duration: duration, volume: volume)
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

    private func checkoutVoice() -> AVAudioPlayerNode {
        lock.lock()
        defer { lock.unlock() }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        return voice
    }

    // MARK: - Rendering

    private func buffer(frequency: Double, duration: Double, volume: Float) -> AVAudioPCMBuffer {
        let tone = Tone(frequency: Int((frequency * 100).rounded()),
                        duration: Int((duration * 1000).rounded()),
                        volume: Int((volume * 1000).rounded()))

        lock.lock()
        if let cached = cache[tone] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let rendered = render(frequency: frequency, duration: duration, volume: volume)

        lock.lock()
        if cache.count >= Self.cacheLimit { cache.removeAll(keepingCapacity: true) }
        cache[tone] = rendered
        lock.unlock()

        return rendered
    }

    private func render(frequency: Double, duration: Double, volume: Float) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(duration * sampleRate)
        // frameCapacity of 0 is invalid, and the guard in `ping` keeps duration > 0.
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(frames, 1))!
        buffer.frameLength = buffer.frameCapacity

        let samples = buffer.floatChannelData![0]
        let attack = 0.02
        let release = 0.04
        let decay = 5.0

        for i in 0..<Int(buffer.frameLength) {
            let t = Double(i) / sampleRate
            let remaining = duration - t
            let envelope = min(1, t / attack)
                * min(1, max(0, remaining) / release)   // avoid a click at the tail
                * exp(-t * decay)
            let triangle = 2 / Double.pi * asin(sin(2 * .pi * frequency * t))
            let shimmer = sin(2 * .pi * frequency * 2.01 * t) * 0.35
            samples[i] = Float((triangle + shimmer) * envelope) * volume
        }
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
