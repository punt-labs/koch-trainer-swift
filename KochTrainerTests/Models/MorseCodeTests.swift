@testable import KochTrainer
import XCTest

final class MorseCodeTests: XCTestCase {

    // MARK: - Koch Order Tests

    func testKochOrderContains26Characters() {
        XCTAssertEqual(MorseCode.kochOrder.count, 26)
    }

    func testKochOrderStartsWithKMRSU() {
        let firstFive = Array(MorseCode.kochOrder.prefix(5))
        XCTAssertEqual(firstFive, ["K", "M", "R", "S", "U"])
    }

    func testKochOrderContainsAllLetters() {
        let alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let kochSet = Set(MorseCode.kochOrder)
        XCTAssertEqual(alphabet, kochSet)
    }

    // MARK: - Encoding Tests

    func testEncodingAllLetters() {
        // Verify all 26 letters have encodings
        for char in MorseCode.kochOrder {
            XCTAssertNotNil(MorseCode.encoding[char], "Missing encoding for \(char)")
        }
    }

    func testEncodingAllCharacters() {
        // Verify all 36 characters (26 letters + 10 digits) have encodings
        XCTAssertEqual(MorseCode.encoding.count, 36)
    }

    func testKnownEncodings() {
        XCTAssertEqual(MorseCode.pattern(for: "K"), "-.-")
        XCTAssertEqual(MorseCode.pattern(for: "M"), "--")
        XCTAssertEqual(MorseCode.pattern(for: "E"), ".")
        XCTAssertEqual(MorseCode.pattern(for: "T"), "-")
        XCTAssertEqual(MorseCode.pattern(for: "S"), "...")
        XCTAssertEqual(MorseCode.pattern(for: "O"), "---")
        XCTAssertEqual(MorseCode.pattern(for: "Q"), "--.-")
    }

    func testPatternForLowercaseCharacter() {
        XCTAssertEqual(MorseCode.pattern(for: "k"), "-.-")
        XCTAssertEqual(MorseCode.pattern(for: "e"), ".")
    }

    func testPatternForInvalidCharacter() {
        XCTAssertNil(MorseCode.pattern(for: "?"))
        XCTAssertNil(MorseCode.pattern(for: " "))
        XCTAssertNil(MorseCode.pattern(for: "@"))
    }

    // MARK: - Number Encoding Tests

    func testNumberEncodings() {
        XCTAssertEqual(MorseCode.pattern(for: "0"), "-----")
        XCTAssertEqual(MorseCode.pattern(for: "1"), ".----")
        XCTAssertEqual(MorseCode.pattern(for: "2"), "..---")
        XCTAssertEqual(MorseCode.pattern(for: "3"), "...--")
        XCTAssertEqual(MorseCode.pattern(for: "4"), "....-")
        XCTAssertEqual(MorseCode.pattern(for: "5"), ".....")
        XCTAssertEqual(MorseCode.pattern(for: "6"), "-....")
        XCTAssertEqual(MorseCode.pattern(for: "7"), "--...")
        XCTAssertEqual(MorseCode.pattern(for: "8"), "---..")
        XCTAssertEqual(MorseCode.pattern(for: "9"), "----.")
    }

    func testNumberDecodings() {
        XCTAssertEqual(MorseCode.character(for: "-----"), "0")
        XCTAssertEqual(MorseCode.character(for: ".----"), "1")
        XCTAssertEqual(MorseCode.character(for: "..---"), "2")
        XCTAssertEqual(MorseCode.character(for: "...--"), "3")
        XCTAssertEqual(MorseCode.character(for: "....-"), "4")
        XCTAssertEqual(MorseCode.character(for: "....."), "5")
        XCTAssertEqual(MorseCode.character(for: "-...."), "6")
        XCTAssertEqual(MorseCode.character(for: "--..."), "7")
        XCTAssertEqual(MorseCode.character(for: "---.."), "8")
        XCTAssertEqual(MorseCode.character(for: "----."), "9")
    }

    // MARK: - Decoding Tests

    func testDecodingAllPatterns() {
        for (char, pattern) in MorseCode.encoding {
            XCTAssertEqual(
                MorseCode.character(for: pattern),
                char,
                "Failed to decode pattern \(pattern) for \(char)"
            )
        }
    }

    func testDecodingKnownPatterns() {
        XCTAssertEqual(MorseCode.character(for: "-.-"), "K")
        XCTAssertEqual(MorseCode.character(for: "--"), "M")
        XCTAssertEqual(MorseCode.character(for: "."), "E")
        XCTAssertEqual(MorseCode.character(for: "-"), "T")
    }

    func testDecodingInvalidPattern() {
        XCTAssertNil(MorseCode.character(for: "------"))
        XCTAssertNil(MorseCode.character(for: ""))
        XCTAssertNil(MorseCode.character(for: "abc"))
    }

    // MARK: - Characters For Level Tests

