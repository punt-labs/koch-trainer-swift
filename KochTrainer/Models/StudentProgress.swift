import Foundation

// MARK: - StudentProgress

/// Tracks a student's overall progress in the Koch method training.
struct StudentProgress: Codable, Equatable {

    // MARK: Lifecycle

    init(
        schemaVersion: Int = currentSchemaVersion,
        receiveLevel: Int = 1,
        sendLevel: Int = 1,
        earTrainingLevel: Int = 1,
        characterStats: [Character: CharacterStat] = [:],
        sessionHistory: [SessionResult] = [],
        startDate: Date = Date(),
        schedule: PracticeSchedule = PracticeSchedule(),
        wordStats: [String: WordStat] = [:],
        customVocabularySets: [VocabularySet] = []
    ) {
        self.schemaVersion = schemaVersion
        self.receiveLevel = max(1, min(receiveLevel, 26))
        self.sendLevel = max(1, min(sendLevel, 26))
        self.earTrainingLevel = max(1, min(earTrainingLevel, 5))
        self.characterStats = characterStats
        self.sessionHistory = sessionHistory
        self.startDate = startDate
        self.schedule = schedule
        self.wordStats = wordStats
        self.customVocabularySets = customVocabularySets
    }

    // MARK: Internal

    /// Current schema version for data migration support.
    /// Increment when making breaking changes to the data structure.
    static let currentSchemaVersion = 1

    /// Schema version for migration support. Defaults to currentSchemaVersion for new instances.
    var schemaVersion: Int

    /// Level for receive training (1-26). Each level unlocks one additional character.
    var receiveLevel: Int

    /// Level for send training (1-26). Each level unlocks one additional character.
    var sendLevel: Int

    /// Level for ear training (1-5). Each level adds longer pattern characters.
    /// Level 1 = 1-element patterns (E, T)
    /// Level 5 = all patterns up to 5 elements
    var earTrainingLevel: Int

    /// Per-character performance statistics
    var characterStats: [Character: CharacterStat]

    /// History of completed sessions
    var sessionHistory: [SessionResult]

    /// Date when training started
    var startDate: Date

    /// Spaced repetition and streak tracking
    var schedule: PracticeSchedule

    /// Per-word performance statistics for vocabulary training
    var wordStats: [String: WordStat]

    /// User-created vocabulary sets
    var customVocabularySets: [VocabularySet]

    // Legacy computed properties for backward compatibility
    var currentLevel: Int { max(receiveLevel, sendLevel) }
    var unlockedCharacters: [Character] { MorseCode.characters(forLevel: currentLevel) }

