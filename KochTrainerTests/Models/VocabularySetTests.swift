@testable import KochTrainer
import XCTest

final class VocabularySetTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization() {
        let set = VocabularySet(name: "Test Set", words: ["CQ", "DE", "K"])

        XCTAssertEqual(set.name, "Test Set")
        XCTAssertEqual(set.words, ["CQ", "DE", "K"])
        XCTAssertFalse(set.isBuiltIn)
    }

    func testInitializationUppercasesWords() {
        let set = VocabularySet(name: "Test", words: ["cq", "de", "k"])

        XCTAssertEqual(set.words, ["CQ", "DE", "K"])
    }

    func testInitializationWithBuiltInFlag() {
        let set = VocabularySet(name: "Test", words: ["CQ"], isBuiltIn: true)

        XCTAssertTrue(set.isBuiltIn)
    }

    func testInitializationGeneratesUniqueID() {
        let set1 = VocabularySet(name: "Test", words: ["CQ"])
        let set2 = VocabularySet(name: "Test", words: ["CQ"])

        XCTAssertNotEqual(set1.id, set2.id)
    }

    // MARK: - Built-in Sets Tests

    func testCommonWordsSetExists() {
        let set = VocabularySet.commonWords

        XCTAssertEqual(set.name, "Common Words")
        XCTAssertTrue(set.isBuiltIn)
        XCTAssertFalse(set.words.isEmpty)
    }

    func testCommonWordsContainsExpectedWords() {
        let set = VocabularySet.commonWords

        XCTAssertTrue(set.words.contains("CQ"))
        XCTAssertTrue(set.words.contains("DE"))
        XCTAssertTrue(set.words.contains("K"))
        XCTAssertTrue(set.words.contains("73"))
        XCTAssertTrue(set.words.contains("QTH"))
        XCTAssertTrue(set.words.contains("RST"))
    }

    func testCallsignPatternsSetExists() {
        let set = VocabularySet.callsignPatterns

        XCTAssertEqual(set.name, "Callsign Patterns")
        XCTAssertTrue(set.isBuiltIn)
        XCTAssertFalse(set.words.isEmpty)
    }

    func testCallsignPatternsContainsExpectedCallsigns() {
        let set = VocabularySet.callsignPatterns

        XCTAssertTrue(set.words.contains("W1AW"))
        XCTAssertTrue(set.words.contains("VE3ABC"))
        XCTAssertTrue(set.words.contains("G4ABC"))
        XCTAssertTrue(set.words.contains("JA1ABC"))
    }

    // MARK: - User Callsign Factory Tests

    func testUserCallsignFactory() {
        let set = VocabularySet.userCallsign("w5abc")

        XCTAssertEqual(set.name, "Your Callsign")
        XCTAssertEqual(set.words, ["W5ABC"])
        XCTAssertFalse(set.isBuiltIn)
    }

    func testUserCallsignFactoryUppercases() {
        let set = VocabularySet.userCallsign("k0xyz")

        XCTAssertEqual(set.words, ["K0XYZ"])
    }

    // MARK: - Identifiable Tests

    func testIdentifiable() {
        let set = VocabularySet(name: "Test", words: ["CQ"])

        XCTAssertNotNil(set.id)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = VocabularySet(
            name: "Test Set",
            words: ["CQ", "DE", "K"],
            isBuiltIn: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VocabularySet.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.words, original.words)
        XCTAssertEqual(decoded.isBuiltIn, original.isBuiltIn)
    }

    // MARK: - Equatable Tests

    func testEqualityByID() {
        let id = UUID()
        let set1 = VocabularySet(id: id, name: "Test", words: ["CQ"])
        let set2 = VocabularySet(id: id, name: "Test", words: ["CQ"])

        XCTAssertEqual(set1, set2)
    }

    func testInequalityByID() {
        let set1 = VocabularySet(name: "Test", words: ["CQ"])
        let set2 = VocabularySet(name: "Test", words: ["CQ"])

        // Different IDs even though same content
        XCTAssertNotEqual(set1, set2)
    }

    // MARK: - Empty Set Tests

    func testEmptySet() {
        let set = VocabularySet(name: "Empty", words: [])

        XCTAssertTrue(set.words.isEmpty)
    }
}
