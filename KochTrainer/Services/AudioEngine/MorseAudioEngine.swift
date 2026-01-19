import Combine
import Foundation

/// Protocol for playing Morse code audio.
@MainActor
protocol AudioEngineProtocol {
    func playCharacter(_ char: Character) async
    func playGroup(_ group: String) async
    func stop()
    func setFrequency(_ frequency: Double)
    func setEffectiveSpeed(_ wpm: Int)
    func configureBandConditions(from settings: AppSettings)
}

/// Plays Morse code characters and groups with configurable timing.
@MainActor
final class MorseAudioEngine: AudioEngineProtocol, ObservableObject {
    private let toneGenerator = ToneGenerator()
    private var frequency: Double = 600
    private var effectiveSpeed: Int = 12

    private var isStopped = false

    /// Timing configuration based on current effective speed
    private var timing: Timing {
        Timing(effectiveWPM: effectiveSpeed)
    }

    struct Timing {
        let ditDuration: TimeInterval
        let dahDuration: TimeInterval
        let elementGap: TimeInterval
        let characterGap: TimeInterval
        let wordGap: TimeInterval

        init(effectiveWPM: Int) {
            // Character speed fixed at 20 WPM
            ditDuration = MorseCode.Timing.ditDuration
            dahDuration = MorseCode.Timing.dahDuration
            elementGap = MorseCode.Timing.elementGap
            characterGap = MorseCode.Timing.farnsworthCharacterGap(effectiveWPM: effectiveWPM)
            wordGap = MorseCode.Timing.farnsworthWordGap(effectiveWPM: effectiveWPM)
        }
    }

    func setFrequency(_ frequency: Double) {
        self.frequency = max(400, min(800, frequency))
    }

    func setEffectiveSpeed(_ wpm: Int) {
        self.effectiveSpeed = max(10, min(18, wpm))
    }

    func configureBandConditions(from settings: AppSettings) {
        toneGenerator.bandConditionsProcessor.configure(from: settings)
    }

    /// Play a single character in Morse code.
    func playCharacter(_ char: Character) async {
        guard !isStopped else { return }

        guard let pattern = MorseCode.pattern(for: char) else {
            print("Unknown character: \(char)")
            return
        }

        for (index, element) in pattern.enumerated() {
            guard !isStopped else { return }

            switch element {
            case ".":
                await toneGenerator.playTone(frequency: frequency, duration: timing.ditDuration)
            case "-":
                await toneGenerator.playTone(frequency: frequency, duration: timing.dahDuration)
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
        await toneGenerator.playTone(frequency: frequency, duration: timing.ditDuration)
    }

    /// Play a single dah (long tone).
    func playDah() async {
        guard !isStopped else { return }
        await toneGenerator.playTone(frequency: frequency, duration: timing.dahDuration)
    }

    /// Play a group of characters (word or character group).
    func playGroup(_ group: String) async {
        let characters = Array(group.uppercased())

        for (index, char) in characters.enumerated() {
            guard !isStopped else { return }

            if char == " " {
                // Word gap (minus character gap already waited)
                await toneGenerator.playSilence(duration: timing.wordGap - timing.characterGap)
            } else {
                await playCharacter(char)

                // Inter-character gap (except after last character or before space)
                if index < characters.count - 1 && characters[index + 1] != " " {
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
}
