import Foundation

/// Generates word selections for vocabulary training sessions.
/// Weights selection toward words with lower accuracy (like GroupGenerator for characters).
enum VocabularyGroupGenerator {

    // MARK: Internal

    /// Select words from a vocabulary set weighted by inverse accuracy.
    /// Words with lower accuracy get selected more often.
    /// - Parameters:
    ///   - vocabularySet: The set of words to choose from
    ///   - wordStats: Per-word accuracy statistics
    ///   - sessionType: Training direction (receive or send)
    ///   - count: Number of words to select
    /// - Returns: Array of words weighted by inverse accuracy
    static func selectWords(
        from vocabularySet: VocabularySet,
        wordStats: [String: WordStat],
        sessionType: SessionType,
        count: Int = 10
    ) -> [String] {
        let words = vocabularySet.words
        guard !words.isEmpty else { return [] }

        let weights = calculateWeights(for: words, stats: wordStats, sessionType: sessionType)

        var selected: [String] = []
        var remainingWords = words
        var remainingWeights = weights

        for _ in 0 ..< min(count, words.count) {
            let word = weightedRandomSelection(from: remainingWords, weights: remainingWeights)
            selected.append(word)

            // Remove selected word to avoid immediate repeats (if we have enough words)
            if remainingWords.count > 1 {
                if let index = remainingWords.firstIndex(of: word) {
                    remainingWords.remove(at: index)
                    remainingWeights.remove(at: index)
                }
            }
        }

        return selected
    }

    /// Select a single word for the next practice item.
    /// - Parameters:
    ///   - vocabularySet: The set of words to choose from
    ///   - wordStats: Per-word accuracy statistics
    ///   - sessionType: Training direction (receive or send)
    ///   - recentWords: Words to avoid (recently practiced)
    /// - Returns: A single word weighted by inverse accuracy
    static func selectNextWord(
        from vocabularySet: VocabularySet,
        wordStats: [String: WordStat],
        sessionType: SessionType,
        avoiding recentWords: [String] = []
    ) -> String? {
        var words = vocabularySet.words.filter { !recentWords.contains($0) }

        // If all words are recent, use the full set
        if words.isEmpty {
            words = vocabularySet.words
        }

        guard !words.isEmpty else { return nil }

        let weights = calculateWeights(for: words, stats: wordStats, sessionType: sessionType)
        return weightedRandomSelection(from: words, weights: weights)
    }

    // MARK: Private

    // MARK: - Weight Calculation

    /// Calculate selection weights based on inverse accuracy for a specific direction.
    /// Words with lower accuracy get higher weights.
    private static func calculateWeights(
        for words: [String],
        stats: [String: WordStat],
        sessionType: SessionType
    ) -> [Double] {
        // Minimum weight ensures even mastered words appear occasionally
        let minWeight = 0.1
        // Maximum weight caps how much we emphasize weak words
        let maxWeight = 1.0
        // Default weight for unpracticed words (treat as needing practice)
        let defaultWeight = 0.7
        // Minimum attempts required before weighting by accuracy
        let minAttempts = 3

        return words.map { word in
            guard let stat = stats[word] else {
                return defaultWeight
            }

            // Get direction-specific attempts and accuracy
            let attempts: Int
            let accuracy: Double
            switch sessionType.baseType {
            case .receive:
                attempts = stat.receiveAttempts
                accuracy = stat.receiveAccuracy
            case .send:
                attempts = stat.sendAttempts
                accuracy = stat.sendAccuracy
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
        from words: [String],
        weights: [Double]
    ) -> String {
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else {
            return words.randomElement() ?? ""
        }

        var random = Double.random(in: 0 ..< totalWeight)

        for (index, weight) in weights.enumerated() {
            random -= weight
            if random <= 0 {
                return words[index]
            }
        }

        // Fallback (shouldn't reach here)
        return words.last ?? ""
    }
}
