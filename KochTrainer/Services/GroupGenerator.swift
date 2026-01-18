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
            for family in allCases {
                if family.characters.contains(char) {
                    return family
                }
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
    /// - Returns: A string of characters to practice
    static func generateLearningGroup(level: Int, groupLength: Int = 5) -> String {
        let available = MorseCode.characters(forLevel: level)
        guard !available.isEmpty else { return "" }

        // The newest character (most recently unlocked)
        let newestChar = available.last!
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
                group.append(similarChars.randomElement()!)
            } else {
                // Otherwise pick from all available
                group.append(available.randomElement()!)
            }
        }

        return group
    }

    /// Generate a group for retention practice.
    /// Weights selection toward characters with lower accuracy.
    /// - Parameters:
    ///   - level: Current Koch level
    ///   - characterStats: Per-character accuracy statistics
    ///   - groupLength: Number of characters in the group
    /// - Returns: A string of characters weighted by inverse accuracy
    static func generateRetentionGroup(
        level: Int,
        characterStats: [Character: CharacterStat],
        groupLength: Int = 5
    ) -> String {
        let available = MorseCode.characters(forLevel: level)
        guard !available.isEmpty else { return "" }

        // Calculate weights: lower accuracy = higher weight
        let weights = calculateWeights(for: available, stats: characterStats)

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
    ///   - groupLength: Number of characters in the group
    /// - Returns: A balanced practice group
    static func generateMixedGroup(
        level: Int,
        characterStats: [Character: CharacterStat],
        groupLength: Int = 5
    ) -> String {
        let available = MorseCode.characters(forLevel: level)
        guard !available.isEmpty else { return "" }

        // If we have stats, use retention weighting
        // Otherwise, use learning mode
        let hasStats = available.contains { characterStats[$0] != nil }

        if hasStats {
            return generateRetentionGroup(
                level: level,
                characterStats: characterStats,
                groupLength: groupLength
            )
        } else {
            return generateLearningGroup(level: level, groupLength: groupLength)
        }
    }

    // MARK: - Weight Calculation

    /// Calculate selection weights based on inverse accuracy.
    /// Characters with lower accuracy get higher weights.
    private static func calculateWeights(
        for characters: [Character],
        stats: [Character: CharacterStat]
    ) -> [Double] {
        // Minimum weight ensures even mastered characters appear occasionally
        let minWeight = 0.1
        // Maximum weight caps how much we emphasize weak characters
        let maxWeight = 1.0
        // Default weight for unpracticed characters (treat as needing practice)
        let defaultWeight = 0.7

        return characters.map { char in
            guard let stat = stats[char], stat.totalAttempts >= 3 else {
                // Not enough data; use default weight
                return defaultWeight
            }

            // Inverse accuracy: 90% accuracy → 0.1 weight, 50% accuracy → 0.5 weight
            let inverseAccuracy = 1.0 - stat.accuracy

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

        // Fallback (shouldn't reach here)
        return characters.last!
    }
}