    func testCharactersForLevel1() {
        let chars = MorseCode.characters(forLevel: 1)
        XCTAssertEqual(chars, ["K"])
    }

    func testCharactersForLevel5() {
        let chars = MorseCode.characters(forLevel: 5)
        XCTAssertEqual(chars, ["K", "M", "R", "S", "U"])
    }

    func testCharactersForLevel26() {
        let chars = MorseCode.characters(forLevel: 26)
        XCTAssertEqual(chars.count, 26)
        XCTAssertEqual(chars, MorseCode.kochOrder)
    }

    func testCharactersForLevelAbove26() {
        let chars = MorseCode.characters(forLevel: 100)
        XCTAssertEqual(chars.count, 26)
    }

    func testCharactersForLevelZeroReturnsOne() {
        let chars = MorseCode.characters(forLevel: 0)
        XCTAssertEqual(chars, ["K"])
    }

    func testCharactersForNegativeLevelReturnsOne() {
        let chars = MorseCode.characters(forLevel: -5)
        XCTAssertEqual(chars, ["K"])
    }

    // MARK: - Timing Tests

    func testDitDurationIs60ms() {
        XCTAssertEqual(MorseCode.Timing.ditDuration, 0.060, accuracy: 0.001)
    }

    func testDahDurationIs180ms() {
        XCTAssertEqual(MorseCode.Timing.dahDuration, 0.180, accuracy: 0.001)
    }

    func testDahIsThreeTimesDit() {
        XCTAssertEqual(MorseCode.Timing.dahDuration, MorseCode.Timing.ditDuration * 3, accuracy: 0.001)
    }

    func testElementGapEqualsDit() {
        XCTAssertEqual(MorseCode.Timing.elementGap, MorseCode.Timing.ditDuration, accuracy: 0.001)
    }

    func testFarnsworthCharacterGapIncreasesAtLowerSpeed() {
        let gap10 = MorseCode.Timing.farnsworthCharacterGap(effectiveWPM: 10)
        let gap15 = MorseCode.Timing.farnsworthCharacterGap(effectiveWPM: 15)
        let gap18 = MorseCode.Timing.farnsworthCharacterGap(effectiveWPM: 18)

        XCTAssertGreaterThan(gap10, gap15)
        XCTAssertGreaterThan(gap15, gap18)
    }

    func testFarnsworthWordGapIncreasesAtLowerSpeed() {
        let gap10 = MorseCode.Timing.farnsworthWordGap(effectiveWPM: 10)
        let gap15 = MorseCode.Timing.farnsworthWordGap(effectiveWPM: 15)
        let gap18 = MorseCode.Timing.farnsworthWordGap(effectiveWPM: 18)

        XCTAssertGreaterThan(gap10, gap15)
        XCTAssertGreaterThan(gap15, gap18)
    }

    func testFarnsworthGapClampsBelowMinimum() {
        let gap5 = MorseCode.Timing.farnsworthCharacterGap(effectiveWPM: 5)
        let gap10 = MorseCode.Timing.farnsworthCharacterGap(effectiveWPM: 10)
        XCTAssertEqual(gap5, gap10, accuracy: 0.001)
    }

    func testFarnsworthGapClampsAboveMaximum() {
        let gap25 = MorseCode.Timing.farnsworthCharacterGap(effectiveWPM: 25)
        let gap18 = MorseCode.Timing.farnsworthCharacterGap(effectiveWPM: 18)
        XCTAssertEqual(gap25, gap18, accuracy: 0.001)
    }

    // MARK: - Pattern Length Tests (Ear Training)

    func testPatternLengthGroupsCount() {
        XCTAssertEqual(MorseCode.patternLengthGroups.count, 5)
    }

    func testPatternLengthGroupsLevel1Contains2Characters() {
        let level1 = MorseCode.patternLengthGroups[0]
        XCTAssertEqual(level1, ["E", "T"])
    }

    func testPatternLengthGroupsLevel2Contains4Characters() {
        let level2 = MorseCode.patternLengthGroups[1]
        XCTAssertEqual(level2, ["A", "I", "M", "N"])
    }

    func testPatternLengthGroupsLevel3Contains8Characters() {
        let level3 = MorseCode.patternLengthGroups[2]
        XCTAssertEqual(level3.count, 8)
        XCTAssertTrue(level3.contains("K"))
        XCTAssertTrue(level3.contains("O"))
    }

    func testPatternLengthGroupsLevel4Contains12Characters() {
        let level4 = MorseCode.patternLengthGroups[3]
        XCTAssertEqual(level4.count, 12)
    }

    func testPatternLengthGroupsLevel5ContainsDigits() {
        let level5 = MorseCode.patternLengthGroups[4]
        XCTAssertEqual(level5.count, 10)
        for digit in "0123456789" {
            XCTAssertTrue(level5.contains(digit), "Missing digit \(digit)")
        }
    }

