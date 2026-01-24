@testable import KochTrainer
import XCTest

/// Tests for Radio state machine per Z specification invariants.
///
/// Key invariants from Z specification:
/// - `¬(mode = receiving ∧ isKeying)` — can only key while transmitting
/// - `¬(mode = off ∧ isKeying)` — can only key while transmitting
/// - Mode transitions require `mode = off`
final class RadioTests: XCTestCase {

    // MARK: - Initial State

    func testInitialState_isOff() {
        let radio = Radio()
        XCTAssertEqual(radio.mode, .off)
        XCTAssertFalse(radio.isKeying)
    }

    // MARK: - Happy Path: Mode Transitions

    func testStartReceiving_fromOff_succeeds() throws {
        let radio = Radio()
        try radio.startReceiving()
        XCTAssertEqual(radio.mode, .receiving)
    }

    func testStartTransmitting_fromOff_succeeds() throws {
        let radio = Radio()
        try radio.startTransmitting()
        XCTAssertEqual(radio.mode, .transmitting)
    }

    func testStop_fromReceiving_succeeds() throws {
        let radio = Radio()
        try radio.startReceiving()
        try radio.stop()
        XCTAssertEqual(radio.mode, .off)
    }

    func testStop_fromTransmitting_succeeds() throws {
        let radio = Radio()
        try radio.startTransmitting()
        try radio.stop()
        XCTAssertEqual(radio.mode, .off)
    }

    // MARK: - Happy Path: Keying

    func testKey_whileTransmitting_succeeds() throws {
        let radio = Radio()
        try radio.startTransmitting()
        try radio.key()
        XCTAssertTrue(radio.isKeying)
    }

    func testUnkey_whileTransmitting_succeeds() throws {
        let radio = Radio()
        try radio.startTransmitting()
        try radio.key()
        try radio.unkey()
        XCTAssertFalse(radio.isKeying)
    }

    func testStop_clearsKeying() throws {
        let radio = Radio()
        try radio.startTransmitting()
        try radio.key()
        XCTAssertTrue(radio.isKeying)
        try radio.stop()
        XCTAssertFalse(radio.isKeying)
        XCTAssertEqual(radio.mode, .off)
    }

    // MARK: - Constraint Violations: Mode Transitions

    func testStartReceiving_fromReceiving_throws() throws {
        let radio = Radio()
        try radio.startReceiving()

        XCTAssertThrowsError(try radio.startReceiving()) { error in
            guard let radioError = error as? Radio.RadioError else {
                XCTFail("Expected RadioError, got \(type(of: error))")
                return
            }
            XCTAssertEqual(radioError, .mustBeOff(current: .receiving))
        }
    }

    func testStartReceiving_fromTransmitting_throws() throws {
        let radio = Radio()
        try radio.startTransmitting()

        XCTAssertThrowsError(try radio.startReceiving()) { error in
            guard let radioError = error as? Radio.RadioError else {
                XCTFail("Expected RadioError, got \(type(of: error))")
                return
            }
            XCTAssertEqual(radioError, .mustBeOff(current: .transmitting))
        }
    }

    func testStartTransmitting_fromReceiving_throws() throws {
        let radio = Radio()
        try radio.startReceiving()

        XCTAssertThrowsError(try radio.startTransmitting()) { error in
            guard let radioError = error as? Radio.RadioError else {
                XCTFail("Expected RadioError, got \(type(of: error))")
                return
            }
            XCTAssertEqual(radioError, .mustBeOff(current: .receiving))
        }
    }

    func testStartTransmitting_fromTransmitting_throws() throws {
        let radio = Radio()
        try radio.startTransmitting()

        XCTAssertThrowsError(try radio.startTransmitting()) { error in
            guard let radioError = error as? Radio.RadioError else {
                XCTFail("Expected RadioError, got \(type(of: error))")
                return
            }
            XCTAssertEqual(radioError, .mustBeOff(current: .transmitting))
        }
    }

    func testStop_fromOff_throws() {
        let radio = Radio()

        XCTAssertThrowsError(try radio.stop()) { error in
            guard let radioError = error as? Radio.RadioError else {
                XCTFail("Expected RadioError, got \(type(of: error))")
                return
            }
            XCTAssertEqual(radioError, .alreadyOff)
        }
    }

    // MARK: - Constraint Violations: Keying

    func testKey_whileOff_throws() {
        let radio = Radio()

        XCTAssertThrowsError(try radio.key()) { error in
            guard let radioError = error as? Radio.RadioError else {
                XCTFail("Expected RadioError, got \(type(of: error))")
                return
            }
            XCTAssertEqual(radioError, .mustBeTransmitting(current: .off))
        }
    }

    func testKey_whileReceiving_throws() throws {
        let radio = Radio()
        try radio.startReceiving()

        XCTAssertThrowsError(try radio.key()) { error in
            guard let radioError = error as? Radio.RadioError else {
                XCTFail("Expected RadioError, got \(type(of: error))")
                return
            }
            XCTAssertEqual(radioError, .mustBeTransmitting(current: .receiving))
        }
    }

    func testUnkey_whileOff_throws() {
        let radio = Radio()

        XCTAssertThrowsError(try radio.unkey()) { error in
            guard let radioError = error as? Radio.RadioError else {
                XCTFail("Expected RadioError, got \(type(of: error))")
                return
            }
            XCTAssertEqual(radioError, .mustBeTransmitting(current: .off))
        }
    }

