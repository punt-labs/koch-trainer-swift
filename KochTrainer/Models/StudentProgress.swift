import Foundation

/// Tracks a student's overall progress in the Koch method training.
struct StudentProgress: Codable, Equatable {
    /// Level for receive training (1-26). Each level unlocks one additional character.
    var receiveLevel: Int

    /// Level for send training (1-26). Each level unlocks one additional character.
    var sendLevel: Int

    /// Per-character performance statistics
    var characterStats: [Character: CharacterStat]

    /// History of completed sessions
    var sessionHistory: [SessionResult]

    /// Date when training started
    var startDate: Date

    /// Spaced repetition and streak tracking
    var schedule: PracticeSchedule

    init(
        receiveLevel: Int = 1,
        sendLevel: Int = 1,
        characterStats: [Character: CharacterStat] = [:],
        sessionHistory: [SessionResult] = [],
        startDate: Date = Date(),
        schedule: PracticeSchedule = PracticeSchedule()
    ) {
        self.receiveLevel = max(1, min(receiveLevel, 26))
        self.sendLevel = max(1, min(sendLevel, 26))
        self.characterStats = characterStats
        self.sessionHistory = sessionHistory
        self.startDate = startDate
        self.schedule = schedule
    }

    /// Get level for a specific session type
    func level(for sessionType: SessionType) -> Int {
        switch sessionType {
        case .receive: return receiveLevel
        case .send: return sendLevel
        }
    }

    /// Characters unlocked for a specific session type
    func unlockedCharacters(for sessionType: SessionType) -> [Character] {
        MorseCode.characters(forLevel: level(for: sessionType))
    }

    /// Next character to unlock for a specific session type, or nil if all unlocked
    func nextCharacter(for sessionType: SessionType) -> Character? {
        let lvl = level(for: sessionType)
        guard lvl < 26 else { return nil }
        return MorseCode.kochOrder[lvl]
    }

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

    /// Determines if the student should advance to the next level for a session type.
    /// Requires ≥90% accuracy in a completed session.
    static func shouldAdvance(sessionAccuracy: Double, level: Int) -> Bool {
        sessionAccuracy >= 0.90 && level < 26
    }

    /// Advance to next level for a session type if conditions are met
    mutating func advanceIfEligible(sessionAccuracy: Double, sessionType: SessionType) -> Bool {
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
        case receiveLevel, sendLevel, currentLevel, characterStats, sessionHistory, startDate, schedule
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Support migration from old single-level format
        if let oldLevel = try container.decodeIfPresent(Int.self, forKey: .currentLevel) {
            // Migrate: use old level for both directions
            receiveLevel = try container.decodeIfPresent(Int.self, forKey: .receiveLevel) ?? oldLevel
            sendLevel = try container.decodeIfPresent(Int.self, forKey: .sendLevel) ?? oldLevel
        } else {
            receiveLevel = try container.decode(Int.self, forKey: .receiveLevel)
            sendLevel = try container.decode(Int.self, forKey: .sendLevel)
        }

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
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(receiveLevel, forKey: .receiveLevel)
        try container.encode(sendLevel, forKey: .sendLevel)
        try container.encode(sessionHistory, forKey: .sessionHistory)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(schedule, forKey: .schedule)

        // Encode character stats with String keys
        var stringKeyedStats: [String: CharacterStat] = [:]
        for (char, stat) in characterStats {
            stringKeyedStats[String(char)] = stat
        }
        try container.encode(stringKeyedStats, forKey: .characterStats)
    }

    /// Calculate initial schedule from existing session history (for migration)
    static func calculateInitialSchedule(from sessionHistory: [SessionResult], startDate: Date) -> PracticeSchedule {
        guard !sessionHistory.isEmpty else {
            return PracticeSchedule()
        }

        // Sort sessions by date
        let sortedSessions = sessionHistory.sorted { $0.date < $1.date }

        // Calculate streak by walking backwards from most recent session
        let (currentStreak, longestStreak, lastStreakDate) = calculateStreakFromHistory(sortedSessions)

        return PracticeSchedule(
            receiveInterval: 1.0,
            sendInterval: 1.0,
            receiveNextDate: nil,
            sendNextDate: nil,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastStreakDate: lastStreakDate
        )
    }

    /// Calculate streak from session history by checking consecutive days
    private static func calculateStreakFromHistory(_ sortedSessions: [SessionResult]) -> (current: Int, longest: Int, lastDate: Date?) {
        guard let lastSession = sortedSessions.last else {
            return (0, 0, nil)
        }

        let calendar = Calendar.current
        var currentStreak = 0
        var longestStreak = 0
        var streakDays: Set<Int> = []  // Days since start date

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
        for i in 1..<sortedDays.count {
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
            return (0, longestStreak, nil)
        }

        if lastDayNum < todayDayNum - 1 {
            // Last session was more than yesterday, streak broken
            return (0, longestStreak, lastSession.date)
        }

        // Count backwards from most recent day
        var checkDay = lastDayNum
        currentStreak = 0
        while streakDays.contains(checkDay) {
            currentStreak += 1
            checkDay -= 1
        }

        return (currentStreak, max(longestStreak, currentStreak), lastSession.date)
    }
}
