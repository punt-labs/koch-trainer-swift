import Foundation

/// Shared timing constants for training sessions.
enum TrainingTiming {
    // MARK: - Feedback Delays (nanoseconds)

    /// Delay before playing the correct character after a wrong answer (0.4s)
    static let preReplayDelay: UInt64 = 400_000_000

    /// Delay after replaying the correct character on a wrong answer (3s)
    static let postReplayDelay: UInt64 = 3_000_000_000

    /// Delay after a correct answer before showing next (0.5s)
    static let correctAnswerDelay: UInt64 = 500_000_000

    /// Delay before auto-playing intro character (0.3s)
    static let introAutoPlayDelay: UInt64 = 300_000_000

    /// Delay between groups in receive training (0.5s)
    static let interGroupDelay: UInt64 = 500_000_000
}
