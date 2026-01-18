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

    init(
        toneFrequency: Double = 600,
        effectiveSpeed: Int = 12,
        sendInputMode: SendInputMode = .paddle
    ) {
        self.toneFrequency = max(400, min(800, toneFrequency))
        self.effectiveSpeed = max(10, min(18, effectiveSpeed))
        self.sendInputMode = sendInputMode
    }
}
