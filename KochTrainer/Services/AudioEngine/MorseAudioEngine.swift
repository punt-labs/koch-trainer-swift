import Combine
import Foundation
import os

// MARK: - AudioEngineProtocol

/// Protocol for playing Morse code audio.
@MainActor
protocol AudioEngineProtocol {
    func playCharacter(_ char: Character) async
    func playGroup(_ group: String) async
    func playGroup(_ group: String, onCharacterPlayed: ((Character, Int) -> Void)?) async
    func playDit() async
    func playDah() async
    func stop()
    func reset()
    func setFrequency(_ frequency: Double)
    func setEffectiveSpeed(_ wpm: Int)
    func configureBandConditions(from settings: AppSettings)

    // MARK: - Continuous Session API (Half-Duplex Radio Simulation)

    /// Start a continuous audio session with radio mode control.
    /// Audio engine runs continuously until `endSession()` is called.
    func startSession()

    /// End the continuous audio session.
    func endSession()

    /// Current radio mode.
    var radioMode: RadioMode { get }

    // MARK: - Radio Control API (Z Specification Compliant)

    /// Start receiving mode (listening for incoming signals).
    /// - Throws: `Radio.RadioError.mustBeOff` if radio is not currently off.
    func startReceiving() throws

    /// Start transmitting mode (preparing to send).
    /// - Throws: `Radio.RadioError.mustBeOff` if radio is not currently off.
    func startTransmitting() throws

    /// Stop the radio (transition to off).
    /// - Throws: `Radio.RadioError.alreadyOff` if radio is already off.
    func stopRadio() throws

    // MARK: - Tone Control API (for IambicKeyer)

    /// Activate continuous tone at specified frequency.
    /// - Throws: `Radio.RadioError.mustBeOn` if radio is off.
    func activateTone(frequency: Double) throws

    /// Deactivate continuous tone.
    func deactivateTone()
}

// MARK: - MorseAudioEngine

/// Plays Morse code characters and groups with configurable timing.
@MainActor
final class MorseAudioEngine: AudioEngineProtocol, ObservableObject {

    // MARK: Lifecycle

    deinit {
        // Ensure audio session is cleaned up when engine is deallocated
        toneGenerator.endSession()
    }

    // MARK: Internal

    struct Timing {

        // MARK: Lifecycle

        init(effectiveWPM: Int) {
            // Character speed fixed at 20 WPM
            ditDuration = MorseCode.Timing.ditDuration
            dahDuration = MorseCode.Timing.dahDuration
            elementGap = MorseCode.Timing.elementGap
            characterGap = MorseCode.Timing.farnsworthCharacterGap(effectiveWPM: effectiveWPM)
            wordGap = MorseCode.Timing.farnsworthWordGap(effectiveWPM: effectiveWPM)
        }

        // MARK: Internal

        let ditDuration: TimeInterval
        let dahDuration: TimeInterval
        let elementGap: TimeInterval
        let characterGap: TimeInterval
        let wordGap: TimeInterval

    }

    /// Current radio mode.
    var radioMode: RadioMode {
        toneGenerator.radioMode
    }

    func setFrequency(_ frequency: Double) {
        self.frequency = max(400, min(800, frequency))
    }

    func setEffectiveSpeed(_ wpm: Int) {
        effectiveSpeed = max(10, min(18, wpm))
    }

    func configureBandConditions(from settings: AppSettings) {
        toneGenerator.bandConditionsProcessor.configure(from: settings)
    }

    /// Play a single character in Morse code.
    func playCharacter(_ char: Character) async {
        guard !isStopped else { return }

        guard let pattern = MorseCode.pattern(for: char) else {
            logger.warning("Unknown character: \(String(char))")
            return
        }

        for (index, element) in pattern.enumerated() {
            guard !isStopped else { return }

            switch element {
            case ".":
                await playToneElement(duration: timing.ditDuration)
            case "-":
                await playToneElement(duration: timing.dahDuration)
            default:
                continue
            }

            // Inter-element gap (except after last element)
            if index < pattern.count - 1 {
                await toneGenerator.playSilence(duration: timing.elementGap)
            }
        }
    }

