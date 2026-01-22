import AVFoundation
import Foundation

/// Simulates HF band conditions: noise (QRN), fading (QSB), and interference (QRM).
///
/// Threading model:
/// - `processSample(_:at:)` is called from the audio render thread at high frequency
/// - `configure(from:)` must only be called when audio is not playing (during setup)
/// - `reset()` is called automatically by ToneGenerator.stopTone()
///
/// The `@unchecked Sendable` annotation is safe because configuration happens only during
/// setup when audio is stopped, and scalar property reads/writes are atomic on modern CPUs.
final class BandConditionsProcessor: @unchecked Sendable {

    // MARK: Lifecycle

    // MARK: - Initialization

    init(sampleRate: Double = 44100) {
        self.sampleRate = sampleRate
    }

    // MARK: Internal

    // MARK: - Configuration

    /// Whether band conditions processing is active
    var isEnabled: Bool = false

    /// Atmospheric noise level (QRN), 0.0 - 1.0
    var noiseLevel: Double = 0.3

    /// Whether signal fading is active
    var fadingEnabled: Bool = true

    /// How deep the signal fades, 0.0 - 1.0
    var fadingDepth: Double = 0.5

    /// Fading rate in Hz (cycles per second)
    var fadingRate: Double = 0.1

    /// Whether interference is active
    var interferenceEnabled: Bool = false

    /// Interference signal level, 0.0 - 1.0
    var interferenceLevel: Double = 0.2

    /// Update configuration from AppSettings
    func configure(from settings: AppSettings) {
        isEnabled = settings.bandConditionsEnabled
        noiseLevel = settings.noiseLevel
        fadingEnabled = settings.fadingEnabled
        fadingDepth = settings.fadingDepth
        fadingRate = settings.fadingRate
        interferenceEnabled = settings.interferenceEnabled
        interferenceLevel = settings.interferenceLevel
    }

    /// Reset all internal state (call when starting new audio session)
    func reset() {
        fadingPhase = 0
        interferenceActive = false
        interferencePhase = 0
        interferenceSamplesRemaining = 0
        crashSamplesRemaining = 0
        crashAmplitude = 0
        pinkB0 = 0
        pinkB1 = 0
        pinkB2 = 0
    }

    // MARK: - Processing

    /// Process a single audio sample with band conditions.
    /// Returns the modified sample value.
    func processSample(_ sample: Float, at sampleIndex: Int) -> Float {
        guard isEnabled else { return sample }

        var output = sample

        // Apply fading (QSB)
        if fadingEnabled {
            output = applyFading(to: output)
        }

        // Add noise (QRN)
        if noiseLevel > 0 {
            output = addNoise(to: output)
        }

        // Add interference (QRM)
        if interferenceEnabled, interferenceLevel > 0 {
            output = addInterference(to: output)
        }

        // Clamp to valid audio range
        return max(-1.0, min(1.0, output))
    }

    // MARK: Private

    // MARK: - Internal State

    private var fadingPhase: Double = 0
    private var sampleRate: Double = 44100

    // Interference state
    private var interferenceActive: Bool = false
    private var interferenceFrequency: Double = 0
    private var interferencePhase: Double = 0
    private var interferenceSamplesRemaining: Int = 0

    // Static crash state for QRN
    private var crashSamplesRemaining: Int = 0
    private var crashAmplitude: Float = 0

    // Pink noise filter state (Paul Kellet's economy filter)
    // Filters white noise to 1/f spectrum (±0.5dB accuracy)
    private var pinkB0: Float = 0
    private var pinkB1: Float = 0
    private var pinkB2: Float = 0

    // MARK: - Fading (QSB)

    /// Apply sinusoidal amplitude fading to simulate QSB.
    /// Real QSB has periods of 2-30 seconds. We use a sine wave modulation.
    private func applyFading(to sample: Float) -> Float {
        // Amplitude envelope: 1.0 - depth * (0.5 + 0.5 * sin(phase))
        // This oscillates between (1.0 - depth) and 1.0
        let envelope = 1.0 - fadingDepth * (0.5 + 0.5 * sin(fadingPhase))

        // Advance phase
        let phaseIncrement = 2.0 * Double.pi * fadingRate / sampleRate
        fadingPhase += phaseIncrement
        if fadingPhase >= 2.0 * Double.pi {
            fadingPhase -= 2.0 * Double.pi
        }

        return sample * Float(envelope)
    }

    // MARK: - Noise (QRN)

    /// Add atmospheric noise to simulate QRN.
    /// Uses pink noise (1/f spectrum) with occasional static crashes.
    private func addNoise(to sample: Float) -> Float {
        var output = sample

        // Generate pink noise using Paul Kellet's economy filter
        // This filters white noise to achieve 1/f spectral characteristics
        let white = Float.random(in: -1 ... 1)
        pinkB0 = 0.99765 * pinkB0 + white * 0.0990460
        pinkB1 = 0.96300 * pinkB1 + white * 0.2965164
        pinkB2 = 0.57000 * pinkB2 + white * 1.0526913
        let pink = pinkB0 + pinkB1 + pinkB2 + white * 0.1848

        // Scale pink noise by noise level (pink output is roughly -1 to 1)
        let baseNoise = pink * Float(noiseLevel) * 0.15
        output += baseNoise

        // Handle ongoing crash
        if crashSamplesRemaining > 0 {
            output += crashAmplitude
            crashSamplesRemaining -= 1
            // Decay the crash
            crashAmplitude *= 0.995
        } else {
            // Occasional static crashes (probability increases with noise level)
            let crashProbability = 0.00005 * noiseLevel
            if Double.random(in: 0 ... 1) < crashProbability {
                // Start a new crash: 10-50ms duration
                let crashDurationMs = Double.random(in: 10 ... 50)
                crashSamplesRemaining = Int(crashDurationMs * sampleRate / 1000)
                crashAmplitude = Float(noiseLevel * Double.random(in: 0.3 ... 0.8))
            }
        }

        return output
    }

    // MARK: - Interference (QRM)

    /// Add interference from other stations to simulate QRM.
    /// Sporadic tones at nearby frequencies.
    private func addInterference(to sample: Float) -> Float {
        var output = sample

        // Handle ongoing interference
        if interferenceActive, interferenceSamplesRemaining > 0 {
            let interferenceSignal = sin(interferencePhase)
            output += Float(interferenceSignal * interferenceLevel * 0.3)

            // Advance interference phase
            let phaseIncrement = 2.0 * Double.pi * interferenceFrequency / sampleRate
            interferencePhase += phaseIncrement
            if interferencePhase >= 2.0 * Double.pi {
                interferencePhase -= 2.0 * Double.pi
            }

            interferenceSamplesRemaining -= 1
            if interferenceSamplesRemaining <= 0 {
                interferenceActive = false
            }
        } else {
            // Random chance to start interference
            let startProbability = 0.00002 * interferenceLevel
            if Double.random(in: 0 ... 1) < startProbability {
                interferenceActive = true
                // Nearby frequency: base ± 50-200 Hz
                interferenceFrequency = 600 + Double.random(in: -200 ... 200)
                interferencePhase = 0

                // Duration: 0.3-2.0 seconds
                let durationSeconds = Double.random(in: 0.3 ... 2.0)
                interferenceSamplesRemaining = Int(durationSeconds * sampleRate)
            }
        }

        return output
    }
}
