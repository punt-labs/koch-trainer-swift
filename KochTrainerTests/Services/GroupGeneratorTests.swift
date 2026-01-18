import XCTest
@testable import KochTrainer

final class GroupGeneratorTests: XCTestCase {

    // MARK: - Pattern Family Tests

    func testPatternFamilySingleElement() {
        let family = GroupGenerator.PatternFamily.singleElement
        XCTAssertEqual(family.characters, ["E", "T"])
    }

    func testPatternFamilyDoubleElement() {
        let family = GroupGenerator.PatternFamily.doubleElement
        XCTAssertTrue(family.characters.contains("I"))
        XCTAssertTrue(family.characters.contains("M"))
        XCTAssertTrue(family.characters.contains("A"))
        XCTAssertTrue(family.characters.contains("N"))
    }

    func testPatternFamilyLookup() {
        XCTAssertEqual(GroupGenerator.PatternFamily.family(for: "E"), .singleElement)
        XCTAssertEqual(GroupGenerator.PatternFamily.family(for: "T"), .singleElement)
        XCTAssertEqual(GroupGenerator.PatternFamily.family(for: "S"), .tripleElement)
        XCTAssertEqual(GroupGenerator.PatternFamily.family(for: "H"), .quadElement)
    }

    func testAllCharactersHaveFamily() {
        for char in MorseCode.kochOrder {
            XCTAssertNotNil(
                GroupGenerator.PatternFamily.family(for: char),
                "Character \(char) has no pattern family"
            )
        }
    }

    // MARK: - Learning Group Tests

    func testLearningGroupLength() {
        let group = GroupGenerator.generateLearningGroup(level: 5, groupLength: 5)
        XCTAssertEqual(group.count, 5)
    }

    func testLearningGroupContainsOnlyAvailableChars() {
        let level = 5
        let available = Set(MorseCode.characters(forLevel: level))

        for _ in 0..<20 {
            let group = GroupGenerator.generateLearningGroup(level: level, groupLength: 5)
            for char in group {
                XCTAssertTrue(available.contains(char), "Character \(char) not available at level \(level)")
            }
        }
    }

    func testLearningGroupEmphasizesNewestCharacter() {
        // At level 5, newest character is U
        var newestCount = 0
        let iterations = 100

        for _ in 0..<iterations {
            let group = GroupGenerator.generateLearningGroup(level: 5, groupLength: 5)
            newestCount += group.filter { $0 == "U" }.count
        }

        // Should appear at least twice per group on average (due to emphasis)
        let averageCount = Double(newestCount) / Double(iterations)
        XCTAssertGreaterThan(averageCount, 1.5, "Newest character should be emphasized")
    }

    func testLearningGroupLevel1() {
        let group = GroupGenerator.generateLearningGroup(level: 1, groupLength: 5)
        // Only K is available at level 1
        XCTAssertTrue(group.allSatisfy { $0 == "K" })
    }

    // MARK: - Retention Group Tests

    func testRetentionGroupLength() {
        let group = GroupGenerator.generateRetentionGroup(
            level: 5,
            characterStats: [:],
            sessionType: .receive,
            groupLength: 4
        )
        XCTAssertEqual(group.count, 4)
    }

    func testRetentionGroupWeightsLowReceiveAccuracy() {
        // K has 50% receive accuracy, others have 90%
        let stats: [Character: CharacterStat] = [
            "K": CharacterStat(receiveAttempts: 100, receiveCorrect: 50),
            "M": CharacterStat(receiveAttempts: 100, receiveCorrect: 90),
            "R": CharacterStat(receiveAttempts: 100, receiveCorrect: 90),
            "S": CharacterStat(receiveAttempts: 100, receiveCorrect: 90),
            "U": CharacterStat(receiveAttempts: 100, receiveCorrect: 90)
        ]

        var kCount = 0
        let iterations = 500

        for _ in 0..<iterations {
            let group = GroupGenerator.generateRetentionGroup(
                level: 5,
                characterStats: stats,
                sessionType: .receive,
                groupLength: 5
            )
            kCount += group.filter { $0 == "K" }.count
        }

        // K should appear more than 1/5 of the time due to lower accuracy
        let expectedUniform = Double(iterations * 5) / 5.0
        XCTAssertGreaterThan(
            Double(kCount),
            expectedUniform * 1.3,
            "Low accuracy character should be weighted higher"
        )
    }

    func testRetentionGroupWeightsLowSendAccuracy() {
        // K has 50% send accuracy, others have 90%
        let stats: [Character: CharacterStat] = [
            "K": CharacterStat(sendAttempts: 100, sendCorrect: 50),
            "M": CharacterStat(sendAttempts: 100, sendCorrect: 90),
            "R": CharacterStat(sendAttempts: 100, sendCorrect: 90),
            "S": CharacterStat(sendAttempts: 100, sendCorrect: 90),
            "U": CharacterStat(sendAttempts: 100, sendCorrect: 90)
        ]

        var kCount = 0
        let iterations = 500

        for _ in 0..<iterations {
            let group = GroupGenerator.generateRetentionGroup(
                level: 5,
                characterStats: stats,
                sessionType: .send,
                groupLength: 5
            )
            kCount += group.filter { $0 == "K" }.count
        }

        // K should appear more than 1/5 of the time due to lower send accuracy
        let expectedUniform = Double(iterations * 5) / 5.0
        XCTAssertGreaterThan(
            Double(kCount),
            expectedUniform * 1.3,
            "Low send accuracy character should be weighted higher"
        )
    }

