import Foundation

// MARK: - SendInputMode

/// Input mode for send training.
enum SendInputMode: String, Codable {
    case paddle
    // Future: case straightKey
}

// MARK: - AppSettings

/// Application settings persisted to UserDefaults.
struct AppSettings: Codable, Equatable {

    // MARK: Lifecycle

    init(
        toneFrequency: Double = 600,
        effectiveSpeed: Int = 12,
        sendInputMode: SendInputMode = .paddle,
        notificationSettings: NotificationSettings = NotificationSettings(),
        userCallsign: String = "",
        bandConditionsEnabled: Bool = false,
        noiseLevel: Double = 0.3,
        fadingEnabled: Bool = true,
        fadingDepth: Double = 0.5,
        fadingRate: Double = 0.1,
        interferenceEnabled: Bool = false,
        interferenceLevel: Double = 0.2,
        morseQSORevealDelay: Double = 0.3
    ) {
        self.toneFrequency = max(400, min(800, toneFrequency))
        self.effectiveSpeed = max(10, min(18, effectiveSpeed))
        self.sendInputMode = sendInputMode
        self.notificationSettings = notificationSettings
        self.userCallsign = userCallsign.uppercased()
        self.bandConditionsEnabled = bandConditionsEnabled
        self.noiseLevel = max(0, min(1, noiseLevel))
        self.fadingEnabled = fadingEnabled
        self.fadingDepth = max(0, min(1, fadingDepth))
        self.fadingRate = max(0.01, min(0.5, fadingRate))
        self.interferenceEnabled = interferenceEnabled
        self.interferenceLevel = max(0, min(1, interferenceLevel))
        self.morseQSORevealDelay = max(
            Self.morseQSORevealDelayRange.lowerBound,
            min(Self.morseQSORevealDelayRange.upperBound, morseQSORevealDelay)
        )
    }

    // MARK: Internal

    // MARK: - Range Constants

    /// Valid range for Morse QSO reveal delay (in seconds).
    static let morseQSORevealDelayRange: ClosedRange<Double> = 0.0 ... 2.0

    /// Tone frequency in Hz (400-800)
    var toneFrequency: Double

    /// Effective Farnsworth speed in WPM (10-18)
    var effectiveSpeed: Int

    /// Send training input mode
    var sendInputMode: SendInputMode

    /// Notification preferences
    var notificationSettings: NotificationSettings

    /// User's amateur radio callsign (for personalized vocabulary practice)
    var userCallsign: String

    // MARK: - Band Conditions

    /// Whether band conditions simulation is enabled
    var bandConditionsEnabled: Bool

    /// Atmospheric noise level (QRN), 0.0 - 1.0
    var noiseLevel: Double

    /// Whether signal fading is enabled (QSB)
    var fadingEnabled: Bool

    /// How deep fades go, 0.0 - 1.0
    var fadingDepth: Double

    /// How fast the signal fades in Hz (0.05 - 0.2 typical)
    var fadingRate: Double

    /// Whether interference from other stations is enabled (QRM)
    var interferenceEnabled: Bool

    /// Interference level, 0.0 - 1.0
    var interferenceLevel: Double

    // MARK: - Morse QSO Training

    /// Delay before revealing each character in Morse QSO training (0.0 - 2.0 seconds)
    /// Default 0.3s reveals text roughly as the next character plays
    var morseQSORevealDelay: Double

}

// MARK: - Codable with migration support

extension AppSettings {
    enum CodingKeys: String, CodingKey {
        case toneFrequency
        case effectiveSpeed
        case sendInputMode
        case notificationSettings
        case userCallsign
        case bandConditionsEnabled
        case noiseLevel
        case fadingEnabled
        case fadingDepth
        case fadingRate
        case interferenceEnabled
        case interferenceLevel
        case morseQSORevealDelay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toneFrequency = try container.decode(Double.self, forKey: .toneFrequency)
        effectiveSpeed = try container.decode(Int.self, forKey: .effectiveSpeed)
        sendInputMode = try container.decode(SendInputMode.self, forKey: .sendInputMode)

        // Migration: provide defaults if not present
        notificationSettings = try container.decodeIfPresent(NotificationSettings.self, forKey: .notificationSettings)
            ?? NotificationSettings()
        userCallsign = try container.decodeIfPresent(String.self, forKey: .userCallsign) ?? ""

        // Band conditions migration
        bandConditionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .bandConditionsEnabled) ?? false
        noiseLevel = try container.decodeIfPresent(Double.self, forKey: .noiseLevel) ?? 0.3
        fadingEnabled = try container.decodeIfPresent(Bool.self, forKey: .fadingEnabled) ?? true
        fadingDepth = try container.decodeIfPresent(Double.self, forKey: .fadingDepth) ?? 0.5
        fadingRate = try container.decodeIfPresent(Double.self, forKey: .fadingRate) ?? 0.1
        interferenceEnabled = try container.decodeIfPresent(Bool.self, forKey: .interferenceEnabled) ?? false
        interferenceLevel = try container.decodeIfPresent(Double.self, forKey: .interferenceLevel) ?? 0.2

        // Morse QSO training migration
        morseQSORevealDelay = try container.decodeIfPresent(Double.self, forKey: .morseQSORevealDelay) ?? 0.3
    }
}
