@testable import KochTrainer
import XCTest

@MainActor
final class SettingsStoreTests: XCTestCase {

    var testDefaults: UserDefaults?

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "TestSettingsStore")
        testDefaults?.removePersistentDomain(forName: "TestSettingsStore")
    }

    override func tearDown() {
        testDefaults?.removePersistentDomain(forName: "TestSettingsStore")
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationWithEmptyDefaults() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = SettingsStore(defaults: defaults)

        // Default values from AppSettings
        XCTAssertEqual(store.settings.toneFrequency, 600)
        XCTAssertEqual(store.settings.effectiveSpeed, 12)
        XCTAssertEqual(store.settings.sendInputMode, .paddle)
        XCTAssertEqual(store.settings.userCallsign, "")
        XCTAssertFalse(store.settings.bandConditionsEnabled)
    }

    func testInitializationLoadsExistingData() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        // Pre-save some settings
        let settings = AppSettings(
            toneFrequency: 700,
            effectiveSpeed: 15,
            userCallsign: "W1AW"
        )
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: "appSettings")

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.settings.toneFrequency, 700)
        XCTAssertEqual(store.settings.effectiveSpeed, 15)
        XCTAssertEqual(store.settings.userCallsign, "W1AW")
    }

    // MARK: - Save Tests

    func testSettingsPersistence() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = SettingsStore(defaults: defaults)

        // Modify settings through published property (triggers didSet save)
        store.settings.toneFrequency = 750
        store.settings.effectiveSpeed = 16
        store.settings.userCallsign = "K0ABC"

        // Verify by loading from defaults
        guard let data = defaults.data(forKey: "appSettings") else {
            XCTFail("No data saved")
            return
        }
        let loaded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(loaded.toneFrequency, 750)
        XCTAssertEqual(loaded.effectiveSpeed, 16)
        XCTAssertEqual(loaded.userCallsign, "K0ABC")
    }

    // MARK: - Invalid Data Tests

    func testInvalidDataFallsBackToDefaults() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        // Save invalid JSON
        defaults.set(Data("invalid json".utf8), forKey: "appSettings")

        let store = SettingsStore(defaults: defaults)

        // Should fall back to defaults
        XCTAssertEqual(store.settings.toneFrequency, 600)
        XCTAssertEqual(store.settings.effectiveSpeed, 12)
    }

    // MARK: - Band Conditions Tests

    func testBandConditionsSettingsPersistence() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = SettingsStore(defaults: defaults)

        store.settings.bandConditionsEnabled = true
        store.settings.noiseLevel = 0.5
        store.settings.fadingEnabled = true
        store.settings.fadingDepth = 0.7
        store.settings.interferenceEnabled = true
        store.settings.interferenceLevel = 0.4

        guard let data = defaults.data(forKey: "appSettings") else {
            XCTFail("No data saved")
            return
        }
        let loaded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertTrue(loaded.bandConditionsEnabled)
        XCTAssertEqual(loaded.noiseLevel, 0.5)
        XCTAssertTrue(loaded.fadingEnabled)
        XCTAssertEqual(loaded.fadingDepth, 0.7)
        XCTAssertTrue(loaded.interferenceEnabled)
        XCTAssertEqual(loaded.interferenceLevel, 0.4)
    }

    // MARK: - Value Clamping Tests

    func testFrequencyClampedToValidRange() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = SettingsStore(defaults: defaults)

        // Test lower bound
        store.settings = AppSettings(toneFrequency: 300) // Below min 400
        XCTAssertEqual(store.settings.toneFrequency, 400)

        // Test upper bound
        store.settings = AppSettings(toneFrequency: 900) // Above max 800
        XCTAssertEqual(store.settings.toneFrequency, 800)
    }

    func testEffectiveSpeedClampedToValidRange() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = SettingsStore(defaults: defaults)

        // Test lower bound
        store.settings = AppSettings(effectiveSpeed: 5) // Below min 10
        XCTAssertEqual(store.settings.effectiveSpeed, 10)

        // Test upper bound
        store.settings = AppSettings(effectiveSpeed: 25) // Above max 18
        XCTAssertEqual(store.settings.effectiveSpeed, 18)
    }
}
