import Foundation
@testable import KochTrainer

/// A silent implementation of AudioEngineProtocol for testing.
/// All methods return immediately without playing audio or waiting.
@MainActor
final class SilentAudioEngine: AudioEngineProtocol {

    // MARK: Internal

    private(set) var playedCharacters: [Character] = []
    private(set) var playedGroups: [String] = []

    var radioMode: RadioMode {
        radioState.mode
    }

    func playCharacter(_ char: Character) async {
        playedCharacters.append(char)
    }

    func playGroup(_ group: String) async {
        playedGroups.append(group)
    }

    func playGroup(_ group: String, onCharacterPlayed: ((Character, Int) -> Void)?) async {
        playedGroups.append(group)
        // Call the callback for each character if provided
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

    func stop() {
        // Silent - no-op
    }

    func reset() {
        playedCharacters.removeAll()
        playedGroups.removeAll()
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
        radioState.startSession()
    }

    func endSession() {
        radioState.endSession()
    }

    // MARK: - Radio Control API

    func startReceiving() throws {
        try radioState.startReceiving()
    }

    func startTransmitting() throws {
        try radioState.startTransmitting()
    }

    func stopRadio() throws {
        try radioState.stopRadio()
    }

    // MARK: Private

    // MARK: - Radio State (shared helper)

    private let radioState = MockRadioState()

}
