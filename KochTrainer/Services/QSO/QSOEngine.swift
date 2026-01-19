import Foundation
import Combine

/// Engine that manages QSO state machine and AI station behavior
@MainActor
final class QSOEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set) var state: QSOState
    @Published private(set) var station: VirtualStation
    @Published private(set) var isPlayingAudio: Bool = false
    @Published private(set) var lastValidationResult: ValidationResult = .valid

    // MARK: - Dependencies

    private let audioEngine: AudioEngineProtocol

    // MARK: - Configuration

    /// Delay before AI responds (simulates listening/thinking)
    private let aiResponseDelay: TimeInterval = 1.5

    // MARK: - Initialization

    init(
        style: QSOStyle,
        myCallsign: String,
        audioEngine: AudioEngineProtocol? = nil
    ) {
        self.state = QSOState(style: style, myCallsign: myCallsign)
        self.station = VirtualStation.randomOrPreset()
        self.audioEngine = audioEngine ?? MorseAudioEngine()
    }

    /// Configure audio settings
    func configureAudio(frequency: Double, effectiveSpeed: Int, settings: AppSettings) {
        audioEngine.setFrequency(frequency)
        audioEngine.setEffectiveSpeed(effectiveSpeed)
        audioEngine.configureBandConditions(from: settings)
    }

    // MARK: - QSO Flow Control

    /// Start a new QSO
    func startQSO() {
        state = QSOState(style: state.style, myCallsign: state.myCallsign)
        station = VirtualStation.randomOrPreset()
        state.phase = .callingCQ
    }

    /// Process user input and advance the state machine
    func processUserInput(_ input: String) async {
        let trimmed = input.uppercased().trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Validate input
        lastValidationResult = QSOTemplate.validateUserInput(trimmed, for: state)

        // Add to transcript even if not perfectly valid
        state.addMessage(from: .user, text: trimmed)

        // Advance state based on current phase
        switch state.phase {
        case .callingCQ:
            state.phase = .awaitingResponse
            await generateAndPlayAIResponse()

        case .receivedCall:
            state.phase = .awaitingExchange
            state.exchangeCount += 1
            await generateAndPlayAIResponse()

        case .sendingExchange:
            state.phase = .awaitingExchange
            state.exchangeCount += 1
            await generateAndPlayAIResponse()

        case .exchangeReceived:
            if state.style == .contest || state.exchangeCount >= 2 {
                state.phase = .signing
                await generateAndPlayAIResponse()
            } else {
                // More exchanges in rag chew
                state.phase = .sendingExchange
            }

        case .signing:
            state.phase = .completed

        default:
            break
        }
    }

    /// Get hint for current phase
    func getCurrentHint() -> String {
        QSOTemplate.userHint(for: state)
    }

    /// Reset for a new QSO with the same settings
    func reset() {
        state = QSOState(style: state.style, myCallsign: state.myCallsign)
        station = VirtualStation.randomOrPreset()
        lastValidationResult = .valid
    }

    // MARK: - AI Response Generation

    private func generateAndPlayAIResponse() async {
        // Small delay to simulate the other station listening/responding
        try? await Task.sleep(nanoseconds: UInt64(aiResponseDelay * 1_000_000_000))

        let response = QSOTemplate.aiResponse(for: state, station: station)
        guard !response.isEmpty else { return }

        // Update state with AI info
        state.theirCallsign = station.callsign
        state.theirName = station.name
        state.theirQTH = station.qth
        state.theirRST = station.randomRST
        state.theirSerialNumber = station.serialNumber

        // Add to transcript
        state.addMessage(from: .station, text: response)

        // Play audio
        await playMessage(response)

        // Advance to next phase after AI responds
        advancePhaseAfterAIResponse()
    }

    private func advancePhaseAfterAIResponse() {
        switch state.phase {
        case .awaitingResponse:
            state.phase = .receivedCall

        case .awaitingExchange:
            state.phase = .exchangeReceived

        case .signing:
            state.phase = .completed

        default:
            break
        }
    }

    // MARK: - Audio Playback

    private func playMessage(_ message: String) async {
        isPlayingAudio = true
        defer { isPlayingAudio = false }

        if let engine = audioEngine as? MorseAudioEngine {
            engine.reset()
            await engine.playGroup(message)
        }
    }

    /// Stop any ongoing audio playback
    func stopAudio() {
        audioEngine.stop()
        isPlayingAudio = false
    }
}

// MARK: - QSO Result

/// Summary of a completed QSO
struct QSOResult {
    let style: QSOStyle
    let myCallsign: String
    let theirCallsign: String
    let theirName: String
    let theirQTH: String
    let duration: TimeInterval
    let exchangeCount: Int
    let transcript: [QSOMessage]

    init(from state: QSOState) {
        self.style = state.style
        self.myCallsign = state.myCallsign
        self.theirCallsign = state.theirCallsign
        self.theirName = state.theirName
        self.theirQTH = state.theirQTH
        self.duration = state.duration
        self.exchangeCount = state.exchangeCount
        self.transcript = state.transcript
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
