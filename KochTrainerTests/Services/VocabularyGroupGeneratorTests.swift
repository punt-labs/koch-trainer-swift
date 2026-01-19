@testable import KochTrainer
import XCTest

final class VocabularyGroupGeneratorTests: XCTestCase {

    // MARK: Internal

    // MARK: - Select Words Tests

    func testSelectWordsFromSet() {
        let words = VocabularyGroupGenerator.selectWords(
            from: testSet,
            wordStats: [:],
            sessionType: .receive,
            count: 3
        )

        XCTAssertEqual(words.count, 3)
        // All selected words should be from the test set
        for word in words {
            XCTAssertTrue(testSet.words.contains(word))
        }
    }

    func testSelectWordsDoesNotExceedSetSize() {
        let words = VocabularyGroupGenerator.selectWords(
            from: testSet,
            wordStats: [:],
            sessionType: .receive,
            count: 10 // More than available
        )

        XCTAssertEqual(words.count, 5) // Limited to set size
    }

    func testSelectWordsFromEmptySet() {
        let emptySet = VocabularySet(name: "Empty", words: [])
        let words = VocabularyGroupGenerator.selectWords(
            from: emptySet,
            wordStats: [:],
            sessionType: .receive,
            count: 5
        )

        XCTAssertTrue(words.isEmpty)
    }

    // MARK: - Select Next Word Tests

    func testSelectNextWordFromSet() {
        let word = VocabularyGroupGenerator.selectNextWord(
            from: testSet,
            wordStats: [:],
            sessionType: .receive
        )

        XCTAssertNotNil(word)
        if let word {
            XCTAssertTrue(testSet.words.contains(word))
        }
    }

    func testSelectNextWordFromEmptySet() {
        let emptySet = VocabularySet(name: "Empty", words: [])
        let word = VocabularyGroupGenerator.selectNextWord(
            from: emptySet,
            wordStats: [:],
            sessionType: .receive
        )

        XCTAssertNil(word)
    }

    func testSelectNextWordAvoidsRecentWords() {
        // Use a set with just 3 words
        let smallSet = VocabularySet(name: "Small", words: ["CQ", "DE", "K"])

        // Run many selections avoiding 2 of the 3 words
        var seenK = false
        for _ in 0 ..< 20 {
            let word = VocabularyGroupGenerator.selectNextWord(
                from: smallSet,
                wordStats: [:],
                sessionType: .receive,
                avoiding: ["CQ", "DE"]
            )
            if word == "K" {
                seenK = true
            }
        }

        // K should be selected most/all of the time
        XCTAssertTrue(seenK)
    }

    func testSelectNextWordFallsBackWhenAllRecent() {
        // Avoid all words
        let word = VocabularyGroupGenerator.selectNextWord(
            from: testSet,
            wordStats: [:],
            sessionType: .receive,
            avoiding: testSet.words
        )

        // Should fall back to selecting from full set
        XCTAssertNotNil(word)
        if let word {
            XCTAssertTrue(testSet.words.contains(word))
        }
    }

    // MARK: - Weighted Selection Tests

    func testWeightedSelectionFavorsWeakWords() {
        // Create stats where "CQ" has low accuracy and "DE" has high accuracy
        let stats: [String: WordStat] = [
            "CQ": WordStat(receiveAttempts: 10, receiveCorrect: 3), // 30% accuracy
            "DE": WordStat(receiveAttempts: 10, receiveCorrect: 9), // 90% accuracy
            "K": WordStat(receiveAttempts: 10, receiveCorrect: 9), // 90% accuracy
            "AR": WordStat(receiveAttempts: 10, receiveCorrect: 9), // 90% accuracy
            "SK": WordStat(receiveAttempts: 10, receiveCorrect: 9) // 90% accuracy
        ]

        // Run many selections and count how often CQ (the weak word) is selected
        var cqCount = 0
        let iterations = 100

        for _ in 0 ..< iterations {
            let word = VocabularyGroupGenerator.selectNextWord(
                from: testSet,
                wordStats: stats,
                sessionType: .receive
            )
            if word == "CQ" {
                cqCount += 1
            }
        }

        // CQ should be selected more than uniform distribution (1/5 = 20%)
        // With proper weighting, it should be significantly higher
        XCTAssertGreaterThan(cqCount, 25, "Weak word should be selected more often than uniform distribution")
    }

    func testSendModeUsesCorrectStats() {
        // Create stats where receive and send accuracies differ
        let stats: [String: WordStat] = [
            "CQ": WordStat(
                receiveAttempts: 10,
                receiveCorrect: 9,
                sendAttempts: 10,
                sendCorrect: 3
            ), // High receive, low send
            "DE": WordStat(
                receiveAttempts: 10,
                receiveCorrect: 3,
                sendAttempts: 10,
                sendCorrect: 9
            ), // Low receive, high send
            "K": WordStat(receiveAttempts: 10, receiveCorrect: 9, sendAttempts: 10, sendCorrect: 9),
            "AR": WordStat(receiveAttempts: 10, receiveCorrect: 9, sendAttempts: 10, sendCorrect: 9),
            "SK": WordStat(receiveAttempts: 10, receiveCorrect: 9, sendAttempts: 10, sendCorrect: 9)
        ]

        // For send mode, CQ should be selected more often (it's weak in send)
        var cqCountSend = 0
        let iterations = 100

        for _ in 0 ..< iterations {
            let word = VocabularyGroupGenerator.selectNextWord(
                from: testSet,
                wordStats: stats,
                sessionType: .send
            )
            if word == "CQ" {
                cqCountSend += 1
            }
        }

        // CQ should be favored in send mode
        XCTAssertGreaterThan(cqCountSend, 25, "CQ should be selected more in send mode where it's weak")
    }

    // MARK: - Insufficient Attempts Tests

    func testWordsWithFewAttemptsGetDefaultWeight() {
        // Create stats with insufficient attempts (< 3)
        let stats: [String: WordStat] = [
            "CQ": WordStat(receiveAttempts: 2, receiveCorrect: 2), // 100% but insufficient data
            "DE": WordStat(receiveAttempts: 10, receiveCorrect: 9), // 90% with sufficient data
            "K": WordStat(receiveAttempts: 10, receiveCorrect: 9),
            "AR": WordStat(receiveAttempts: 10, receiveCorrect: 9),
            "SK": WordStat(receiveAttempts: 10, receiveCorrect: 9)
        ]

        // CQ should have default weight (0.7) despite 100% accuracy because of insufficient attempts
        var cqCount = 0
        let iterations = 100

        for _ in 0 ..< iterations {
            let word = VocabularyGroupGenerator.selectNextWord(
                from: testSet,
                wordStats: stats,
                sessionType: .receive
            )
            if word == "CQ" {
                cqCount += 1
            }
        }

        // CQ should be selected more than its accuracy would suggest due to default weight
        XCTAssertGreaterThan(cqCount, 10, "Words with insufficient data should be practiced")
    }

    // MARK: Private

    // MARK: - Test Vocabulary Set

    private let testSet = VocabularySet(
        name: "Test Set",
        words: ["CQ", "DE", "K", "AR", "SK"],
        isBuiltIn: true
    )

}
