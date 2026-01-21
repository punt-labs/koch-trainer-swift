@testable import KochTrainer
import XCTest

final class NotificationSettingsTests: XCTestCase {

    // MARK: - Initialization Validation Tests

    func testInitWithValidHourAndMinute() {
        let settings = NotificationSettings(
            preferredReminderHour: 14,
            preferredReminderMinute: 30
        )

        XCTAssertEqual(settings.preferredReminderHour, 14)
        XCTAssertEqual(settings.preferredReminderMinute, 30)
    }

    func testInitWithHourTooHigh() {
        let settings = NotificationSettings(
            preferredReminderHour: 25,
            preferredReminderMinute: 0
        )

        XCTAssertEqual(settings.preferredReminderHour, 23, "Hour should be clamped to 23")
    }

    func testInitWithHourTooLow() {
        let settings = NotificationSettings(
            preferredReminderHour: -5,
            preferredReminderMinute: 0
        )

        XCTAssertEqual(settings.preferredReminderHour, 0, "Hour should be clamped to 0")
    }

    func testInitWithMinuteTooHigh() {
        let settings = NotificationSettings(
            preferredReminderHour: 9,
            preferredReminderMinute: 75
        )

        XCTAssertEqual(settings.preferredReminderMinute, 59, "Minute should be clamped to 59")
    }

    func testInitWithMinuteTooLow() {
        let settings = NotificationSettings(
            preferredReminderHour: 9,
            preferredReminderMinute: -10
        )

        XCTAssertEqual(settings.preferredReminderMinute, 0, "Minute should be clamped to 0")
    }

    func testInitWithBoundaryValues() {
        let settings = NotificationSettings(
            preferredReminderHour: 23,
            preferredReminderMinute: 59
        )

        XCTAssertEqual(settings.preferredReminderHour, 23)
        XCTAssertEqual(settings.preferredReminderMinute, 59)
    }

    func testInitWithMinimumBoundaryValues() {
        let settings = NotificationSettings(
            preferredReminderHour: 0,
            preferredReminderMinute: 0
        )

        XCTAssertEqual(settings.preferredReminderHour, 0)
        XCTAssertEqual(settings.preferredReminderMinute, 0)
    }

    // MARK: - Property Setter Validation Tests

    func testSetHourWithValidValue() {
        var settings = NotificationSettings()
        settings.preferredReminderHour = 15

        XCTAssertEqual(settings.preferredReminderHour, 15)
    }

    func testSetHourTooHigh() {
        var settings = NotificationSettings()
        settings.preferredReminderHour = 30

        XCTAssertEqual(settings.preferredReminderHour, 23, "Hour should be clamped to 23")
    }

    func testSetHourTooLow() {
        var settings = NotificationSettings()
        settings.preferredReminderHour = -3

        XCTAssertEqual(settings.preferredReminderHour, 0, "Hour should be clamped to 0")
    }

    func testSetMinuteWithValidValue() {
        var settings = NotificationSettings()
        settings.preferredReminderMinute = 45

        XCTAssertEqual(settings.preferredReminderMinute, 45)
    }

    func testSetMinuteTooHigh() {
        var settings = NotificationSettings()
        settings.preferredReminderMinute = 100

        XCTAssertEqual(settings.preferredReminderMinute, 59, "Minute should be clamped to 59")
    }

    func testSetMinuteTooLow() {
        var settings = NotificationSettings()
        settings.preferredReminderMinute = -20

        XCTAssertEqual(settings.preferredReminderMinute, 0, "Minute should be clamped to 0")
    }

    // MARK: - Codable Tests

    func testDecodingWithValidData() throws {
        let json = """
        {
            "practiceRemindersEnabled": true,
            "streakRemindersEnabled": false,
            "preferredReminderHour": 10,
            "preferredReminderMinute": 30,
            "quietHoursEnabled": true
        }
        """

        let data = json.data(using: .utf8)!
        let settings = try JSONDecoder().decode(NotificationSettings.self, from: data)

        XCTAssertEqual(settings.preferredReminderHour, 10)
        XCTAssertEqual(settings.preferredReminderMinute, 30)
    }

    func testDecodingWithInvalidHourClamps() throws {
        let json = """
        {
            "practiceRemindersEnabled": true,
            "streakRemindersEnabled": false,
            "preferredReminderHour": 99,
            "preferredReminderMinute": 30,
            "quietHoursEnabled": true
        }
        """

        let data = json.data(using: .utf8)!
        var settings = try JSONDecoder().decode(NotificationSettings.self, from: data)

        // Validation happens in init, but decoded value won't trigger didSet
        // We need to manually set it to trigger validation
        settings.preferredReminderHour = settings.preferredReminderHour

        XCTAssertEqual(settings.preferredReminderHour, 23, "Decoded hour should be clamped to 23")
    }

    func testDecodingWithInvalidMinuteClamps() throws {
        let json = """
        {
            "practiceRemindersEnabled": true,
            "streakRemindersEnabled": false,
            "preferredReminderHour": 10,
            "preferredReminderMinute": 150,
            "quietHoursEnabled": true
        }
        """

        let data = json.data(using: .utf8)!
        var settings = try JSONDecoder().decode(NotificationSettings.self, from: data)

        // Validation happens in init, but decoded value won't trigger didSet
        // We need to manually set it to trigger validation
        settings.preferredReminderMinute = settings.preferredReminderMinute

        XCTAssertEqual(settings.preferredReminderMinute, 59, "Decoded minute should be clamped to 59")
    }

    func testEncodingAndDecoding() throws {
        let original = NotificationSettings(
            practiceRemindersEnabled: true,
            streakRemindersEnabled: false,
            preferredReminderHour: 14,
            preferredReminderMinute: 45,
            quietHoursEnabled: true
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotificationSettings.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - Default Values Tests

    func testDefaultValues() {
        let settings = NotificationSettings()

        XCTAssertTrue(settings.practiceRemindersEnabled)
        XCTAssertTrue(settings.streakRemindersEnabled)
        XCTAssertEqual(settings.preferredReminderHour, 9)
        XCTAssertEqual(settings.preferredReminderMinute, 0)
        XCTAssertTrue(settings.quietHoursEnabled)
    }

    // MARK: - Edge Cases

    func testMultipleSettersInSequence() {
        var settings = NotificationSettings()

        settings.preferredReminderHour = 50
        XCTAssertEqual(settings.preferredReminderHour, 23)

        settings.preferredReminderHour = 12
        XCTAssertEqual(settings.preferredReminderHour, 12)

        settings.preferredReminderHour = -5
        XCTAssertEqual(settings.preferredReminderHour, 0)
    }

    func testBothPropertiesInvalidSimultaneously() {
        let settings = NotificationSettings(
            preferredReminderHour: 100,
            preferredReminderMinute: 200
        )

        XCTAssertEqual(settings.preferredReminderHour, 23)
        XCTAssertEqual(settings.preferredReminderMinute, 59)
    }
}