    func testUnkey_whileReceiving_throws() throws {
        let radio = Radio()
        try radio.startReceiving()

        XCTAssertThrowsError(try radio.unkey()) { error in
            guard let radioError = error as? Radio.RadioError else {
                XCTFail("Expected RadioError, got \(type(of: error))")
                return
            }
            XCTAssertEqual(radioError, .mustBeTransmitting(current: .receiving))
        }
    }

    // MARK: - Invariant Tests

    /// Verifies invariant: `¬(mode = receiving ∧ isKeying)`.
    /// The only way to set `isKeying = true` is via `key()`, which requires transmitting.
    func testInvariant_cannotKeyWhileReceiving() throws {
        let radio = Radio()
        try radio.startReceiving()

        // Attempting to key while receiving should throw
        XCTAssertThrowsError(try radio.key())

        // Invariant holds: not keying while receiving
        XCTAssertEqual(radio.mode, .receiving)
        XCTAssertFalse(radio.isKeying)
    }

    /// Verifies invariant: `¬(mode = off ∧ isKeying)`.
    /// The only way to set `isKeying = true` is via `key()`, which requires transmitting.
    func testInvariant_cannotKeyWhileOff() {
        let radio = Radio()

        // Attempting to key while off should throw
        XCTAssertThrowsError(try radio.key())

        // Invariant holds: not keying while off
        XCTAssertEqual(radio.mode, .off)
        XCTAssertFalse(radio.isKeying)
    }

    /// Verifies that stopping while keying clears keying state.
    /// This ensures invariant `¬(mode = off ∧ isKeying)` is maintained after stop.
    func testInvariant_stopClearsKeying() throws {
        let radio = Radio()
        try radio.startTransmitting()
        try radio.key()

        // Keying is active
        XCTAssertTrue(radio.isKeying)

        // Stop clears keying
        try radio.stop()

        // Invariant holds: not keying while off
        XCTAssertEqual(radio.mode, .off)
        XCTAssertFalse(radio.isKeying)
    }

    // MARK: - Error Content Tests

    func testRadioError_mustBeOff_includesCurrentMode() throws {
        let radio = Radio()
        try radio.startReceiving()

        do {
            try radio.startTransmitting()
            XCTFail("Expected error to be thrown")
        } catch let error as Radio.RadioError {
            switch error {
            case let .mustBeOff(current):
                XCTAssertEqual(current, .receiving)
            default:
                XCTFail("Expected mustBeOff error, got \(error)")
            }
        }
    }

    func testRadioError_mustBeTransmitting_includesCurrentMode() throws {
        let radio = Radio()
        try radio.startReceiving()

        do {
            try radio.key()
            XCTFail("Expected error to be thrown")
        } catch let error as Radio.RadioError {
            switch error {
            case let .mustBeTransmitting(current):
                XCTAssertEqual(current, .receiving)
            default:
                XCTFail("Expected mustBeTransmitting error, got \(error)")
            }
        }
    }

    // MARK: - State Machine Round Trip

    func testFullLifecycle_receiveStopTransmitKeyUnkeyStop() throws {
        let radio = Radio()

        // Start receiving
        try radio.startReceiving()
        XCTAssertEqual(radio.mode, .receiving)
        XCTAssertFalse(radio.isKeying)

        // Stop
        try radio.stop()
        XCTAssertEqual(radio.mode, .off)

        // Start transmitting
        try radio.startTransmitting()
        XCTAssertEqual(radio.mode, .transmitting)

        // Key
        try radio.key()
        XCTAssertTrue(radio.isKeying)

        // Unkey
        try radio.unkey()
        XCTAssertFalse(radio.isKeying)

        // Stop
        try radio.stop()
        XCTAssertEqual(radio.mode, .off)
        XCTAssertFalse(radio.isKeying)
    }

    // MARK: - Sendable Conformance

    func testRadio_isSendable() {
        let radio = Radio()

        // This compiles only if Radio is Sendable
        Task {
            _ = radio.mode
            _ = radio.isKeying
        }
    }

    // MARK: - Concurrent Access

    /// Verifies thread safety under concurrent load.
    /// Multiple tasks rapidly key/unkey while the main thread reads state.
    func testConcurrentAccess_maintainsInvariants() async throws {
        let radio = Radio()
        try radio.startTransmitting()

        let iterations = 1000
        let expectation = XCTestExpectation(description: "Concurrent access completes")
        expectation.expectedFulfillmentCount = 2

        // Task 1: Rapidly key/unkey
        Task {
            for _ in 0 ..< iterations {
                try? radio.key()
                try? radio.unkey()
            }
            expectation.fulfill()
        }

        // Task 2: Rapidly read state and verify invariants
        Task {
            for _ in 0 ..< iterations {
                let mode = radio.mode
                let keying = radio.isKeying

                // Invariant: if keying, must be transmitting
                if keying {
                    XCTAssertEqual(mode, .transmitting, "Invariant violated: keying while not transmitting")
                }
            }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)

        // Final state should be consistent
        try radio.stop()
        XCTAssertEqual(radio.mode, .off)
        XCTAssertFalse(radio.isKeying)
    }
}
