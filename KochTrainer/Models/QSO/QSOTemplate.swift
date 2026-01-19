import Foundation

// MARK: - QSOTemplate

/// Templates for generating QSO messages
enum QSOTemplate {

    // MARK: Internal

    // MARK: - User Hints (what the user should send)

    /// Get a hint for what the user should send next
    static func userHint(for state: QSOState) -> String {
        switch state.phase {
        case .idle,
             .callingCQ:
            return "CQ CQ CQ DE \(state.myCallsign) \(state.myCallsign) K"

        case .awaitingResponse:
            return "Waiting for a station to respond..."

        case .receivedCall:
            return receivedCallHint(for: state)

        case .sendingExchange:
            return sendingExchangeHint(for: state)

        case .awaitingExchange:
            return "Waiting for their exchange..."

        case .exchangeReceived:
            return exchangeReceivedHint(for: state)

        case .signing:
            return "73 DE \(state.myCallsign) SK"

        case .completed:
            return "QSO Complete!"
        }
    }

    // MARK: - AI Station Responses

    /// Generate AI station CQ call (for Answer CQ mode)
    static func aiCQCall(station: VirtualStation) -> String {
        let formats = [
            "CQ CQ CQ DE \(station.callsign) \(station.callsign) K",
            "CQ CQ DE \(station.callsign) \(station.callsign) K",
            "CQ CQ CQ DE \(station.callsign) K"
        ]
        return formats[Int.random(in: 0 ..< formats.count)]
    }

    /// Generate AI station response for the given state
    static func aiResponse(for state: QSOState, station: VirtualStation) -> String {
        switch state.phase {
        case .idle:
            return "" // AI doesn't initiate in Call CQ mode

        case .callingCQ,
             .awaitingResponse:
            // AI calls in response to user's CQ
            return "\(state.myCallsign) DE \(station.callsign) \(station.callsign) K"

        case .receivedCall:
            // Shouldn't happen - user sends exchange first
            return ""

        case .sendingExchange,
             .awaitingExchange:
            // AI sends their exchange based on style
            return aiExchange(for: state, station: station)

        case .exchangeReceived:
            // AI acknowledges and may send more in rag chew
            return aiAcknowledgment(for: state, station: station)

        case .signing:
            return "73 DE \(station.callsign) SK"

        case .completed:
            return ""
        }
    }

    // MARK: - Validation

    /// Check if user input is valid for the current phase
    static func validateUserInput(_ input: String, for state: QSOState) -> ValidationResult {
        let cleaned = input.uppercased().trimmingCharacters(in: .whitespaces)

        switch state.phase {
        case .idle,
             .callingCQ:
            // Should contain CQ and callsign
            if cleaned.contains("CQ"), cleaned.contains(state.myCallsign) {
                return .valid
            }
            return .invalid(hint: "Include 'CQ' and your callsign")

        case .receivedCall,
             .sendingExchange:
            // Should contain some exchange info
            if cleaned.contains(state.theirCallsign) || cleaned.contains("5") || cleaned.contains("9") {
                return .valid
            }
            return .invalid(hint: "Include their callsign or signal report")

        case .exchangeReceived:
            // Should be acknowledgment or sign-off
            if cleaned.contains("73") || cleaned.contains("TU") || cleaned.contains("TNX") || cleaned.contains("K") {
                return .valid
            }
            return .invalid(hint: "Send acknowledgment (TU, TNX) or sign-off (73)")

        case .signing:
            if cleaned.contains("73") || cleaned.contains("SK") {
                return .valid
            }
            return .invalid(hint: "Send '73' or 'SK' to end")

        default:
            return .valid
        }
    }

    // MARK: Private

    // MARK: - User Hint Helpers

    private static func receivedCallHint(for state: QSOState) -> String {
        switch state.style {
        case .firstContact:
            return "\(state.theirCallsign) DE \(state.myCallsign) UR RST \(state.myRST) K"
        case .signalReport:
            return "\(state.theirCallsign) DE \(state.myCallsign) UR RST \(state.myRST) NAME [NAME] K"
        case .contest:
            return "\(state.theirCallsign) \(state.myRST) \(formatSerial(state.mySerialNumber)) K"
        case .ragChew:
            return "\(state.theirCallsign) DE \(state.myCallsign) GM TNX FER CALL UR RST \(state.myRST) NAME HR IS [YOUR NAME] QTH [YOUR QTH] K"
        }
    }

