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

    /// Overall accuracy across all attempts (both directions combined)
    var overallAccuracy: Double {
        let totalAttempts = characterStats.values.reduce(0) { $0 + $1.totalAttempts }
        let totalCorrect = characterStats.values.reduce(0) { $0 + $1.totalCorrect }
        guard totalAttempts > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAttempts)
    }

    /// Overall accuracy for a specific session type
    func overallAccuracy(for sessionType: SessionType) -> Double {
        let stats = characterStats.values
        switch sessionType {
        case .receive:
            let attempts = stats.reduce(0) { $0 + $1.receiveAttempts }
            let correct = stats.reduce(0) { $0 + $1.receiveCorrect }
            guard attempts > 0 else { return 0 }
            return Double(correct) / Double(attempts)
        case .send:
            let attempts = stats.reduce(0) { $0 + $1.sendAttempts }
            let correct = stats.reduce(0) { $0 + $1.sendCorrect }
            guard attempts > 0 else { return 0 }
            return Double(correct) / Double(attempts)
        }
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
                existing.merge(stat)
                characterStats[char] = existing
            } else {
                characterStats[char] = stat
            }
        }
        sessionHistory.append(result)
    }
}

/// Performance statistics for a single character, tracked separately by direction.
struct CharacterStat: Codable, Equatable {
    /// Receive training stats (audio → text)
    var receiveAttempts: Int
    var receiveCorrect: Int

    /// Send training stats (text → keying)
    var sendAttempts: Int
    var sendCorrect: Int

    var lastPracticed: Date

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

    /// Convenience initializer for single-direction stats (used during sessions)
    init(sessionType: SessionType, attempts: Int, correct: Int, lastPracticed: Date = Date()) {
        switch sessionType {
        case .receive:
            self.receiveAttempts = attempts
            self.receiveCorrect = correct
            self.sendAttempts = 0
            self.sendCorrect = 0
        case .send:
            self.receiveAttempts = 0
            self.receiveCorrect = 0
            self.sendAttempts = attempts
            self.sendCorrect = correct
        }
        self.lastPracticed = lastPracticed
    }

    // MARK: - Computed Properties

    var totalAttempts: Int { receiveAttempts + sendAttempts }
    var totalCorrect: Int { receiveCorrect + sendCorrect }

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
    func accuracy(for sessionType: SessionType) -> Double {
        switch sessionType {
        case .receive: return receiveAccuracy
        case .send: return sendAccuracy
        }
    }

    /// Merge another stat into this one
    mutating func merge(_ other: CharacterStat) {
        receiveAttempts += other.receiveAttempts
        receiveCorrect += other.receiveCorrect
        sendAttempts += other.sendAttempts
        sendCorrect += other.sendCorrect
        if other.lastPracticed > lastPracticed {
            lastPracticed = other.lastPracticed
        }
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
