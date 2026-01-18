import Foundation

/// The type of training session.
enum SessionType: String, Codable {
    case receive
    case send

    var displayName: String {
        switch self {
        case .receive: return "Receive"
        case .send: return "Send"
        }
    }
}

/// Result of a completed training session.
struct SessionResult: Codable, Equatable, Identifiable {
    let id: UUID
    let sessionType: SessionType
    let duration: TimeInterval
    let totalAttempts: Int
    let correctCount: Int
    let characterStats: [Character: CharacterStat]
    let date: Date

    init(
        id: UUID = UUID(),
        sessionType: SessionType,
        duration: TimeInterval,
        totalAttempts: Int,
        correctCount: Int,
        characterStats: [Character: CharacterStat],
        date: Date = Date()
    ) {
        self.id = id
        self.sessionType = sessionType
        self.duration = duration
        self.totalAttempts = totalAttempts
        self.correctCount = correctCount
        self.characterStats = characterStats
        self.date = date
    }

    /// Accuracy as a decimal (0.0 to 1.0)
    var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctCount) / Double(totalAttempts)
    }

    /// Accuracy as a whole percentage (0 to 100)
    var accuracyPercentage: Int {
        Int((accuracy * 100).rounded())
    }

    /// Formatted duration string (e.g., "5:00")
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Codable support for Character keys

extension SessionResult {
    enum CodingKeys: String, CodingKey {
        case id, sessionType, duration, totalAttempts, correctCount, characterStats, date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionType = try container.decode(SessionType.self, forKey: .sessionType)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        totalAttempts = try container.decode(Int.self, forKey: .totalAttempts)
        correctCount = try container.decode(Int.self, forKey: .correctCount)
        date = try container.decode(Date.self, forKey: .date)

        let stringKeyedStats = try container.decode([String: CharacterStat].self, forKey: .characterStats)
        var charStats: [Character: CharacterStat] = [:]
        for (key, value) in stringKeyedStats {
            if let char = key.first {
                charStats[char] = value
            }
        }
        characterStats = charStats
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionType, forKey: .sessionType)
        try container.encode(duration, forKey: .duration)
        try container.encode(totalAttempts, forKey: .totalAttempts)
        try container.encode(correctCount, forKey: .correctCount)
        try container.encode(date, forKey: .date)

        var stringKeyedStats: [String: CharacterStat] = [:]
        for (char, stat) in characterStats {
            stringKeyedStats[String(char)] = stat
        }
        try container.encode(stringKeyedStats, forKey: .characterStats)
    }
}
