import Combine
import Foundation

/// Training session attempt counter per Z specification.
///
/// Enforces the invariant: `correct ≤ attempts`
///
/// The only way to increment `correct` is via `recordAttempt(wasCorrect: true)`,
/// which always increments `attempts` first. This makes it impossible to
/// construct a state where `correct > attempts`.
///
/// From Z specification (docs/koch_trainer.tex):
/// ```
/// sessionCorrect ≤ sessionAttempts
/// ```
@MainActor
final class SessionCounter: ObservableObject {

    /// Total number of attempts in the session.
    @Published private(set) var attempts: Int = 0

    /// Number of correct attempts in the session.
    /// Invariant: `correct ≤ attempts`
    @Published private(set) var correct: Int = 0

    /// Accuracy as a ratio (0.0 to 1.0).
    /// Returns 0 if no attempts have been made.
    var accuracy: Double {
        attempts > 0 ? Double(correct) / Double(attempts) : 0
    }

    /// Record an attempt result.
    /// - Parameter wasCorrect: Whether the attempt was correct.
    ///
    /// This is the only way to increment counters, ensuring the invariant
    /// `correct ≤ attempts` is always maintained.
    func recordAttempt(wasCorrect: Bool) {
        attempts += 1
        if wasCorrect {
            correct += 1
        }
    }

    /// Reset counters to zero.
    func reset() {
        attempts = 0
        correct = 0
    }
}