    func testRetentionGroupUsesCorrectDirection() {
        // K has low receive accuracy but high send accuracy
        let stats: [Character: CharacterStat] = [
            "K": CharacterStat(
                receiveAttempts: 100, receiveCorrect: 50,
                sendAttempts: 100, sendCorrect: 95
            ),
            "M": CharacterStat(
                receiveAttempts: 100, receiveCorrect: 90,
                sendAttempts: 100, sendCorrect: 90
            )
        ]

        // For receive mode, K should be weighted higher (low receive accuracy)
        var kCountReceive = 0
        for _ in 0..<200 {
            let group = GroupGenerator.generateRetentionGroup(
                level: 2,
                characterStats: stats,
                sessionType: .receive,
                groupLength: 5
            )
            kCountReceive += group.filter { $0 == "K" }.count
        }

        // For send mode, M should be weighted higher (K has high send accuracy)
        var kCountSend = 0
        for _ in 0..<200 {
            let group = GroupGenerator.generateRetentionGroup(
                level: 2,
                characterStats: stats,
                sessionType: .send,
                groupLength: 5
            )
            kCountSend += group.filter { $0 == "K" }.count
        }

        // K should appear MORE in receive mode than send mode
        XCTAssertGreaterThan(kCountReceive, kCountSend,
            "K should appear more in receive mode (where it has low accuracy)")
    }

    func testRetentionGroupWithNoStats() {
        let group = GroupGenerator.generateRetentionGroup(
            level: 5,
            characterStats: [:],
            sessionType: .receive,
            groupLength: 5
        )

        // Should still generate valid group
        XCTAssertEqual(group.count, 5)
        let available = Set(MorseCode.characters(forLevel: 5))
        XCTAssertTrue(group.allSatisfy { available.contains($0) })
    }

    // MARK: - Mixed Group Tests

    func testMixedGroupWithReceiveStats() {
        let stats: [Character: CharacterStat] = [
            "K": CharacterStat(receiveAttempts: 10, receiveCorrect: 5)
        ]

        let group = GroupGenerator.generateMixedGroup(
            level: 5,
            characterStats: stats,
            sessionType: .receive,
            groupLength: 5
        )

        XCTAssertEqual(group.count, 5)
    }

    func testMixedGroupWithSendStats() {
        let stats: [Character: CharacterStat] = [
            "K": CharacterStat(sendAttempts: 10, sendCorrect: 5)
        ]

        let group = GroupGenerator.generateMixedGroup(
            level: 5,
            characterStats: stats,
            sessionType: .send,
            groupLength: 5
        )

        XCTAssertEqual(group.count, 5)
    }

    func testMixedGroupWithoutStats() {
        let group = GroupGenerator.generateMixedGroup(
            level: 5,
            characterStats: [:],
            sessionType: .receive,
            groupLength: 5
        )

        // Should fall back to learning mode
        XCTAssertEqual(group.count, 5)
    }

    func testMixedGroupFallsBackWhenNoDirectionStats() {
        // Has receive stats but requesting send mode
        let stats: [Character: CharacterStat] = [
            "K": CharacterStat(receiveAttempts: 10, receiveCorrect: 5)
        ]

        let group = GroupGenerator.generateMixedGroup(
            level: 5,
            characterStats: stats,
            sessionType: .send,  // No send stats exist
            groupLength: 5
        )

        // Should fall back to learning mode since no send stats
        XCTAssertEqual(group.count, 5)
    }

    func testMixedGroupEmptyLevel() {
        let group = GroupGenerator.generateMixedGroup(
            level: 0,
            characterStats: [:],
            sessionType: .receive,
            groupLength: 5
        )

        // Level 0 clamps to level 1 (K only)
        XCTAssertTrue(group.allSatisfy { $0 == "K" })
    }

    // MARK: - Edge Cases

    func testEmptyGroupLength() {
        let group = GroupGenerator.generateLearningGroup(level: 5, groupLength: 0)
        XCTAssertEqual(group.count, 0)
    }

    func testSingleCharacterGroup() {
        let group = GroupGenerator.generateRetentionGroup(
            level: 10,
            characterStats: [:],
            sessionType: .receive,
            groupLength: 1
        )
        XCTAssertEqual(group.count, 1)
    }

    func testHighLevel() {
        let group = GroupGenerator.generateMixedGroup(
            level: 26,
            characterStats: [:],
            sessionType: .receive,
            groupLength: 5
        )

        XCTAssertEqual(group.count, 5)
        // All 26 characters available
        let available = Set(MorseCode.kochOrder)
        XCTAssertTrue(group.allSatisfy { available.contains($0) })
    }
}
