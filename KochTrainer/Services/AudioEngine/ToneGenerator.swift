import AVFoundation
import Foundation

/// Generates sine wave audio tones using AVAudioEngine.
/// Thread-safe: uses internal locking and serial queue for synchronization.
final class ToneGenerator: @unchecked Sendable {

    // MARK: Lifecycle

    init() {
        setupAudioSession()
    }

    deinit {
        stopTone()
    }

    // MARK: Internal

    /// Band conditions processor for simulating HF conditions (QRN, QSB, QRM)
    let bandConditionsProcessor = BandConditionsProcessor()

    /// Play a tone at the specified frequency for the given duration.
    /// Queues the request to ensure sequential playback when called rapidly.
    /// - Parameters:
    ///   - frequency: Tone frequency in Hz (typically 400-800)
    ///   - duration: Duration in seconds
    func playTone(frequency: Double, duration: TimeInterval) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            audioQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                // If currently playing, wait for it to finish
                while self.isPlaying {
                    Thread.sleep(forTimeInterval: 0.005) // 5ms polling
                }

                // Start the tone on main thread (AVAudioEngine requirement)
                DispatchQueue.main.sync {
                    self.startToneInternal(frequency: frequency)
                }

                // Wait for the duration
                Thread.sleep(forTimeInterval: duration)

                // Stop the tone on main thread
                DispatchQueue.main.sync {
                    self.stopTone()
                }

                continuation.resume()
            }
        }
    }

    /// Start continuous tone at the specified frequency (public API for external use).
    func startTone(frequency: Double) {
        startToneInternal(frequency: frequency)
    }

    /// Stop the currently playing tone.
    func stopTone() {
        guard isPlaying else { return }

        audioEngine.stop()
        if let sourceNode = sourceNode {
            audioEngine.detach(sourceNode)
        }
        sourceNode = nil
        isPlaying = false
        currentPhase = 0
    }

    /// Play silence for the specified duration.
    func playSilence(duration: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }

    // MARK: Private

    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 44100

    private var currentPhase: Double = 0
    private let stateLock = NSLock()
    private var _isPlaying = false

    // Serial queue to ensure tones play sequentially
    private let audioQueue = DispatchQueue(label: "com.kochtrainer.audioQueue")

    private var isPlaying: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _isPlaying
        }
        set {
            stateLock.lock()
            _isPlaying = newValue
            stateLock.unlock()
        }
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    /// Start continuous tone at the specified frequency (internal, called from queue).
    private func startToneInternal(frequency: Double) {
        guard !isPlaying else { return }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let twoPi = 2.0 * Double.pi
        let phaseIncrement = twoPi * frequency / sampleRate
        let processor = bandConditionsProcessor

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0 ..< Int(frameCount) {
                var value = Float(sin(self.currentPhase))
                self.currentPhase += phaseIncrement
                if self.currentPhase >= twoPi {
                    self.currentPhase -= twoPi
                }

                // Apply base volume
                value *= 0.5

                // Apply band conditions processing (QRN, QSB, QRM)
                value = processor.processSample(value, at: frame)

                // Clamp to prevent distortion
                value = max(-1.0, min(1.0, value))

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = value
                }
            }
            return noErr
        }

        guard let sourceNode = sourceNode else { return }

        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
            isPlaying = true
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

}
