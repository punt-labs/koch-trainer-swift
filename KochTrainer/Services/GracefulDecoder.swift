import Foundation
import OSLog

// MARK: - GracefulDecoder

/// Decodes StudentProgress with graceful degradation.
///
/// Preserves critical data (levels, start date) even when nested models fail to decode.
/// Attempts to decode sessionHistory items individually, keeping valid ones.
enum GracefulDecoder {

    // MARK: Internal

    /// Decode StudentProgress from JSON data with graceful degradation.
    ///
    /// Strategy:
    /// 1. Try standard full decode
    /// 2. On failure, extract core fields and decode arrays individually
    /// 3. Returns partial progress or nil if completely unrecoverable
    static func decode(from data: Data) -> StudentProgress? {
        // First, try standard decode
        do {
            return try JSONDecoder().decode(StudentProgress.self, from: data)
        } catch {
            logger.warning("Standard decode failed: \(error.localizedDescription)")
        }

        // Fall back to graceful degradation
        return decodeGracefully(from: data)
    }

    // MARK: Private

    private static let logger = Logger(subsystem: "com.kochtrainer", category: "GracefulDecoder")

    /// Attempt graceful decode by extracting fields individually.
    private static func decodeGracefully(from data: Data) -> StudentProgress? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("Failed to parse JSON as dictionary")
            return nil
        }

        // Extract core fields with defaults
        let schemaVersion = json["schemaVersion"] as? Int ?? StudentProgress.currentSchemaVersion
        let receiveLevel = json["receiveLevel"] as? Int ?? 1
        let sendLevel = json["sendLevel"] as? Int ?? 1

        // Handle legacy currentLevel migration
        let finalReceiveLevel: Int
        let finalSendLevel: Int
        if let currentLevel = json["currentLevel"] as? Int {
            finalReceiveLevel = json["receiveLevel"] as? Int ?? currentLevel
            finalSendLevel = json["sendLevel"] as? Int ?? currentLevel
        } else {
            finalReceiveLevel = receiveLevel
            finalSendLevel = sendLevel
        }

        // Extract startDate
        let startDate: Date
        if let startDateValue = json["startDate"] as? Double {
            startDate = Date(timeIntervalSinceReferenceDate: startDateValue)
        } else if let startDateString = json["startDate"] as? String,
                  let parsed = ISO8601DateFormatter().date(from: startDateString) {
            startDate = parsed
        } else {
            startDate = Date()
            logger.notice("Could not decode startDate, using current date")
        }

        // Decode sessionHistory individually
        let sessionHistory = decodeSessionsIndividually(from: json)

        // Decode characterStats individually
        let characterStats = decodeCharacterStatsIndividually(from: json)

        // Decode schedule with fallback
        let schedule = decodeSchedule(from: json)

        // Decode wordStats with fallback
        let wordStats = decodeWordStats(from: json)

        // Decode customVocabularySets with fallback
        let customVocabularySets = decodeVocabularySets(from: json)

        let sessionCount = sessionHistory.count
        let statsCount = characterStats.count
        logger.notice(
            "Graceful decode recovered: levels=\(finalReceiveLevel)/\(finalSendLevel), sessions=\(sessionCount), stats=\(statsCount)"
        )

        return StudentProgress(
            schemaVersion: schemaVersion,
            receiveLevel: finalReceiveLevel,
            sendLevel: finalSendLevel,
            characterStats: characterStats,
            sessionHistory: sessionHistory,
            startDate: startDate,
            schedule: schedule,
            wordStats: wordStats,
            customVocabularySets: customVocabularySets
        )
    }

    /// Decode each session individually, keeping valid ones.
    private static func decodeSessionsIndividually(from json: [String: Any]) -> [SessionResult] {
        guard let sessionsArray = json["sessionHistory"] as? [[String: Any]] else {
            return []
        }

        var validSessions: [SessionResult] = []
        let decoder = JSONDecoder()

        for (index, sessionDict) in sessionsArray.enumerated() {
            do {
                let sessionData = try JSONSerialization.data(withJSONObject: sessionDict)
                let session = try decoder.decode(SessionResult.self, from: sessionData)
                validSessions.append(session)
            } catch {
                logger.warning("Session \(index) decode failed, skipping: \(error.localizedDescription)")
            }
        }

        return validSessions
    }

    /// Decode character stats individually, keeping valid ones.
    private static func decodeCharacterStatsIndividually(from json: [String: Any]) -> [Character: CharacterStat] {
        guard let statsDict = json["characterStats"] as? [String: [String: Any]] else {
            return [:]
        }

        var validStats: [Character: CharacterStat] = [:]
        let decoder = JSONDecoder()

        for (charKey, statDict) in statsDict {
            guard let char = charKey.first else { continue }

            do {
                let statData = try JSONSerialization.data(withJSONObject: statDict)
                let stat = try decoder.decode(CharacterStat.self, from: statData)
                validStats[char] = stat
            } catch {
                logger.warning("CharacterStat '\(charKey)' decode failed, skipping")
            }
        }

        return validStats
    }

    /// Decode schedule with fallback to default.
    private static func decodeSchedule(from json: [String: Any]) -> PracticeSchedule {
        guard let scheduleDict = json["schedule"] as? [String: Any] else {
            return PracticeSchedule()
        }

        do {
            let scheduleData = try JSONSerialization.data(withJSONObject: scheduleDict)
            return try JSONDecoder().decode(PracticeSchedule.self, from: scheduleData)
        } catch {
            logger.warning("Schedule decode failed, using default: \(error.localizedDescription)")
            return PracticeSchedule()
        }
    }

    /// Decode word stats with fallback to empty.
    private static func decodeWordStats(from json: [String: Any]) -> [String: WordStat] {
        guard let statsDict = json["wordStats"] as? [String: [String: Any]] else {
            return [:]
        }

        var validStats: [String: WordStat] = [:]
        let decoder = JSONDecoder()

        for (word, statDict) in statsDict {
            do {
                let statData = try JSONSerialization.data(withJSONObject: statDict)
                let stat = try decoder.decode(WordStat.self, from: statData)
                validStats[word] = stat
            } catch {
                logger.warning("WordStat '\(word)' decode failed, skipping")
            }
        }

        return validStats
    }

    /// Decode vocabulary sets with fallback to empty.
    private static func decodeVocabularySets(from json: [String: Any]) -> [VocabularySet] {
        guard let setsArray = json["customVocabularySets"] as? [[String: Any]] else {
            return []
        }

        var validSets: [VocabularySet] = []
        let decoder = JSONDecoder()

        for (index, setDict) in setsArray.enumerated() {
            do {
                let setData = try JSONSerialization.data(withJSONObject: setDict)
                let vocabSet = try decoder.decode(VocabularySet.self, from: setData)
                validSets.append(vocabSet)
            } catch {
                logger.warning("VocabularySet \(index) decode failed, skipping")
            }
        }

        return validSets
    }
}
