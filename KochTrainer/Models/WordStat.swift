import Foundation

/// Performance statistics for a single word in vocabulary training.
struct WordStat: Codable, Equatable {

    // MARK: Lifecycle

    init(
        receiveAttempts: Int = 0,
        receiveCorrect: Int = 0,
        sendAttempts: Int = 0,
        sendCorrect: Int = 0,
        lastPracticed: Date = Date()
    ) {
        self.receiveAttempts = receiveAttempts
        self.receiveCorrect = receiveCorrect
        self.sendAttempts = sendAttempts
        self.sendCorrect = sendCorrect
        self.lastPracticed = lastPracticed
    }

    // MARK: Internal

    /// Receive training stats (audio → text)
    var receiveAttempts: Int
    var receiveCorrect: Int

    /// Send training stats (text → keying)
    var sendAttempts: Int
    var sendCorrect: Int

    var lastPracticed: Date

    var totalAttempts: Int {
        receiveAttempts + sendAttempts
    }

    var totalCorrect: Int {
        receiveCorrect + sendCorrect
    }

    var receiveAccuracy: Double {
        guard receiveAttempts > 0 else { return 0 }
        return Double(receiveCorrect) / Double(receiveAttempts)
    }

    var sendAccuracy: Double {
        guard sendAttempts > 0 else { return 0 }
        return Double(sendCorrect) / Double(sendAttempts)
    }

    var combinedAccuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAttempts)
    }

    /// Get accuracy for a specific session type
    func accuracy(for sessionType: BaseSessionType) -> Double {
        switch sessionType {
        case .receive: return receiveAccuracy
        case .send: return sendAccuracy
        }
    }

    /// Merge another stat into this one
    mutating func merge(_ other: WordStat) {
        receiveAttempts += other.receiveAttempts
        receiveCorrect += other.receiveCorrect
        sendAttempts += other.sendAttempts
        sendCorrect += other.sendCorrect
        if other.lastPracticed > lastPracticed {
            lastPracticed = other.lastPracticed
        }
    }
}
