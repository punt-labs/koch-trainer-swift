import Foundation

/// QSO conversation style
enum QSOStyle: String, Codable, CaseIterable {
    case contest    // Short structured: RST + serial number
    case ragChew    // Casual: name, QTH, weather, rig, etc.

    var displayName: String {
        switch self {
        case .contest: return "Contest"
        case .ragChew: return "Rag Chew"
        }
    }

    var description: String {
        switch self {
        case .contest:
            return "Quick exchanges: signal report and serial number"
        case .ragChew:
            return "Casual conversation: names, locations, weather"
        }
    }
}

/// Phase of the QSO conversation
enum QSOPhase: String, Codable, Equatable {
    case idle               // Not started
    case callingCQ          // User sending CQ
    case awaitingResponse   // Waiting for AI station to respond
    case receivedCall       // AI station has called us
    case sendingExchange    // User sending their exchange
    case awaitingExchange   // Waiting for AI exchange
    case exchangeReceived   // AI sent their exchange
    case signing            // Sign-off phase (73/SK)
    case completed          // QSO finished

    var userAction: String {
        switch self {
        case .idle: return "Start by sending CQ"
        case .callingCQ: return "Send CQ CQ CQ DE [your call] K"
        case .awaitingResponse: return "Wait for station to call..."
        case .receivedCall: return "Acknowledge the calling station"
        case .sendingExchange: return "Send your exchange"
        case .awaitingExchange: return "Wait for their exchange..."
        case .exchangeReceived: return "Copy their exchange and respond"
        case .signing: return "Send 73 or SK to end"
        case .completed: return "QSO complete!"
        }
    }
}

/// A single message in the QSO transcript
struct QSOMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let sender: QSOSender
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), sender: QSOSender, text: String, timestamp: Date = Date()) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
    }
}

/// Who sent the message
enum QSOSender: String, Codable, Equatable {
    case user       // The user/operator
    case station    // The AI virtual station
}

/// Complete state of an ongoing QSO
struct QSOState: Codable, Equatable {
    var phase: QSOPhase
    var style: QSOStyle
    var myCallsign: String
    var theirCallsign: String
    var theirName: String
    var theirQTH: String
    var mySerialNumber: Int
    var theirSerialNumber: Int
    var myRST: String
    var theirRST: String
    var transcript: [QSOMessage]
    var startTime: Date
    var exchangeCount: Int

    init(
        style: QSOStyle,
        myCallsign: String,
        theirCallsign: String = "",
        theirName: String = "",
        theirQTH: String = ""
    ) {
        self.phase = .idle
        self.style = style
        self.myCallsign = myCallsign.uppercased()
        self.theirCallsign = theirCallsign.uppercased()
        self.theirName = theirName
        self.theirQTH = theirQTH
        self.mySerialNumber = 1
        self.theirSerialNumber = 0
        self.myRST = "599"
        self.theirRST = ""
        self.transcript = []
        self.startTime = Date()
        self.exchangeCount = 0
    }

    /// Add a message to the transcript
    mutating func addMessage(from sender: QSOSender, text: String) {
        let message = QSOMessage(sender: sender, text: text)
        transcript.append(message)
    }

    /// Duration of the QSO so far
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}
