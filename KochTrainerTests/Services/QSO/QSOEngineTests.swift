@testable import KochTrainer
import XCTest

// MARK: - QSOEngineTests

@MainActor
final class QSOEngineTests: XCTestCase {

    // MARK: - Mock Audio Engine

    class MockAudioEngine: AudioEngineProtocol {
        var playedGroups: [String] = []
        var frequency: Double = 600
        var effectiveSpeed: Int = 12

        func playCharacter(_ char: Character) async {}
        func playGroup(_ group: String) async {
            playedGroups.append(group)
        }

        func playGroup(_ group: String, onCharacterPlayed: ((Character, Int) -> Void)?) async {
            playedGroups.append(group)
            // Call callback for each character to simulate playback
            for (index, char) in group.enumerated() {
                onCharacterPlayed?(char, index)
            }
        }

        func stop() {}
        func setFrequency(_ frequency: Double) {
            self.frequency = frequency
        }

        func setEffectiveSpeed(_ wpm: Int) {
            effectiveSpeed = wpm
        }

        func configureBandConditions(from settings: AppSettings) {}
    }

    // MARK: - Tests

    func testInitialState() {
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC")

        XCTAssertEqual(engine.state.phase, .idle)
        XCTAssertEqual(engine.state.myCallsign, "W5ABC")
        XCTAssertEqual(engine.state.style, .contest)
        XCTAssertTrue(engine.state.transcript.isEmpty)
    }

    func testStartQSOSetsCallingPhase() {
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC")

        engine.startQSO()

        XCTAssertEqual(engine.state.phase, .callingCQ)
    }

    func testCallsignUppercased() {
        let engine = QSOEngine(style: .contest, myCallsign: "w5abc")

        XCTAssertEqual(engine.state.myCallsign, "W5ABC")
    }

    func testStationGenerated() {
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC")

        XCTAssertFalse(engine.station.callsign.isEmpty)
        XCTAssertFalse(engine.station.name.isEmpty)
        XCTAssertFalse(engine.station.qth.isEmpty)
    }

    func testResetClearsState() {
        let engine = QSOEngine(style: .ragChew, myCallsign: "K1ABC")
        engine.startQSO()

        engine.reset()

        XCTAssertEqual(engine.state.phase, .idle)
        XCTAssertTrue(engine.state.transcript.isEmpty)
    }

    func testGetCurrentHintReturnsValue() {
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC")
        engine.startQSO()

        let hint = engine.getCurrentHint()

        XCTAssertTrue(hint.contains("CQ"))
        XCTAssertTrue(hint.contains("W5ABC"))
    }

    // MARK: - startWithAICQ Tests

    func testStartWithAICQSetsReceivedCallPhase() {
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC")

        _ = engine.startWithAICQ()

        XCTAssertEqual(engine.state.phase, .receivedCall)
    }

    func testStartWithAICQReturnsCQCallText() {
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC")

        let cqCall = engine.startWithAICQ()

        XCTAssertTrue(cqCall.contains("CQ"))
        XCTAssertTrue(cqCall.contains(engine.station.callsign))
    }

    func testStartWithAICQAddsMessageToTranscript() {
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC")

        let cqCall = engine.startWithAICQ()

        XCTAssertEqual(engine.state.transcript.count, 1)
        XCTAssertEqual(engine.state.transcript.first?.sender, .station)
        XCTAssertEqual(engine.state.transcript.first?.text, cqCall)
    }

    func testStartWithAICQSetsStationInfo() {
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC")

        _ = engine.startWithAICQ()

        XCTAssertEqual(engine.state.theirCallsign, engine.station.callsign)
        XCTAssertEqual(engine.state.theirName, engine.station.name)
        XCTAssertEqual(engine.state.theirQTH, engine.station.qth)
    }

    func testStartWithAICQResetsState() {
        let engine = QSOEngine(style: .ragChew, myCallsign: "K1ABC")
        engine.startQSO()
        // Simulate some state changes
        engine.state.exchangeCount = 5

        _ = engine.startWithAICQ()

        // State should be fresh except for phase and transcript
        XCTAssertEqual(engine.state.exchangeCount, 0)
        XCTAssertEqual(engine.state.phase, .receivedCall)
    }
}

// MARK: - CallsignGeneratorTests

final class CallsignGeneratorTests: XCTestCase {

    func testRandomUSCallsign() {
        let callsign = CallsignGenerator.randomUS()

        XCTAssertTrue(CallsignGenerator.isValid(callsign))
        // US callsigns: W/K/N + digit + 1-3 letters = 3-6 chars total
        XCTAssertGreaterThanOrEqual(callsign.count, 3)
        XCTAssertLessThanOrEqual(callsign.count, 6)
    }

    func testRandomEUCallsign() {
        let callsign = CallsignGenerator.randomEU()

        XCTAssertTrue(CallsignGenerator.isValid(callsign))
    }

    func testRandomVECallsign() {
        let callsign = CallsignGenerator.randomVE()

        XCTAssertTrue(CallsignGenerator.isValid(callsign))
        XCTAssertTrue(callsign.hasPrefix("VE") || callsign.hasPrefix("VA") || callsign.hasPrefix("VY"))
    }

    func testIsValidRejectsShortCallsigns() {
        XCTAssertFalse(CallsignGenerator.isValid("W1"))
    }

    func testIsValidRejectsLongCallsigns() {
        XCTAssertFalse(CallsignGenerator.isValid("W1ABCDEFG"))
    }

    func testIsValidRejectsNoDigit() {
        XCTAssertFalse(CallsignGenerator.isValid("WABCD"))
    }

    func testIsValidRejectsNoLetter() {
        XCTAssertFalse(CallsignGenerator.isValid("12345"))
    }

    func testIsValidAcceptsValidCallsigns() {
        XCTAssertTrue(CallsignGenerator.isValid("W5ABC"))
        XCTAssertTrue(CallsignGenerator.isValid("K0XYZ"))
        XCTAssertTrue(CallsignGenerator.isValid("DL1ABC"))
        XCTAssertTrue(CallsignGenerator.isValid("VE3ABC"))
    }
}

// MARK: - VirtualStationTests

final class VirtualStationTests: XCTestCase {

    func testRandomStationGeneration() {
        let station = VirtualStation.random()

        XCTAssertFalse(station.callsign.isEmpty)
        XCTAssertFalse(station.name.isEmpty)
        XCTAssertFalse(station.qth.isEmpty)
        XCTAssertGreaterThan(station.serialNumber, 0)
    }

    func testRandomRSTFormat() {
        let station = VirtualStation.random()
        let rst = station.randomRST

        XCTAssertEqual(rst.count, 3)
        XCTAssertTrue(rst.allSatisfy(\.isNumber))
    }

    func testFormattedSerialNumber() {
        let station = VirtualStation(callsign: "W1AW", name: "TEST", qth: "CT", serialNumber: 5)

        XCTAssertEqual(station.formattedSerialNumber, "005")
    }

    func testPresetStationsExist() {
        XCTAssertFalse(VirtualStation.presets.isEmpty)

        let w1aw = VirtualStation.presets.first { $0.callsign == "W1AW" }
        XCTAssertNotNil(w1aw)
        XCTAssertEqual(w1aw?.qth, "NEWINGTON CT")
    }
}
