import Foundation

// MARK: - MorseQSOResult

/// Summary of a completed Morse QSO training session.
struct MorseQSOResult {

    /// QSO style (contest or rag chew)
    let style: QSOStyle

    /// User's callsign
    let myCallsign: String

    /// AI station's callsign
    let theirCallsign: String

    /// AI operator's name
    let theirName: String

    /// AI station's location
    let theirQTH: String

    /// Total session duration
    let duration: TimeInterval

    /// Total characters the user attempted to key
    let totalCharactersKeyed: Int

    /// Characters keyed correctly
    let correctCharactersKeyed: Int

    /// Number of exchanges completed
    let exchangesCompleted: Int

    /// Keying accuracy as a percentage (0.0 - 1.0)
    var keyingAccuracy: Double {
        guard totalCharactersKeyed > 0 else { return 0 }
        return Double(correctCharactersKeyed) / Double(totalCharactersKeyed)
    }

    /// Formatted duration string (MM:SS)
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formatted accuracy as percentage string
    var formattedAccuracy: String {
        "\(Int(keyingAccuracy * 100))%"
    }

}
