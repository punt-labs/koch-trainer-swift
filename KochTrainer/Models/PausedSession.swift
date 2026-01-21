import Foundation

// MARK: - PausedSession

/// Captures the state of a paused training session for later resumption.
/// Supports both character-based sessions (receive/send/custom) and vocabulary sessions.
struct PausedSession: Codable, Equatable {

    // MARK: Lifecycle

    /// Initialize for character-based training sessions
    init(
        id: UUID = UUID(),
        sessionType: SessionType,
        startTime: Date,
        pausedAt: Date,
        correctCount: Int,
        totalAttempts: Int,
        characterStats: [Character: CharacterStat],
        introCharacters: [Character],
        introCompleted: Bool,
        customCharacters: [Character]?,
        currentLevel: Int
    ) {
        self.id = id
        self.sessionType = sessionType
        self.startTime = startTime
        self.pausedAt = pausedAt
        self.correctCount = correctCount
        self.totalAttempts = totalAttempts
        self.characterStats = characterStats
        self.introCharacters = introCharacters
        self.introCompleted = introCompleted
        self.customCharacters = customCharacters
        self.currentLevel = currentLevel
        vocabularySetId = nil
        wordStats = nil
    }

    /// Initialize for vocabulary training sessions
    init(
        id: UUID = UUID(),
        sessionType: SessionType,
        startTime: Date,
        pausedAt: Date,
        correctCount: Int,
        totalAttempts: Int,
        vocabularySetId: UUID,
        wordStats: [String: WordStat]
    ) {
        self.id = id
        self.sessionType = sessionType
        self.startTime = startTime
        self.pausedAt = pausedAt
        self.correctCount = correctCount
        self.totalAttempts = totalAttempts
        characterStats = [:]
        introCharacters = []
        introCompleted = true
        customCharacters = nil
        currentLevel = 0
        self.vocabularySetId = vocabularySetId
        self.wordStats = wordStats
    }

    // MARK: Internal

    let id: UUID
    let sessionType: SessionType
    let startTime: Date
    let pausedAt: Date
    let correctCount: Int
    let totalAttempts: Int

    // Character-based session fields
    let characterStats: [Character: CharacterStat]
    let introCharacters: [Character]
    let introCompleted: Bool
    let customCharacters: [Character]?
    let currentLevel: Int

    // Vocabulary session fields
    let vocabularySetId: UUID?
    let wordStats: [String: WordStat]?

    /// Duration spent in training before pause
    var elapsedDuration: TimeInterval {
        pausedAt.timeIntervalSince(startTime)
    }

    /// Whether the session is expired (paused > 24 hours ago)
    var isExpired: Bool {
        Date().timeIntervalSince(pausedAt) > 24 * 60 * 60
    }

    /// Whether this is a custom practice session
    var isCustomSession: Bool {
        customCharacters != nil
    }

    /// Whether this is a vocabulary session
    var isVocabularySession: Bool {
        vocabularySetId != nil
    }
}

// MARK: - Codable support for Character keys and arrays

extension PausedSession {
    enum CodingKeys: String, CodingKey {
        case id
        case sessionType
        case startTime
        case pausedAt
        case correctCount
        case totalAttempts
        case characterStats
        case introCharacters
        case introCompleted
        case customCharacters
        case currentLevel
        case vocabularySetId
        case wordStats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionType = try container.decode(SessionType.self, forKey: .sessionType)
        startTime = try container.decode(Date.self, forKey: .startTime)
        pausedAt = try container.decode(Date.self, forKey: .pausedAt)
        correctCount = try container.decode(Int.self, forKey: .correctCount)
        totalAttempts = try container.decode(Int.self, forKey: .totalAttempts)
        introCompleted = try container.decode(Bool.self, forKey: .introCompleted)
        currentLevel = try container.decode(Int.self, forKey: .currentLevel)

        // Decode characterStats with String keys
        let stringKeyedStats = try container.decode([String: CharacterStat].self, forKey: .characterStats)
        var charStats: [Character: CharacterStat] = [:]
        for (key, value) in stringKeyedStats {
            if let char = key.first {
                charStats[char] = value
            }
        }
        characterStats = charStats

        // Decode introCharacters from String array
        let introStrings = try container.decode([String].self, forKey: .introCharacters)
        introCharacters = introStrings.compactMap(\.first)

        // Decode optional customCharacters from String array
        if let customStrings = try container.decodeIfPresent([String].self, forKey: .customCharacters) {
            customCharacters = customStrings.compactMap(\.first)
        } else {
            customCharacters = nil
        }

        // Decode optional vocabulary fields
        vocabularySetId = try container.decodeIfPresent(UUID.self, forKey: .vocabularySetId)
        wordStats = try container.decodeIfPresent([String: WordStat].self, forKey: .wordStats)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionType, forKey: .sessionType)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(pausedAt, forKey: .pausedAt)
        try container.encode(correctCount, forKey: .correctCount)
        try container.encode(totalAttempts, forKey: .totalAttempts)
        try container.encode(introCompleted, forKey: .introCompleted)
        try container.encode(currentLevel, forKey: .currentLevel)

        // Encode characterStats with String keys
        var stringKeyedStats: [String: CharacterStat] = [:]
        for (char, stat) in characterStats {
            stringKeyedStats[String(char)] = stat
        }
        try container.encode(stringKeyedStats, forKey: .characterStats)

        // Encode introCharacters as String array
        let introStrings = introCharacters.map { String($0) }
        try container.encode(introStrings, forKey: .introCharacters)

        // Encode optional customCharacters as String array
        if let custom = customCharacters {
            let customStrings = custom.map { String($0) }
            try container.encode(customStrings, forKey: .customCharacters)
        }

        // Encode optional vocabulary fields
        try container.encodeIfPresent(vocabularySetId, forKey: .vocabularySetId)
        try container.encodeIfPresent(wordStats, forKey: .wordStats)
    }
}
