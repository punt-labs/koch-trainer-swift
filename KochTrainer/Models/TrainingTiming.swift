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

    // MARK: - Response Timeouts (seconds)

    /// Timeout for single keystroke input (Receive training: user types one letter)
    static let singleCharacterTimeout: TimeInterval = 3.0

    /// Base timeout for pattern input (Send/Ear training)
    static let patternInputBaseTimeout: TimeInterval = 1.0

    /// Additional time per element in pattern (dit or dah)
    static let timePerPatternElement: TimeInterval = 0.8

    /// Calculate timeout for pattern input based on pattern length.
    /// - Parameter patternLength: Number of dits/dahs in the pattern (1-5)
    /// - Returns: Timeout in seconds (e.g., 5 elements = 1.0 + 5*0.8 = 5.0 seconds)
    static func timeoutForPattern(length: Int) -> TimeInterval {
        patternInputBaseTimeout + Double(length) * timePerPatternElement
    }

    /// Calculate timeout for a specific character's pattern.
    /// - Parameter character: The target character
    /// - Returns: Timeout in seconds based on pattern length
    static func timeoutForCharacter(_ character: Character) -> TimeInterval {
        let patternLength = MorseCode.pattern(for: character)?.count ?? 1
        return timeoutForPattern(length: patternLength)
    }
}
