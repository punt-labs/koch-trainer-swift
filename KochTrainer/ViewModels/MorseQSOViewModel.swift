import Combine
import Foundation

// MARK: - MorseQSOViewModel

/// ViewModel for Morse QSO training sessions.
/// Coordinates QSO state machine with dit/dah keying input and progressive text reveal.
@MainActor
final class MorseQSOViewModel: ObservableObject {

    // MARK: Lifecycle

    init(style: QSOStyle, callsign: String, aiStarts: Bool = true, audioEngine: AudioEngineProtocol? = nil) {
        self.style = style
        myCallsign = callsign
        self.aiStarts = aiStarts
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
    @Published var isAITextVisible: Bool = true

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

    // Speed tracking for current user turn
    @Published private(set) var currentBlockCharactersKeyed: Int = 0

    // Session info
    let style: QSOStyle
    let myCallsign: String
    let aiStarts: Bool

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

    /// The portion of the script the user has typed so far
    var typedScript: String {
        guard scriptIndex > 0, scriptIndex <= currentScript.count else { return "" }
        let endIndex = currentScript.index(currentScript.startIndex, offsetBy: scriptIndex)
        return String(currentScript[currentScript.startIndex ..< endIndex])
    }

    /// Computed WPM for the current user turn block
    var currentBlockWPM: Int {
        guard let startTime = currentBlockStartTime,
              currentBlockCharactersKeyed > 0 else { return 0 }

        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed > 0 else { return 0 }

        // Standard WPM calculation: (characters / 5) / minutes
        // 5 characters = 1 word (PARIS standard)
        let minutes = elapsed / 60.0
        let words = Double(currentBlockCharactersKeyed) / 5.0
        return Int(words / minutes)
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

        if aiStarts {
            // AI calls CQ first, user responds
            Task {
                await startAITurnWithCQ()
            }
        } else {
            // User calls CQ first
            engine.startQSO()
            startUserTurn()
        }
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
    private var currentBlockStartTime: Date?
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
        // Reset block speed tracking
        currentBlockStartTime = nil
        currentBlockCharactersKeyed = 0
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

        // Start block timer on first character
        if currentBlockStartTime == nil {
            currentBlockStartTime = Date()
        }

        totalCharactersKeyed += 1
        currentBlockCharactersKeyed += 1
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
            // playAudio: false so we can handle audio with synced text reveal
            let response = await engine.processUserInput(currentScript, playAudio: false)

            // Check if QSO completed
            if engine.state.phase == .completed {
                turnState = .completed
            } else if let response {
                // Start AI turn with the response
                await startAITurn(withResponse: response)
            } else {
                // No AI response (e.g., rag chew continuation), start user turn
                startUserTurn()
            }
        }
    }

    // MARK: - AI Turn

    /// Start QSO with AI calling CQ (Answer CQ mode)
    private func startAITurnWithCQ() async {
        turnState = .aiTransmitting
        isPlayingAudio = true
        revealedText = ""

        // Engine handles state setup and returns the CQ message
        let cqCall = engine.startWithAICQ()
        aiMessage = cqCall

        // Play audio with synced text reveal
        await playWithSyncedReveal(cqCall)

        isPlayingAudio = false
        startUserTurn()
    }

    /// Handle AI turn after user input (response text passed from completeUserTurn)
    private func startAITurn(withResponse response: String) async {
        turnState = .aiTransmitting
        isPlayingAudio = true
        revealedText = ""
        aiMessage = response

        // Play audio with synced text reveal
        await playWithSyncedReveal(response)

        isPlayingAudio = false

        // Check if QSO completed
        if engine.state.phase == .completed {
            turnState = .completed
        } else {
            startUserTurn()
        }
    }

    /// Play audio and reveal text character-by-character in sync
    private func playWithSyncedReveal(_ text: String) async {
        revealedText = ""

        if let morseEngine = audioEngine as? MorseAudioEngine {
            await morseEngine.playGroup(text) { [weak self] _, index in
                guard let self else { return }
                // Reveal text up to and including the character just played
                let endIndex = text.index(text.startIndex, offsetBy: index + 1)
                revealedText = String(text[text.startIndex ..< endIndex])
            }
        }

        // Ensure full text is revealed at the end
        revealedText = text
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
