import AVFoundation
import Foundation

/// Generates sine wave audio tones using AVAudioEngine.
///
/// Supports two modes of operation:
/// 1. **Discrete tones**: Traditional start/stop per tone via `playTone()`
/// 2. **Continuous session**: Engine runs for session duration with radio mode control
///
/// For continuous mode, use `startSession()` to begin, `setRadioMode(_:)` to control
/// audio behavior, and `endSession()` to stop.
///
/// Thread-safe: uses internal locking and serial queue for synchronization.
final class ToneGenerator: @unchecked Sendable {

    // MARK: Lifecycle

    init() {
        setupAudioSession()
        setupInterruptionHandling()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        endSession()
    }

    // MARK: Internal

    /// Band conditions processor for simulating HF conditions (QRN, QSB, QRM)
    let bandConditionsProcessor = BandConditionsProcessor()

    /// Current radio mode (thread-safe read)
    var radioMode: RadioMode {
        radioModeLock.lock()
        defer { radioModeLock.unlock() }
        return _radioMode
    }

    /// Whether a tone is currently being generated (for continuous mode)
    var isToneActive: Bool {
        toneActiveLock.lock()
        defer { toneActiveLock.unlock() }
        return _isToneActive
    }

    /// Play a tone at the specified frequency for the given duration.
    /// Queues the request to ensure sequential playback when called rapidly.
    /// - Parameters:
    ///   - frequency: Tone frequency in Hz (typically 400-800)
    ///   - duration: Duration in seconds
    func playTone(frequency: Double, duration: TimeInterval) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            audioQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }

                // If currently playing, wait for it to finish
                while isPlaying {
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
        if let sourceNode {
            audioEngine.detach(sourceNode)
        }
        sourceNode = nil
        isPlaying = false
        currentPhase = 0
        bandConditionsProcessor.reset()
    }

    /// Play silence for the specified duration.
    func playSilence(duration: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }

    // MARK: - Continuous Session API

    /// Start a continuous audio session.
    /// The audio engine runs continuously until `endSession()` is called.
    /// Use `setRadioMode(_:)` to control audio output behavior.
    func startSession() {
        guard !isSessionActive else { return }

        bandConditionsProcessor.reset()
        setRadioMode(.receiving)
        startContinuousAudio()
        isSessionActive = true
    }

    /// End the continuous audio session.
    func endSession() {
        guard isSessionActive else {
            // Also handle legacy discrete tone cleanup
            stopTone()
            return
        }

        setRadioMode(.off)
        stopContinuousAudio()
        isSessionActive = false
    }

    /// Set the radio mode for continuous audio.
    /// - Parameter mode: The desired radio mode
    ///
    /// From Z specification:
    /// - `.off`: Radio not active (silence)
    /// - `.receiving`: Noise + incoming signals + band conditions
    /// - `.transmitting`: Sidetone only (no noise, no band conditions)
    func setRadioMode(_ mode: RadioMode) {
        radioModeLock.lock()
        _radioMode = mode
        radioModeLock.unlock()
    }

    /// Activate tone generation at the specified frequency (for continuous mode)
    func activateTone(frequency: Double) {
        currentFrequency = frequency
        toneActiveLock.lock()
        _isToneActive = true
        toneActiveLock.unlock()
    }

    /// Deactivate tone generation (for continuous mode)
    func deactivateTone() {
        toneActiveLock.lock()
        _isToneActive = false
        toneActiveLock.unlock()
    }

    // MARK: Private

    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 44100

    private let stateLock = NSLock()
    private var _isPlaying = false

    // Serial queue to ensure tones play sequentially
    private let audioQueue = DispatchQueue(label: "com.kochtrainer.audioQueue")

    // Continuous session state
    private var isSessionActive = false
    private var wasInterrupted = false

    // Radio mode (thread-safe for audio callback access)
    private let radioModeLock = NSLock()
    private var _radioMode: RadioMode = .off

    // Tone active flag (thread-safe for audio callback access)
    private let toneActiveLock = NSLock()
    private var _isToneActive = false

    // Frequency (thread-safe for audio callback access)
    private let frequencyLock = NSLock()
    private var _currentFrequency: Double = 600

    // Phase (thread-safe for audio callback access)
    private let phaseLock = NSLock()
    private var _currentPhase: Double = 0

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

    private var currentFrequency: Double {
        get {
            frequencyLock.lock()
            defer { frequencyLock.unlock() }
            return _currentFrequency
        }
        set {
            frequencyLock.lock()
            _currentFrequency = newValue
            frequencyLock.unlock()
        }
    }

    private var currentPhase: Double {
        get {
            phaseLock.lock()
            defer { phaseLock.unlock() }
            return _currentPhase
        }
        set {
            phaseLock.lock()
            _currentPhase = newValue
            phaseLock.unlock()
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

    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            // Audio was interrupted (app backgrounded, phone call, etc.)
            // The audio engine will be stopped by iOS
            wasInterrupted = true

        case .ended:
            // Interruption ended - check if we should resume
            guard wasInterrupted, isSessionActive else { return }
            wasInterrupted = false

            // Check if we should resume playback
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Reactivate audio session and restart continuous audio
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        restartContinuousAudio()
                    } catch {
                        print("Failed to reactivate audio session: \(error)")
                    }
                }
            }

        @unknown default:
            break
        }
    }

    /// Restart continuous audio after interruption (preserves current radio mode).
    private func restartContinuousAudio() {
        guard isSessionActive else { return }

        // Stop any existing audio
        if isPlaying {
            stopContinuousAudio()
        }

        // Restart with current radio mode
        startContinuousAudio()
    }

    /// Start continuous tone at the specified frequency (internal, called from queue).
    private func startToneInternal(frequency: Double) {
        guard !isPlaying else { return }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let twoPi = 2.0 * Double.pi
        let phaseIncrement = twoPi * frequency / sampleRate
        let processor = bandConditionsProcessor

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0 ..< Int(frameCount) {
                var value = Float(sin(currentPhase))
                currentPhase += phaseIncrement
                if currentPhase >= twoPi {
                    currentPhase -= twoPi
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

        guard let sourceNode else { return }

        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
            isPlaying = true
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    // MARK: - Continuous Audio (Private)

    /// Start continuous audio with radio-mode-aware rendering.
    private func startContinuousAudio() {
        guard !isPlaying else { return }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let twoPi = 2.0 * Double.pi
        let processor = bandConditionsProcessor

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }

            // Read thread-safe state once at callback start (avoid lock contention in loop)
            let mode = radioMode
            let toneActive = isToneActive
            let frequency = currentFrequency
            var phase = currentPhase
            let phaseIncrement = twoPi * frequency / sampleRate

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0 ..< Int(frameCount) {
                var value: Float

                switch mode {
                case .off:
                    // Radio off: silence
                    value = 0.0

                case .receiving:
                    // Radio receiving: noise + optional incoming signal + band conditions
                    if toneActive {
                        // Generate tone
                        value = Float(sin(phase))
                        phase += phaseIncrement
                        if phase >= twoPi {
                            phase -= twoPi
                        }
                        value *= 0.5
                    } else {
                        // No tone, just noise floor
                        value = 0.0
                    }
                    // Apply band conditions (noise, fading, interference)
                    value = processor.processSample(value, at: frame)

                case .transmitting:
                    // Radio transmitting: sidetone only (no band conditions)
                    if toneActive {
                        value = Float(sin(phase))
                        phase += phaseIncrement
                        if phase >= twoPi {
                            phase -= twoPi
                        }
                        value *= 0.5
                    } else {
                        value = 0.0
                    }
                    // No band conditions processing - clean sidetone
                }

                // Clamp to prevent distortion
                value = max(-1.0, min(1.0, value))

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = value
                }
            }

            // Write phase back once at callback end
            currentPhase = phase
            return noErr
        }

        guard let sourceNode else { return }

        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
            isPlaying = true
        } catch {
            print("Failed to start continuous audio engine: \(error)")
        }
    }

    /// Stop continuous audio.
    private func stopContinuousAudio() {
        guard isPlaying else { return }

        audioEngine.stop()
        if let sourceNode {
            audioEngine.detach(sourceNode)
        }
        sourceNode = nil
        isPlaying = false
        currentPhase = 0
        bandConditionsProcessor.reset()
    }

}
