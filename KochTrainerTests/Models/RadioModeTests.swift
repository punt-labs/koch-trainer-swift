@testable import KochTrainer
import XCTest

/// Tests for RadioMode enum based on Z specification invariants.
///
/// From Z specification (docs/koch_trainer.tex):
/// - radioOff: Radio not active
/// - radioReceiving: Radio on, listening
/// - radioTransmitting: Radio on, sending (sidetone only)
final class RadioModeTests: XCTestCase {

    // MARK: - Enum Cases

    func testRadioMode_hasThreeCases() {
        // Verify all cases from Z spec exist
        let off = RadioMode.off
        let receiving = RadioMode.receiving
        let transmitting = RadioMode.transmitting

        XCTAssertEqual(off, .off)
        XCTAssertEqual(receiving, .receiving)
        XCTAssertEqual(transmitting, .transmitting)
    }

    func testRadioMode_casesAreDistinct() {
        XCTAssertNotEqual(RadioMode.off, RadioMode.receiving)
        XCTAssertNotEqual(RadioMode.off, RadioMode.transmitting)
        XCTAssertNotEqual(RadioMode.receiving, RadioMode.transmitting)
    }

    // MARK: - Equatable

    func testRadioMode_equatable() {
        XCTAssertEqual(RadioMode.off, RadioMode.off)
        XCTAssertEqual(RadioMode.receiving, RadioMode.receiving)
        XCTAssertEqual(RadioMode.transmitting, RadioMode.transmitting)
    }

    // MARK: - Sendable

    func testRadioMode_isSendable() {
        // RadioMode should be Sendable for thread-safe audio callback access
        let mode: RadioMode = .receiving
        Task {
            // This compiles only if RadioMode is Sendable
            _ = mode
        }
    }
}
