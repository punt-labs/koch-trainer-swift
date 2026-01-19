import Combine
import Foundation

// MARK: - MorseQSOViewModel

/// ViewModel for Morse QSO training sessions.
/// Coordinates QSO state machine with dit/dah keying input and progressive text reveal.
@MainActor
final class MorseQSOViewModel: ObservableObject {

    // MARK: Lifecycle

    init(style: QSOStyle, callsign: String, audioEngine: AudioEngineProtocol? = nil) {
        self.style = style
        myCallsign = callsign
        self.audioEngine = audioEngine ?? MorseAudioEngine()
        engine = QSOEngine(style: style, myCallsign: callsign, audioEngine: self.audioEngine)
    }

    // MARK: Internal

    // MARK: - Turn State

    enum TurnState: Equatable {
        case idle
        case aiTransmitting
        case userKeying
        case completed
    }

    // MARK: - Published State

    @Published private(set) var turnState: TurnState = .idle
    @Published private(set) var isSessionActive: Bool = false

    // AI turn state
    @Published private(set) var aiMessage: String = ""
    @Published private(set) var revealedText: String = ""
    @Published private(set) var isPlayingAudio: Bool = false

    // User turn state
    @Published private(set) var currentScript: String = ""
    @Published private(set) var currentPattern: String = ""
    @Published private(set) var scriptIndex: Int = 0
    @Published private(set) var inputTimeRemaining: TimeInterval = 0

    // Accuracy tracking
    @Published private(set) var totalCharactersKeyed: Int = 0
    @Published private(set) var correctCharactersKeyed: Int = 0
    @Published private(set) var lastKeyedCharacter: Character?
    @Published private(set) var lastKeyedWasCorrect: Bool = false

    // Session info
    let style: QSOStyle
    let myCallsign: String

    // MARK: - Configuration

    let inputTimeout: TimeInterval = 2.0

    var revealDelay: TimeInterval {
        settingsStore?.settings.morseQSORevealDelay ?? 0.3
    }

    var phase: QSOPhase {
        engine.state.phase
    }