    private static func sendingExchangeHint(for state: QSOState) -> String {
        switch state.style {
        case .firstContact:
            return "UR RST \(state.myRST) K"
        case .signalReport:
            return "UR RST \(state.myRST) NAME [NAME] K"
        case .contest:
            return "\(state.myRST) \(formatSerial(state.mySerialNumber)) K"
        case .ragChew:
            return "UR RST \(state.myRST) NAME HR IS [NAME] QTH [LOCATION] K"
        }
    }

    private static func exchangeReceivedHint(for state: QSOState) -> String {
        switch state.style {
        case .firstContact:
            return "TNX 73 DE \(state.myCallsign) SK"
        case .signalReport:
            return "TNX FER QSO 73 DE \(state.myCallsign) SK"
        case .contest:
            return "TU 73 DE \(state.myCallsign) SK"
        case .ragChew:
            if state.exchangeCount < 2 {
                return "RIG HR IS [YOUR RIG] WX [WEATHER] HW? K"
            } else {
                return "TNX FER QSO 73 DE \(state.myCallsign) SK"
            }
        }
    }

    // MARK: - AI Exchange Helpers

    private static func aiExchange(for state: QSOState, station: VirtualStation) -> String {
        switch state.style {
        case .firstContact:
            return firstContactExchange(state: state, station: station)
        case .signalReport:
            return signalReportExchange(state: state, station: station)
        case .contest:
            return contestExchange(station: station)
        case .ragChew:
            return ragChewExchange(state: state, station: station)
        }
    }

    private static func aiAcknowledgment(for state: QSOState, station: VirtualStation) -> String {
        switch state.style {
        case .firstContact:
            return "TNX 73 DE \(station.callsign) SK"
        case .signalReport:
            return "TNX FER QSO 73 DE \(station.callsign) SK"
        case .contest:
            return "TU \(station.callsign)"
        case .ragChew:
            if state.exchangeCount < 2 {
                return ragChewSecondExchange(station: station)
            } else {
                return "TNX FER QSO \(state.myCallsign) 73 DE \(station.callsign) SK"
            }
        }
    }

    // MARK: - First Contact Templates (Beginner)

    private static func firstContactExchange(state: QSOState, station: VirtualStation) -> String {
        let rst = station.randomRST
        return "R \(state.myCallsign) UR RST \(rst) K"
    }

    // MARK: - Signal Report Templates (Intermediate)

    private static func signalReportExchange(state: QSOState, station: VirtualStation) -> String {
        let rst = station.randomRST
        return "R \(state.myCallsign) UR RST \(rst) NAME IS \(station.name) K"
    }

    // MARK: - Contest Templates

    private static func contestExchange(station: VirtualStation) -> String {
        let rst = station.randomRST
        let serial = station.formattedSerialNumber
        // Vary the format slightly for realism
        let formats = [
            "\(rst) \(serial) \(serial) K",
            "UR \(rst) NR \(serial) K",
            "\(rst) \(serial) K"
        ]
        return formats[Int.random(in: 0 ..< formats.count)]
    }

    // MARK: - Rag Chew Templates

    private static func ragChewExchange(state: QSOState, station: VirtualStation) -> String {
        let rst = station.randomRST
        let templates = [
            "R R \(state.myCallsign) UR RST \(rst) \(rst) NAME HR IS \(station.name) \(station.name) QTH IS \(station.qth) HW? K",
            "GM TNX FER RPT UR RST \(rst) NAME IS \(station.name) QTH \(station.qth) K",
            "TNX \(state.myCallsign) UR \(rst) HR NAME \(station.name) IN \(station.qth) HW CPY? K"
        ]
        return templates[Int.random(in: 0 ..< templates.count)]
    }

    private static func ragChewSecondExchange(station: VirtualStation) -> String {
        let templates = [
            "RIG HR IS \(station.rig) WX IS FB HR HW UR WX? K",
            "RUNNING \(station.rig) INTO DIPOLE ANT WX GUD HR K",
            "USING \(station.rig) WX NICE AND SUNNY K"
        ]
        return templates[Int.random(in: 0 ..< templates.count)]
    }

    // MARK: - Helpers

    private static func formatSerial(_ number: Int) -> String {
        String(format: "%03d", number)
    }
}

// MARK: - ValidationResult

enum ValidationResult: Equatable {
    case valid
    case invalid(hint: String)

    // MARK: Internal

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var hint: String? {
        if case let .invalid(hint) = self { return hint }
        return nil
    }
}
