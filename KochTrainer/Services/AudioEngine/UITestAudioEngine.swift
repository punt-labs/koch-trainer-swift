import Foundation

/// A silent implementation of AudioEngineProtocol for UI testing.
/// All methods return immediately without playing audio.
/// Named UITestAudioEngine to distinguish from the test helper SilentAudioEngine.
@MainActor
final class UITestAudioEngine: AudioEngineProtocol, ObservableObject {

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
        for (index, char) in group.enumerated() {
            onCharacterPlayed?(char, index)
        }
    }

    func playDit() async {
        // Silent - no-op
    }

    func playDah() async {
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

    // MARK: - Radio Control API

    func startReceiving() throws {
        guard storedRadioMode == .off else {
            throw Radio.RadioError.mustBeOff(current: storedRadioMode)
        }
        storedRadioMode = .receiving
    }

    func startTransmitting() throws {
        guard storedRadioMode == .off else {
            throw Radio.RadioError.mustBeOff(current: storedRadioMode)
        }
        storedRadioMode = .transmitting
    }

    func stopRadio() throws {
        guard storedRadioMode != .off else {
            throw Radio.RadioError.alreadyOff
        }
        storedRadioMode = .off
    }

    // MARK: - Tone Control API

    func activateTone(frequency: Double) throws {
        guard storedRadioMode != .off else {
            throw Radio.RadioError.mustBeOn
        }
        // Silent - no-op
    }

    func deactivateTone() {
        // Silent - no-op
    }

    // MARK: Private

    private var storedRadioMode: RadioMode = .off

}