    /// Play a single dit (short tone).
    func playDit() async {
        guard !isStopped else { return }
        await playToneElement(duration: timing.ditDuration)
    }

    /// Play a single dah (long tone).
    func playDah() async {
        guard !isStopped else { return }
        await playToneElement(duration: timing.dahDuration)
    }

    /// Play a group of characters (word or character group).
    func playGroup(_ group: String) async {
        await playGroup(group, onCharacterPlayed: nil)
    }

    /// Play a group of characters with optional callback after each character.
    /// The callback receives the character and its index in the string.
    func playGroup(_ group: String, onCharacterPlayed: ((Character, Int) -> Void)?) async {
        let characters = Array(group.uppercased())

        for (index, char) in characters.enumerated() {
            guard !isStopped else { return }

            if char == " " {
                // Word gap (minus character gap already waited)
                await toneGenerator.playSilence(duration: timing.wordGap - timing.characterGap)
                onCharacterPlayed?(char, index)
            } else {
                await playCharacter(char)
                onCharacterPlayed?(char, index)

                // Inter-character gap (except after last character or before space)
                if index < characters.count - 1, characters[index + 1] != " " {
                    await toneGenerator.playSilence(duration: timing.characterGap)
                }
            }
        }
    }

    /// Stop all audio playback.
    func stop() {
        isStopped = true
        toneGenerator.stopTone()
    }

    /// Reset stopped state to allow playback again.
    func reset() {
        isStopped = false
    }

    // MARK: - Continuous Session API

    /// Start a continuous audio session.
    /// The audio engine runs continuously with radio mode control.
    func startSession() {
        isStopped = false
        isSessionActive = true
        toneGenerator.startSession()
    }

    /// End the continuous audio session.
    func endSession() {
        isStopped = true
        isSessionActive = false
        toneGenerator.endSession()
    }

    // MARK: - Radio Control API

    /// Start receiving mode.
    func startReceiving() throws {
        try toneGenerator.radio.startReceiving()
    }

    /// Start transmitting mode.
    func startTransmitting() throws {
        try toneGenerator.radio.startTransmitting()
    }

    /// Stop the radio.
    func stopRadio() throws {
        try toneGenerator.radio.stop()
    }

    // MARK: - Tone Control API

    /// Activate continuous tone at specified frequency.
    func activateTone(frequency: Double) throws {
        try toneGenerator.activateTone(frequency: frequency)
    }

    /// Deactivate continuous tone.
    func deactivateTone() {
        toneGenerator.deactivateTone()
    }

    // MARK: Private

    private let logger = Logger(subsystem: "com.kochtrainer", category: "MorseAudioEngine")

    private let toneGenerator = ToneGenerator()
    private var frequency: Double = 600
    private var effectiveSpeed: Int = 12

    private var isStopped = false
    private var isSessionActive = false

    /// Timing configuration based on current effective speed
    private var timing: Timing {
        Timing(effectiveWPM: effectiveSpeed)
    }

    /// Play a tone element.
    /// Uses continuous mode during active sessions (radio simulation with band conditions).
    /// Uses discrete mode otherwise (clean audio for settings preview).
    private func playToneElement(duration: TimeInterval) async {
        if isSessionActive {
            // Continuous mode: use serialized playback to prevent race conditions
            do {
                try await toneGenerator.playToneElementSerialized(
                    frequency: frequency,
                    duration: duration
                )
            } catch {
                preconditionFailure(
                    "Programming error: Z spec violation: attempted to play tone with radio off."
                )
            }
        } else {
            // Discrete mode: start/stop engine per tone (no band conditions)
            await toneGenerator.playTone(frequency: frequency, duration: duration)
        }
    }

}