    func testMaxEarTrainingLevelIs5() {
        XCTAssertEqual(MorseCode.maxEarTrainingLevel, 5)
    }

    // MARK: - charactersByPatternLength Tests

    func testCharactersByPatternLengthLevel1() {
        let chars = MorseCode.charactersByPatternLength(upToLevel: 1)
        XCTAssertEqual(chars, ["E", "T"])
    }

    func testCharactersByPatternLengthLevel2IsCumulative() {
        let chars = MorseCode.charactersByPatternLength(upToLevel: 2)
        XCTAssertEqual(chars.count, 6) // 2 + 4
        XCTAssertEqual(chars, ["E", "T", "A", "I", "M", "N"])
    }

    func testCharactersByPatternLengthLevel3IsCumulative() {
        let chars = MorseCode.charactersByPatternLength(upToLevel: 3)
        XCTAssertEqual(chars.count, 14) // 2 + 4 + 8
    }

    func testCharactersByPatternLengthLevel5ContainsAll36() {
        let chars = MorseCode.charactersByPatternLength(upToLevel: 5)
        XCTAssertEqual(chars.count, 36) // 2 + 4 + 8 + 12 + 10
    }

    func testCharactersByPatternLengthClampsToMax() {
        let chars100 = MorseCode.charactersByPatternLength(upToLevel: 100)
        let chars5 = MorseCode.charactersByPatternLength(upToLevel: 5)
        XCTAssertEqual(chars100, chars5)
    }

    func testCharactersByPatternLengthClampsToMin() {
        let chars0 = MorseCode.charactersByPatternLength(upToLevel: 0)
        let chars1 = MorseCode.charactersByPatternLength(upToLevel: 1)
        XCTAssertEqual(chars0, chars1)
    }

    func testCharactersByPatternLengthNegativeClampsTo1() {
        let charsNeg = MorseCode.charactersByPatternLength(upToLevel: -5)
        XCTAssertEqual(charsNeg, ["E", "T"])
    }

    // MARK: - charactersAtPatternLength Tests

    func testCharactersAtPatternLengthLevel1() {
        let chars = MorseCode.charactersAtPatternLength(1)
        XCTAssertEqual(chars, ["E", "T"])
    }

    func testCharactersAtPatternLengthLevel2NotCumulative() {
        let chars = MorseCode.charactersAtPatternLength(2)
        XCTAssertEqual(chars, ["A", "I", "M", "N"])
        XCTAssertFalse(chars.contains("E"))
        XCTAssertFalse(chars.contains("T"))
    }

    func testCharactersAtPatternLengthLevel5() {
        let chars = MorseCode.charactersAtPatternLength(5)
        XCTAssertEqual(chars.count, 10)
        XCTAssertTrue(chars.contains("0"))
        XCTAssertTrue(chars.contains("9"))
    }

    func testCharactersAtPatternLengthInvalidReturnsEmpty() {
        XCTAssertEqual(MorseCode.charactersAtPatternLength(0), [])
        XCTAssertEqual(MorseCode.charactersAtPatternLength(-1), [])
        XCTAssertEqual(MorseCode.charactersAtPatternLength(6), [])
        XCTAssertEqual(MorseCode.charactersAtPatternLength(100), [])
    }

    // MARK: - Pattern Length Verification Tests

    func testAllLevel1CharactersHaveLength1Patterns() {
        for char in MorseCode.patternLengthGroups[0] {
            let pattern = MorseCode.pattern(for: char)
            XCTAssertNotNil(pattern)
            XCTAssertEqual(pattern?.count, 1, "Character \(char) should have length 1 pattern")
        }
    }

    func testAllLevel2CharactersHaveLength2Patterns() {
        for char in MorseCode.patternLengthGroups[1] {
            let pattern = MorseCode.pattern(for: char)
            XCTAssertNotNil(pattern)
            XCTAssertEqual(pattern?.count, 2, "Character \(char) should have length 2 pattern")
        }
    }

    func testAllLevel3CharactersHaveLength3Patterns() {
        for char in MorseCode.patternLengthGroups[2] {
            let pattern = MorseCode.pattern(for: char)
            XCTAssertNotNil(pattern)
            XCTAssertEqual(pattern?.count, 3, "Character \(char) should have length 3 pattern")
        }
    }

    func testAllLevel4CharactersHaveLength4Patterns() {
        for char in MorseCode.patternLengthGroups[3] {
            let pattern = MorseCode.pattern(for: char)
            XCTAssertNotNil(pattern)
            XCTAssertEqual(pattern?.count, 4, "Character \(char) should have length 4 pattern")
        }
    }

    func testAllLevel5CharactersHaveLength5Patterns() {
        for char in MorseCode.patternLengthGroups[4] {
            let pattern = MorseCode.pattern(for: char)
            XCTAssertNotNil(pattern)
            XCTAssertEqual(pattern?.count, 5, "Character \(char) should have length 5 pattern")
        }
    }
}
