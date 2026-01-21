@testable import KochTrainer
import XCTest

final class AppSettingsCodableTests: XCTestCase {

    // MARK: - Encoding/Decoding Tests

    func testEncodingAndDecoding() throws {
        let original = AppSettings(
            toneFrequency: 700,
            effectiveSpeed: 15,
            sendInputMode: .paddle,
            userCallsign: "W1AW",
            bandConditionsEnabled: true,
            noiseLevel: 0.4,
            fadingEnabled: false,
            fadingDepth: 0.6,
            fadingRate: 0.2,
            interferenceEnabled: true,
            interferenceLevel: 0.3
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    func testDecodingWithAllFieldsPresent() throws {
        let json = """
        {
            "toneFrequency": 650,
            "effectiveSpeed": 14,
            "sendInputMode": "paddle",
            "notificationSettings": {
                "practiceRemindersEnabled": true,
                "streakRemindersEnabled": true,
                "preferredReminderHour": 9,
                "preferredReminderMinute": 0,
                "quietHoursEnabled": true
            },
            "userCallsign": "K4ABC",
            "bandConditionsEnabled": true,
            "noiseLevel": 0.5,
            "fadingEnabled": true,
            "fadingDepth": 0.7,
            "fadingRate": 0.15,
            "interferenceEnabled": true,
            "interferenceLevel": 0.4
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.toneFrequency, 650)
        XCTAssertEqual(settings.effectiveSpeed, 14)
        XCTAssertEqual(settings.sendInputMode, .paddle)
        XCTAssertEqual(settings.userCallsign, "K4ABC")
        XCTAssertTrue(settings.bandConditionsEnabled)
        XCTAssertEqual(settings.noiseLevel, 0.5)
        XCTAssertTrue(settings.fadingEnabled)
        XCTAssertEqual(settings.fadingDepth, 0.7)
        XCTAssertEqual(settings.fadingRate, 0.15)
        XCTAssertTrue(settings.interferenceEnabled)
        XCTAssertEqual(settings.interferenceLevel, 0.4)
    }

    // MARK: - Migration Tests

    func testDecodingMigrationWithMissingOptionalFields() throws {
        // Simulates decoding from an older version without band conditions fields
        let json = """
        {
            "toneFrequency": 600,
            "effectiveSpeed": 12,
            "sendInputMode": "paddle"
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        // Required fields decoded
        XCTAssertEqual(settings.toneFrequency, 600)
        XCTAssertEqual(settings.effectiveSpeed, 12)
        XCTAssertEqual(settings.sendInputMode, .paddle)

        // Optional fields get defaults
        XCTAssertEqual(settings.userCallsign, "")
        XCTAssertFalse(settings.bandConditionsEnabled)
        XCTAssertEqual(settings.noiseLevel, 0.3)
        XCTAssertTrue(settings.fadingEnabled)
        XCTAssertEqual(settings.fadingDepth, 0.5)
        XCTAssertEqual(settings.fadingRate, 0.1)
        XCTAssertFalse(settings.interferenceEnabled)
        XCTAssertEqual(settings.interferenceLevel, 0.2)
    }

    func testDecodingMigrationWithPartialBandConditions() throws {
        // Simulates decoding with some but not all band condition fields
        let json = """
        {
            "toneFrequency": 600,
            "effectiveSpeed": 12,
            "sendInputMode": "paddle",
            "userCallsign": "N5XYZ",
            "bandConditionsEnabled": true,
            "noiseLevel": 0.6
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.userCallsign, "N5XYZ")
        XCTAssertTrue(settings.bandConditionsEnabled)
        XCTAssertEqual(settings.noiseLevel, 0.6)

        // Missing band condition fields get defaults
        XCTAssertTrue(settings.fadingEnabled)
        XCTAssertEqual(settings.fadingDepth, 0.5)
        XCTAssertEqual(settings.fadingRate, 0.1)
        XCTAssertFalse(settings.interferenceEnabled)
        XCTAssertEqual(settings.interferenceLevel, 0.2)
    }

    // MARK: - SendInputMode Codable Tests

    func testSendInputModePaddleRawValue() {
        XCTAssertEqual(SendInputMode.paddle.rawValue, "paddle")
    }

    func testSendInputModeDecodable() throws {
        let json = "\"paddle\""
        let data = try XCTUnwrap(json.data(using: .utf8))
        let mode = try JSONDecoder().decode(SendInputMode.self, from: data)
        XCTAssertEqual(mode, .paddle)
    }

    func testSendInputModeEncodable() throws {
        let encoded = try JSONEncoder().encode(SendInputMode.paddle)
        let string = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(string, "\"paddle\"")
    }
}
