import Foundation

/// Tracks a student's overall progress in the Koch method training.
struct StudentProgress: Codable, Equatable {
    /// Current level (1-26). Each level unlocks one additional character.
    var currentLevel: Int

    /// Per-character performance statistics
    var characterStats: [Character: CharacterStat]

    /// History of completed sessions
    var sessionHistory: [SessionResult]

    /// Date when training started
    var startDate: Date

    init(
        currentLevel: Int = 1,
        characterStats: [Character: CharacterStat] = [:],
        sessionHistory: [SessionResult] = [],
        startDate: Date = Date()
    ) {
        self.currentLevel = max(1, min(currentLevel, 26))
        self.characterStats = characterStats
        self.sessionHistory = sessionHistory
        self.startDate = startDate
    }

    /// Characters currently unlocked based on level
    var unlockedCharacters: [Character] {
        MorseCode.characters(forLevel: currentLevel)
    }

    /// Next character to unlock, or nil if all unlocked
    var nextCharacter: Character? {
        guard currentLevel < 26 else { return nil }
        return MorseCode.kochOrder[currentLevel]
    }

    /// Overall accuracy across all attempts
    var overallAccuracy: Double {
        let totalAttempts = characterStats.values.reduce(0) { $0 + $1.totalAttempts }
        let totalCorrect = characterStats.values.reduce(0) { $0 + $1.correctCount }
        guard totalAttempts > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAttempts)
    }

    /// Determines if the student should advance to the next level.
    /// Requires ≥90% accuracy in a completed 5-minute session.
    static func shouldAdvance(sessionAccuracy: Double, currentLevel: Int) -> Bool {
        sessionAccuracy >= 0.90 && currentLevel < 26
    }

    /// Advance to next level if conditions are met
    mutating func advanceIfEligible(sessionAccuracy: Double) -> Bool {
        guard Self.shouldAdvance(sessionAccuracy: sessionAccuracy, currentLevel: currentLevel) else {
            return false
        }
        currentLevel += 1
        return true
    }

    /// Update character statistics from a session result
    mutating func updateStats(from result: SessionResult) {
        for (char, stat) in result.characterStats {
            if var existing = characterStats[char] {
                existing.totalAttempts += stat.totalAttempts
                existing.correctCount += stat.correctCount
                existing.lastPracticed = stat.lastPracticed
                characterStats[char] = existing
            } else {
                characterStats[char] = stat
            }
        }
        sessionHistory.append(result)
    }
}

/// Performance statistics for a single character.
struct CharacterStat: Codable, Equatable {
    var totalAttempts: Int
    var correctCount: Int
    var lastPracticed: Date

    init(totalAttempts: Int = 0, correctCount: Int = 0, lastPracticed: Date = Date()) {
        self.totalAttempts = totalAttempts
        self.correctCount = correctCount
        self.lastPracticed = lastPracticed
    }

    var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctCount) / Double(totalAttempts)
    }
}

// MARK: - Codable support for Character keys

extension StudentProgress {
    enum CodingKeys: String, CodingKey {
        case currentLevel, characterStats, sessionHistory, startDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentLevel = try container.decode(Int.self, forKey: .currentLevel)
        sessionHistory = try container.decode([SessionResult].self, forKey: .sessionHistory)
        startDate = try container.decode(Date.self, forKey: .startDate)

        // Decode character stats with String keys
        let stringKeyedStats = try container.decode([String: CharacterStat].self, forKey: .characterStats)
        characterStats = [:]
        for (key, value) in stringKeyedStats {
            if let char = key.first {
                characterStats[char] = value
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentLevel, forKey: .currentLevel)
        try container.encode(sessionHistory, forKey: .sessionHistory)
        try container.encode(startDate, forKey: .startDate)

        // Encode character stats with String keys
        var stringKeyedStats: [String: CharacterStat] = [:]
        for (char, stat) in characterStats {
            stringKeyedStats[String(char)] = stat
        }
        try container.encode(stringKeyedStats, forKey: .characterStats)
    }
}
