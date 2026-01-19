import Foundation
import Combine

/// ViewModel for QSO session, wraps QSOEngine for UI binding
@MainActor
final class QSOViewModel: ObservableObject {

    // MARK: - Published State

    @Published var userInput: String = ""
    @Published var showHint: Bool = false
    @Published private(set) var isSessionActive: Bool = false

    // MARK: - Engine

    let engine: QSOEngine

    // MARK: - Computed Properties

    var phase: QSOPhase {
        engine.state.phase
    }

    var transcript: [QSOMessage] {
        engine.state.transcript
    }

    var currentHint: String {
        engine.getCurrentHint()
    }

    var isPlaying: Bool {
        engine.isPlayingAudio
    }

    var theirCallsign: String {
        engine.station.callsign
    }

    var theirName: String {
        engine.station.name
    }

    var theirQTH: String {
        engine.station.qth
    }

    var myCallsign: String {
        engine.state.myCallsign
    }

    var style: QSOStyle {
        engine.state.style
    }

    var isCompleted: Bool {
        phase == .completed
    }

    var validationHint: String? {
        engine.lastValidationResult.hint
    }

    // MARK: - Initialization

    init(style: QSOStyle, callsign: String) {
        self.engine = QSOEngine(style: style, myCallsign: callsign)
    }

    // MARK: - Configuration

    func configure(settingsStore: SettingsStore) {
        engine.configureAudio(
            frequency: settingsStore.settings.toneFrequency,
            effectiveSpeed: settingsStore.settings.effectiveSpeed,
            settings: settingsStore.settings
        )
    }

    // MARK: - Session Control

    func startSession() {
        isSessionActive = true
        engine.startQSO()
    }

    func endSession() {
        engine.stopAudio()
        isSessionActive = false
    }

    func reset() {
        engine.reset()
        userInput = ""
        showHint = false
        isSessionActive = false
    }

    // MARK: - Input Handling

    func submitInput() async {
        guard !userInput.isEmpty else { return }

        let input = userInput
        userInput = ""
        showHint = false

        await engine.processUserInput(input)
    }

    func toggleHint() {
        showHint.toggle()
    }

    // MARK: - Result

    func getResult() -> QSOResult {
        QSOResult(from: engine.state)
    }
}
