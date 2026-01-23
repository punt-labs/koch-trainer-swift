import Foundation

/// A silent implementation of AudioEngineProtocol for UI testing.
/// All methods return immediately without playing audio.
@MainActor
final class SilentAudioEngine: AudioEngineProtocol, ObservableObject {

    // MARK: Internal

    var radioMode: RadioMode {
        storedRadioMode
    }

    // MARK: - AudioEngineProtocol

    func playCharacter(_ char: Character) async {
        // Silent - no-op
    }

    func playGroup(_ group: String) async {
        // Silent - no-op
    }

    func playGroup(_ group: String, onCharacterPlayed: ((Character, Int) -> Void)?) async {
        // Call the callback for each character if provided (for progress tracking)
        for (index, char) in group.enumerated() where !char.isWhitespace {
            onCharacterPlayed?(char, index)
        }
    }

    func playDit() async {
        // Silent - no-op
    }

    func playDah() async {
        // Silent - no-op
    }

    func stop() {
        // Silent - no-op
    }

    func reset() {
        // Silent - no-op
    }

    func setFrequency(_ frequency: Double) {
        // Silent - no-op
    }

    func setEffectiveSpeed(_ wpm: Int) {
        // Silent - no-op
    }

    func configureBandConditions(from settings: AppSettings) {
        // Silent - no-op
    }

    func startSession() {
        storedRadioMode = .receiving
    }

    func endSession() {
        storedRadioMode = .off
    }

    func setRadioMode(_ mode: RadioMode) {
        storedRadioMode = mode
    }

    // MARK: Private

    // MARK: - RadioMode

    private var storedRadioMode: RadioMode = .off

}