    /// Overall accuracy across all attempts (both directions combined)
    var overallAccuracy: Double {
        let totalAttempts = characterStats.values.reduce(0) { $0 + $1.totalAttempts }
        let totalCorrect = characterStats.values.reduce(0) { $0 + $1.totalCorrect }
        guard totalAttempts > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAttempts)
    }

    /// Determines if the student should advance to the next level for a session type.
    /// Requires ≥90% accuracy in a completed session.
    static func shouldAdvance(sessionAccuracy: Double, level: Int) -> Bool {
        sessionAccuracy >= 0.90 && level < 26
    }

    /// Get level for a specific session type
    func level(for sessionType: BaseSessionType) -> Int {
        switch sessionType {
        case .receive: return receiveLevel
        case .send: return sendLevel
        }
    }

    /// Characters unlocked for a specific session type
    func unlockedCharacters(for sessionType: BaseSessionType) -> [Character] {
        MorseCode.characters(forLevel: level(for: sessionType))
    }

    /// Next character to unlock for a specific session type, or nil if all unlocked
    func nextCharacter(for sessionType: BaseSessionType) -> Character? {
        let lvl = level(for: sessionType)
        guard lvl < 26 else { return nil }
        return MorseCode.kochOrder[lvl]
    }

    /// Overall accuracy for a specific session type
    func overallAccuracy(for sessionType: BaseSessionType) -> Double {
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

    /// Advance to next level for a session type if conditions are met
    mutating func advanceIfEligible(sessionAccuracy: Double, sessionType: BaseSessionType) -> Bool {
        let currentLvl = level(for: sessionType)
        guard Self.shouldAdvance(sessionAccuracy: sessionAccuracy, level: currentLvl) else {
            return false
        }
        switch sessionType {
        case .receive:
            receiveLevel += 1
        case .send:
            sendLevel += 1
        }
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

// MARK: - CharacterStat

/// Performance statistics for a single character, tracked separately by direction.
struct CharacterStat: Codable, Equatable {

    // MARK: Lifecycle

    init(
        receiveAttempts: Int = 0,
        receiveCorrect: Int = 0,
        sendAttempts: Int = 0,
        sendCorrect: Int = 0,
        earTrainingAttempts: Int = 0,
        earTrainingCorrect: Int = 0,
        lastPracticed: Date = Date()
    ) {
        self.receiveAttempts = receiveAttempts
        self.receiveCorrect = receiveCorrect
        self.sendAttempts = sendAttempts
        self.sendCorrect = sendCorrect
        self.earTrainingAttempts = earTrainingAttempts
        self.earTrainingCorrect = earTrainingCorrect
        self.lastPracticed = lastPracticed
    }

    /// Convenience initializer for single-direction stats (used during sessions)
    init(sessionType: BaseSessionType, attempts: Int, correct: Int, lastPracticed: Date = Date()) {
        switch sessionType {
        case .receive:
            receiveAttempts = attempts
            receiveCorrect = correct
            sendAttempts = 0
            sendCorrect = 0
        case .send:
            receiveAttempts = 0
            receiveCorrect = 0
            sendAttempts = attempts
            sendCorrect = correct
        }
        earTrainingAttempts = 0
        earTrainingCorrect = 0
        self.lastPracticed = lastPracticed
    }

    /// Convenience initializer for ear training stats
    init(earTrainingAttempts: Int, earTrainingCorrect: Int, lastPracticed: Date = Date()) {
        receiveAttempts = 0
        receiveCorrect = 0
        sendAttempts = 0
        sendCorrect = 0
        self.earTrainingAttempts = earTrainingAttempts
        self.earTrainingCorrect = earTrainingCorrect
        self.lastPracticed = lastPracticed
    }

    // MARK: Internal

    /// Receive training stats (audio → text)
    var receiveAttempts: Int
    var receiveCorrect: Int

    /// Send training stats (text → keying)
    var sendAttempts: Int
    var sendCorrect: Int

    /// Ear training stats (audio → pattern reproduction)
    var earTrainingAttempts: Int
    var earTrainingCorrect: Int

    var lastPracticed: Date

    var totalAttempts: Int { receiveAttempts + sendAttempts + earTrainingAttempts }
    var totalCorrect: Int { receiveCorrect + sendCorrect + earTrainingCorrect }

    var receiveAccuracy: Double {
        guard receiveAttempts > 0 else { return 0 }
        return Double(receiveCorrect) / Double(receiveAttempts)
    }

    var sendAccuracy: Double {
        guard sendAttempts > 0 else { return 0 }
        return Double(sendCorrect) / Double(sendAttempts)
    }

    var earTrainingAccuracy: Double {
        guard earTrainingAttempts > 0 else { return 0 }
        return Double(earTrainingCorrect) / Double(earTrainingAttempts)
    }

    /// Koch method accuracy (receive + send only, excludes ear training)
    /// Used for proficiency indicators on the Practice screen.
    var kochAccuracy: Double {
        let kochAttempts = receiveAttempts + sendAttempts
        let kochCorrect = receiveCorrect + sendCorrect
        guard kochAttempts > 0 else { return 0 }
        return Double(kochCorrect) / Double(kochAttempts)
    }

    /// Get accuracy for a specific session type
    func accuracy(for sessionType: BaseSessionType) -> Double {
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
        earTrainingAttempts += other.earTrainingAttempts
        earTrainingCorrect += other.earTrainingCorrect
        if other.lastPracticed > lastPracticed {
            lastPracticed = other.lastPracticed
        }
    }
}

// MARK: - CharacterStat Codable

extension CharacterStat {
    enum CodingKeys: String, CodingKey {
        case receiveAttempts
        case receiveCorrect
        case sendAttempts
        case sendCorrect
        case earTrainingAttempts
        case earTrainingCorrect
        case lastPracticed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        receiveAttempts = try container.decode(Int.self, forKey: .receiveAttempts)
        receiveCorrect = try container.decode(Int.self, forKey: .receiveCorrect)
        sendAttempts = try container.decode(Int.self, forKey: .sendAttempts)
        sendCorrect = try container.decode(Int.self, forKey: .sendCorrect)
        // Ear training fields default to 0 for legacy data
        earTrainingAttempts = try container.decodeIfPresent(Int.self, forKey: .earTrainingAttempts) ?? 0
        earTrainingCorrect = try container.decodeIfPresent(Int.self, forKey: .earTrainingCorrect) ?? 0
        lastPracticed = try container.decode(Date.self, forKey: .lastPracticed)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(receiveAttempts, forKey: .receiveAttempts)
        try container.encode(receiveCorrect, forKey: .receiveCorrect)
        try container.encode(sendAttempts, forKey: .sendAttempts)
        try container.encode(sendCorrect, forKey: .sendCorrect)
        try container.encode(earTrainingAttempts, forKey: .earTrainingAttempts)
        try container.encode(earTrainingCorrect, forKey: .earTrainingCorrect)
        try container.encode(lastPracticed, forKey: .lastPracticed)
    }
}

// MARK: - Codable support for Character keys

extension StudentProgress {
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case receiveLevel
        case sendLevel
        case earTrainingLevel
        case currentLevel
        case characterStats
        case sessionHistory
        case startDate
        case schedule
        case wordStats
        case customVocabularySets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Schema version (default to 1 for old data without version field)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.currentSchemaVersion

        // Support migration from old single-level format
        if let oldLevel = try container.decodeIfPresent(Int.self, forKey: .currentLevel) {
            // Migrate: use old level for both directions
            receiveLevel = try container.decodeIfPresent(Int.self, forKey: .receiveLevel) ?? oldLevel
            sendLevel = try container.decodeIfPresent(Int.self, forKey: .sendLevel) ?? oldLevel
        } else {
            receiveLevel = try container.decode(Int.self, forKey: .receiveLevel)
            sendLevel = try container.decode(Int.self, forKey: .sendLevel)
        }

        // Ear training level with default for old data
        earTrainingLevel = try container.decodeIfPresent(Int.self, forKey: .earTrainingLevel) ?? 1

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

        // Migration: calculate schedule from session history if not present
        if let existingSchedule = try container.decodeIfPresent(PracticeSchedule.self, forKey: .schedule) {
            schedule = existingSchedule
        } else {
            schedule = Self.calculateInitialSchedule(from: sessionHistory, startDate: startDate)
        }

        // Migration: provide defaults for vocabulary fields if not present
        wordStats = try container.decodeIfPresent([String: WordStat].self, forKey: .wordStats) ?? [:]
        customVocabularySets = try container.decodeIfPresent([VocabularySet].self, forKey: .customVocabularySets) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(receiveLevel, forKey: .receiveLevel)
        try container.encode(sendLevel, forKey: .sendLevel)
        try container.encode(earTrainingLevel, forKey: .earTrainingLevel)
        try container.encode(sessionHistory, forKey: .sessionHistory)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(wordStats, forKey: .wordStats)
        try container.encode(customVocabularySets, forKey: .customVocabularySets)

        // Encode character stats with String keys
        var stringKeyedStats: [String: CharacterStat] = [:]
        for (char, stat) in characterStats {
            stringKeyedStats[String(char)] = stat
        }
        try container.encode(stringKeyedStats, forKey: .characterStats)
    }

    /// Result of calculating streak from session history
    private struct StreakHistoryResult {
        let currentStreak: Int
        let longestStreak: Int
        let lastDate: Date?
    }

    /// Calculate initial schedule from existing session history (for migration)
    static func calculateInitialSchedule(from sessionHistory: [SessionResult], startDate: Date) -> PracticeSchedule {
        guard !sessionHistory.isEmpty else {
            return PracticeSchedule()
        }

        // Sort sessions by date
        let sortedSessions = sessionHistory.sorted { $0.date < $1.date }

        // Calculate streak by walking backwards from most recent session
        let streakResult = calculateStreakFromHistory(sortedSessions)

        return PracticeSchedule(
            receiveInterval: 1.0,
            sendInterval: 1.0,
            receiveNextDate: nil,
            sendNextDate: nil,
            currentStreak: streakResult.currentStreak,
            longestStreak: streakResult.longestStreak,
            lastStreakDate: streakResult.lastDate
        )
    }

    /// Calculate streak from session history by checking consecutive days
    private static func calculateStreakFromHistory(_ sortedSessions: [SessionResult]) -> StreakHistoryResult {
        guard let lastSession = sortedSessions.last else {
            return StreakHistoryResult(currentStreak: 0, longestStreak: 0, lastDate: nil)
        }

        let calendar = Calendar.current
        var currentStreak = 0
        var longestStreak = 0
        var streakDays: Set<Int> = [] // Days since start date

        // Group sessions by calendar day
        for session in sortedSessions {
            let dayStart = calendar.startOfDay(for: session.date)
            let daysSinceEpoch = Int(dayStart.timeIntervalSince1970 / 86400)
            streakDays.insert(daysSinceEpoch)
        }

        // Sort unique days
        let sortedDays = streakDays.sorted()

        // Calculate longest streak
        var tempStreak = 1
        for i in 1 ..< sortedDays.count {
            if sortedDays[i] == sortedDays[i - 1] + 1 {
                tempStreak += 1
            } else {
                longestStreak = max(longestStreak, tempStreak)
                tempStreak = 1
            }
        }
        longestStreak = max(longestStreak, tempStreak)

        // Calculate current streak (from most recent day backwards)
        let todayStart = calendar.startOfDay(for: Date())
        let todayDayNum = Int(todayStart.timeIntervalSince1970 / 86400)

        // Check if most recent session was today or yesterday
        guard let lastDayNum = sortedDays.last else {
            return StreakHistoryResult(currentStreak: 0, longestStreak: longestStreak, lastDate: nil)
        }

        if lastDayNum < todayDayNum - 1 {
            // Last session was more than yesterday, streak broken
            return StreakHistoryResult(currentStreak: 0, longestStreak: longestStreak, lastDate: lastSession.date)
        }

        // Count backwards from most recent day
        var checkDay = lastDayNum
        currentStreak = 0
        while streakDays.contains(checkDay) {
            currentStreak += 1
            checkDay -= 1
        }

        return StreakHistoryResult(
            currentStreak: currentStreak,
            longestStreak: max(longestStreak, currentStreak),
            lastDate: lastSession.date
        )
    }
}