    var phaseDescription: String {
        phase.userAction
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

    var keyingAccuracy: Double {
        guard totalCharactersKeyed > 0 else { return 0 }
        return Double(correctCharactersKeyed) / Double(totalCharactersKeyed)
    }

    var accuracyPercentage: Int {
        Int(keyingAccuracy * 100)
    }

    var inputProgress: Double {
        guard inputTimeout > 0 else { return 0 }
        return inputTimeRemaining / inputTimeout
    }

    var currentExpectedCharacter: Character? {
        guard scriptIndex < currentScript.count else { return nil }
        return currentScript[currentScript.index(currentScript.startIndex, offsetBy: scriptIndex)]
    }

    var isCompleted: Bool {
        turnState == .completed
    }

    var transcript: [QSOMessage] {
        engine.state.transcript
    }

    func configure(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        engine.configureAudio(
            frequency: settingsStore.settings.toneFrequency,
            effectiveSpeed: settingsStore.settings.effectiveSpeed,
            settings: settingsStore.settings
        )
    }

    // MARK: - Session Control

    func startSession() {
        isSessionActive = true
        sessionStartTime = Date()
        totalCharactersKeyed = 0
        correctCharactersKeyed = 0

        engine.startQSO()
        startUserTurn()
    }

    func endSession() {
        isSessionActive = false
        turnState = .completed
        inputTimer?.invalidate()
        revealTimer?.invalidate()
        audioEngine.stop()
    }

    func cleanup() {
        inputTimer?.invalidate()
        inputTimer = nil
        revealTimer?.invalidate()
        revealTimer = nil
        audioEngine.stop()
    }

    // MARK: - Input Handling

    func handleKeyPress(_ key: Character) {
        guard turnState == .userKeying else { return }

        let keyLower = Character(key.lowercased())
        if keyLower == "." || keyLower == "f" {
            inputDit()
        } else if keyLower == "-" || keyLower == "j" {
            inputDah()
        }
    }

    func inputDit() {
        guard turnState == .userKeying else { return }
        currentPattern += "."
        playDit()
        resetInputTimer()
    }

    func inputDah() {
        guard turnState == .userKeying else { return }
        currentPattern += "-"
        playDah()
        resetInputTimer()
    }

    // MARK: - Results

    func getResult() -> MorseQSOResult {
        let duration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        return MorseQSOResult(
            style: style,
            myCallsign: myCallsign,
            theirCallsign: theirCallsign,
            theirName: theirName,
            theirQTH: theirQTH,
            duration: duration,
            totalCharactersKeyed: totalCharactersKeyed,
            correctCharactersKeyed: correctCharactersKeyed,
            exchangesCompleted: engine.state.exchangeCount
        )
    }

    // MARK: Private

    private let engine: QSOEngine
    private let audioEngine: AudioEngineProtocol
    private var settingsStore: SettingsStore?
    private var sessionStartTime: Date?
    private var inputTimer: Timer?
    private var revealTimer: Timer?
    private var revealIndex: Int = 0

    // MARK: - User Turn

    private func startUserTurn() {
        turnState = .userKeying
        currentScript = generateUserScript()
        scriptIndex = 0
        currentPattern = ""
        inputTimeRemaining = 0
        lastKeyedCharacter = nil
    }

    private func generateUserScript() -> String {
        // Get the hint from QSOTemplate and clean it up
        var script = QSOTemplate.userHint(for: engine.state)

        // Replace placeholder patterns with actual values
        script = script.replacingOccurrences(of: "[YOUR NAME]", with: "OP")
        script = script.replacingOccurrences(of: "[YOUR QTH]", with: "QTH")
        script = script.replacingOccurrences(of: "[YOUR RIG]", with: "RIG")
        script = script.replacingOccurrences(of: "[WEATHER]", with: "WX FB")
        script = script.replacingOccurrences(of: "[NAME]", with: "OP")
        script = script.replacingOccurrences(of: "[LOCATION]", with: "QTH")

        // Remove waiting messages (these aren't things to send)
        if script.contains("Waiting") || script.contains("QSO Complete") {
            return ""
        }

        return script
    }

    private func completeCurrentCharacter() {
        guard !currentPattern.isEmpty else { return }
        guard let expected = currentExpectedCharacter else { return }

        let decoded = MorseCode.character(for: currentPattern)
        let isCorrect = decoded == expected

        totalCharactersKeyed += 1
        if isCorrect {
            correctCharactersKeyed += 1
        }

        lastKeyedCharacter = decoded
        lastKeyedWasCorrect = isCorrect

        currentPattern = ""
        scriptIndex += 1

        // Check if script is complete
        if scriptIndex >= currentScript.count {
            completeUserTurn()
        }
    }

    private func completeUserTurn() {
        inputTimer?.invalidate()

        Task {
            // Submit the script to QSO engine (advances state machine)
            await engine.processUserInput(currentScript)

            // Check if QSO completed
            if engine.state.phase == .completed {
                turnState = .completed
            } else {
                // Start AI turn
                await startAITurn()
            }
        }
    }

    // MARK: - AI Turn

    private func startAITurn() async {
        turnState = .aiTransmitting
        isPlayingAudio = true
        revealedText = ""
        revealIndex = 0

        // Wait for engine to play AI response (it does this internally after processUserInput)
        // The engine already played the audio, we just need to reveal the text
        // Get the last station message from transcript
        if let lastMessage = engine.state.transcript.last, lastMessage.sender == .station {
            aiMessage = lastMessage.text
            await revealTextProgressively(aiMessage)
        }

        isPlayingAudio = false

        // Check if QSO completed
        if engine.state.phase == .completed {
            turnState = .completed
        } else {
            startUserTurn()
        }
    }

    private func revealTextProgressively(_ text: String) async {
        revealedText = ""
        for index in text.indices {
            let prefixEnd = text.index(after: index)
            revealedText = String(text[text.startIndex ..< prefixEnd])

            // Wait for reveal delay (unless it's the last character)
            if index < text.index(before: text.endIndex) {
                try? await Task.sleep(nanoseconds: UInt64(revealDelay * 1_000_000_000))
            }
        }
    }

    // MARK: - Timer Management

    private func resetInputTimer() {
        inputTimeRemaining = inputTimeout
        inputTimer?.invalidate()
        inputTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickInput() }
        }
    }

    private func tickInput() {
        inputTimeRemaining -= 0.05
        if inputTimeRemaining <= 0 {
            inputTimer?.invalidate()
            completeCurrentCharacter()
        }
    }

    // MARK: - Audio

    private func playDit() {
        Task {
            if let engine = audioEngine as? MorseAudioEngine {
                await engine.playDit()
            }
        }
    }

    private func playDah() {
        Task {
            if let engine = audioEngine as? MorseAudioEngine {
                await engine.playDah()
            }
        }
    }
}
