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
        interferenceLevel: Double = 0.2
    ) {
        _toneFrequency = max(400, min(800, toneFrequency))
        _effectiveSpeed = max(10, min(18, effectiveSpeed))
        self.sendInputMode = sendInputMode
        self.notificationSettings = notificationSettings
        _userCallsign = userCallsign.uppercased()
        self.bandConditionsEnabled = bandConditionsEnabled
        _noiseLevel = max(0, min(1, noiseLevel))
        self.fadingEnabled = fadingEnabled
        _fadingDepth = max(0, min(1, fadingDepth))
        _fadingRate = max(0.01, min(0.5, fadingRate))
        self.interferenceEnabled = interferenceEnabled
        _interferenceLevel = max(0, min(1, interferenceLevel))
    }

    // MARK: Internal

    /// Send training input mode
    var sendInputMode: SendInputMode

    /// Notification preferences
    var notificationSettings: NotificationSettings

    // MARK: - Band Conditions

    /// Whether band conditions simulation is enabled
    var bandConditionsEnabled: Bool

    /// Whether signal fading is enabled (QSB)
    var fadingEnabled: Bool

    /// Whether interference from other stations is enabled (QRM)
    var interferenceEnabled: Bool

    /// Tone frequency in Hz (400-800)
    var toneFrequency: Double {
        get { _toneFrequency }
        set { _toneFrequency = max(400, min(800, newValue)) }
    }

    /// Effective Farnsworth speed in WPM (10-18)
    var effectiveSpeed: Int {
        get { _effectiveSpeed }
        set { _effectiveSpeed = max(10, min(18, newValue)) }
    }

    /// User's amateur radio callsign (for personalized vocabulary practice)
    var userCallsign: String {
        get { _userCallsign }
        set { _userCallsign = newValue.uppercased() }
    }

    /// Atmospheric noise level (QRN), 0.0 - 1.0
    var noiseLevel: Double {
        get { _noiseLevel }
        set { _noiseLevel = max(0, min(1, newValue)) }
    }

    /// How deep fades go, 0.0 - 1.0
    var fadingDepth: Double {
        get { _fadingDepth }
        set { _fadingDepth = max(0, min(1, newValue)) }
    }

    /// How fast the signal fades in Hz (0.05 - 0.2 typical)
    var fadingRate: Double {
        get { _fadingRate }
        set { _fadingRate = max(0.01, min(0.5, newValue)) }
    }

    /// Interference level, 0.0 - 1.0
    var interferenceLevel: Double {
        get { _interferenceLevel }
        set { _interferenceLevel = max(0, min(1, newValue)) }
    }

    // MARK: Private

    private var _toneFrequency: Double
    private var _effectiveSpeed: Int
    private var _userCallsign: String
    private var _noiseLevel: Double
    private var _fadingDepth: Double
    private var _fadingRate: Double
    private var _interferenceLevel: Double

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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode and clamp required fields
        let frequency = try container.decode(Double.self, forKey: .toneFrequency)
        _toneFrequency = max(400, min(800, frequency))

        let speed = try container.decode(Int.self, forKey: .effectiveSpeed)
        _effectiveSpeed = max(10, min(18, speed))

        sendInputMode = try container.decode(SendInputMode.self, forKey: .sendInputMode)

        // Migration: provide defaults if not present
        notificationSettings = try container.decodeIfPresent(NotificationSettings.self, forKey: .notificationSettings)
            ?? NotificationSettings()

        let callsign = try container.decodeIfPresent(String.self, forKey: .userCallsign) ?? ""
        _userCallsign = callsign.uppercased()

        // Band conditions migration with clamping
        bandConditionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .bandConditionsEnabled) ?? false

        let noise = try container.decodeIfPresent(Double.self, forKey: .noiseLevel) ?? 0.3
        _noiseLevel = max(0, min(1, noise))

        fadingEnabled = try container.decodeIfPresent(Bool.self, forKey: .fadingEnabled) ?? true

        let depth = try container.decodeIfPresent(Double.self, forKey: .fadingDepth) ?? 0.5
        _fadingDepth = max(0, min(1, depth))

        let rate = try container.decodeIfPresent(Double.self, forKey: .fadingRate) ?? 0.1
        _fadingRate = max(0.01, min(0.5, rate))

        interferenceEnabled = try container.decodeIfPresent(Bool.self, forKey: .interferenceEnabled) ?? false

        let interference = try container.decodeIfPresent(Double.self, forKey: .interferenceLevel) ?? 0.2
        _interferenceLevel = max(0, min(1, interference))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_toneFrequency, forKey: .toneFrequency)
        try container.encode(_effectiveSpeed, forKey: .effectiveSpeed)
        try container.encode(sendInputMode, forKey: .sendInputMode)
        try container.encode(notificationSettings, forKey: .notificationSettings)
        try container.encode(_userCallsign, forKey: .userCallsign)
        try container.encode(bandConditionsEnabled, forKey: .bandConditionsEnabled)
        try container.encode(_noiseLevel, forKey: .noiseLevel)
        try container.encode(fadingEnabled, forKey: .fadingEnabled)
        try container.encode(_fadingDepth, forKey: .fadingDepth)
        try container.encode(_fadingRate, forKey: .fadingRate)
        try container.encode(interferenceEnabled, forKey: .interferenceEnabled)
        try container.encode(_interferenceLevel, forKey: .interferenceLevel)
    }
}
