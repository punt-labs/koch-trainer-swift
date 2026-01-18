import Foundation

/// Input mode for send training.
enum SendInputMode: String, Codable {
    case paddle
    // Future: case straightKey
}

/// Application settings persisted to UserDefaults.
struct AppSettings: Codable, Equatable {
    /// Tone frequency in Hz (400-800)
    var toneFrequency: Double

    /// Effective Farnsworth speed in WPM (10-18)
    var effectiveSpeed: Int

    /// Send training input mode
    var sendInputMode: SendInputMode

    /// Notification preferences
    var notificationSettings: NotificationSettings

    init(
        toneFrequency: Double = 600,
        effectiveSpeed: Int = 12,
        sendInputMode: SendInputMode = .paddle,
        notificationSettings: NotificationSettings = NotificationSettings()
    ) {
        self.toneFrequency = max(400, min(800, toneFrequency))
        self.effectiveSpeed = max(10, min(18, effectiveSpeed))
        self.sendInputMode = sendInputMode
        self.notificationSettings = notificationSettings
    }
}

// MARK: - Codable with migration support

extension AppSettings {
    enum CodingKeys: String, CodingKey {
        case toneFrequency, effectiveSpeed, sendInputMode, notificationSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toneFrequency = try container.decode(Double.self, forKey: .toneFrequency)
        effectiveSpeed = try container.decode(Int.self, forKey: .effectiveSpeed)
        sendInputMode = try container.decode(SendInputMode.self, forKey: .sendInputMode)

        // Migration: provide default if not present
        notificationSettings = try container.decodeIfPresent(NotificationSettings.self, forKey: .notificationSettings)
            ?? NotificationSettings()
    }
}
