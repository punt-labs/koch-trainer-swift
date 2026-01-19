import Foundation

/// Generates character groups for training sessions.
/// Supports pattern-based grouping for learning and accuracy-weighted selection for retention.
struct GroupGenerator {

    /// Pattern families group characters by similar Morse structure.
    /// This helps learners recognize rhythmic similarities.
    enum PatternFamily: CaseIterable {
        case singleElement    // E, T
        case doubleElement    // I, M, A, N
        case tripleElement    // S, O, U, R, W, G, D, K
        case quadElement      // H, V, F, L, P, J, B, X, C, Y, Q, Z

        var characters: [Character] {
            switch self {
            case .singleElement:
                return ["E", "T"]
            case .doubleElement:
                return ["I", "M", "A", "N"]
            case .tripleElement:
                return ["S", "O", "U", "R", "W", "G", "D", "K"]
            case .quadElement:
                return ["H", "V", "F", "L", "P", "J", "B", "X", "C", "Y", "Q", "Z"]
            }
        }

        static func family(for char: Character) -> PatternFamily? {
            for family in allCases where family.characters.contains(char) {
                return family
            }
            return nil
        }
    }

    // MARK: - Group Generation

    /// Generate a group for learning new characters.
    /// Prioritizes the newest character and groups it with pattern-similar characters.
    /// - Parameters:
    ///   - level: Current Koch level (determines available characters)
    ///   - groupLength: Number of characters in the group
    ///   - availableCharacters: Optional custom character set (overrides level-based selection)
    /// - Returns: A string of characters to practice
    static func generateLearningGroup(
        level: Int,
        groupLength: Int = 5,
        availableCharacters: [Character]? = nil
    ) -> String {
        let available = availableCharacters ?? MorseCode.characters(forLevel: level)
        guard !available.isEmpty, let newestChar = available.last else { return "" }

        // The newest character (most recently unlocked)
        let newestFamily = PatternFamily.family(for: newestChar)

        // Find pattern-similar characters from the available set
        let similarChars: [Character]
        if let family = newestFamily {
            similarChars = available.filter { family.characters.contains($0) }
        } else {
            similarChars = [newestChar]
        }

        var group = ""
        for i in 0..<groupLength {
            // Include newest character at least twice for emphasis
            if i == 0 || i == groupLength / 2 {
                group.append(newestChar)
            } else if !similarChars.isEmpty && Bool.random() {
                // 50% chance to pick from pattern-similar characters
                group.append(similarChars[Int.random(in: 0..<similarChars.count)])
            } else {
                // Otherwise pick from all available
                group.append(available[Int.random(in: 0..<available.count)])
            }
        }

        return group
    }

    /// Generate a group for retention practice.
    /// Weights selection toward characters with lower accuracy for the specified direction.
    /// - Parameters:
    ///   - level: Current Koch level
    ///   - characterStats: Per-character accuracy statistics
    ///   - sessionType: Training direction (receive or send)
    ///   - groupLength: Number of characters in the group
    ///   - availableCharacters: Optional custom character set (overrides level-based selection)
    /// - Returns: A string of characters weighted by inverse accuracy
    static func generateRetentionGroup(
        level: Int,
        characterStats: [Character: CharacterStat],
        sessionType: SessionType,
        groupLength: Int = 5,
        availableCharacters: [Character]? = nil
    ) -> String {
        let available = availableCharacters ?? MorseCode.characters(forLevel: level)
        guard !available.isEmpty else { return "" }

        // Calculate weights: lower accuracy = higher weight (direction-specific)
        let weights = calculateWeights(for: available, stats: characterStats, sessionType: sessionType)

        var group = ""
        for _ in 0..<groupLength {
            let selected = weightedRandomSelection(from: available, weights: weights)
            group.append(selected)
        }

        return group
    }

    /// Generate a mixed group combining both strategies.
    /// Good for general practice after initial learning phase.
    /// - Parameters:
    ///   - level: Current Koch level
    ///   - characterStats: Per-character accuracy statistics
    ///   - sessionType: Training direction (receive or send)
    ///   - groupLength: Number of characters in the group
    ///   - availableCharacters: Optional custom character set (overrides level-based selection)
    /// - Returns: A balanced practice group
    static func generateMixedGroup(
        level: Int,
        characterStats: [Character: CharacterStat],
        sessionType: SessionType,
        groupLength: Int = 5,
        availableCharacters: [Character]? = nil
    ) -> String {
        let available = availableCharacters ?? MorseCode.characters(forLevel: level)
        guard !available.isEmpty else { return "" }

        // Check if we have direction-specific stats (uses base type for custom/vocabulary)
        let hasDirectionStats = available.contains { char in
            guard let stat = characterStats[char] else { return false }
            switch sessionType.baseType {
            case .receive: return stat.receiveAttempts > 0
            case .send: return stat.sendAttempts > 0
            default: return stat.totalAttempts > 0
            }
        }

        if hasDirectionStats {
            return generateRetentionGroup(
                level: level,
                characterStats: characterStats,
                sessionType: sessionType,
                groupLength: groupLength,
                availableCharacters: availableCharacters
            )
        } else {
            return generateLearningGroup(level: level, groupLength: groupLength, availableCharacters: availableCharacters)
        }
    }

    // MARK: - Weight Calculation

    /// Calculate selection weights based on inverse accuracy for a specific direction.
    /// Characters with lower accuracy get higher weights.
    private static func calculateWeights(
        for characters: [Character],
        stats: [Character: CharacterStat],
        sessionType: SessionType
    ) -> [Double] {
        // Minimum weight ensures even mastered characters appear occasionally
        let minWeight = 0.1
        // Maximum weight caps how much we emphasize weak characters
        let maxWeight = 1.0
        // Default weight for unpracticed characters (treat as needing practice)
        let defaultWeight = 0.7
        // Minimum attempts required before weighting by accuracy
        let minAttempts = 3

        return characters.map { char in
            guard let stat = stats[char] else {
                return defaultWeight
            }

            // Get direction-specific attempts and accuracy (uses base type)
            let attempts: Int
            let accuracy: Double
            switch sessionType.baseType {
            case .receive:
                attempts = stat.receiveAttempts
                accuracy = stat.receiveAccuracy
            case .send:
                attempts = stat.sendAttempts
                accuracy = stat.sendAccuracy
            default:
                attempts = stat.totalAttempts
                accuracy = stat.combinedAccuracy
            }

            guard attempts >= minAttempts else {
                // Not enough data for this direction; use default weight
                return defaultWeight
            }

            // Inverse accuracy: 90% accuracy → 0.1 weight, 50% accuracy → 0.5 weight
            let inverseAccuracy = 1.0 - accuracy

            // Clamp to range
            return max(minWeight, min(maxWeight, inverseAccuracy + minWeight))
        }
    }

    /// Select a random element using weighted probability.
    private static func weightedRandomSelection(
        from characters: [Character],
        weights: [Double]
    ) -> Character {
        let totalWeight = weights.reduce(0, +)
        var random = Double.random(in: 0..<totalWeight)

        for (index, weight) in weights.enumerated() {
            random -= weight
            if random <= 0 {
                return characters[index]
            }
        }

        // Fallback (shouldn't reach here, but safely return first character)
        return characters.first ?? "K"
    }
}
