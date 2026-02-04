import Foundation
@testable import KochTrainer

/// Mock clock for deterministic keyer testing.
/// Advances time manually via `advance(by:)`.
final class MockClock: KeyerClock, @unchecked Sendable {

    // MARK: Internal

    var currentTime: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return _currentTime
    }

    func now() -> TimeInterval {
        currentTime
    }

    /// Advance the clock by the specified duration.
    func advance(by duration: TimeInterval) {
        lock.lock()
        _currentTime += duration
        lock.unlock()
    }

    /// Set the clock to a specific time.
    func set(to time: TimeInterval) {
        lock.lock()
        _currentTime = time
        lock.unlock()
    }

    /// Reset the clock to zero.
    func reset() {
        set(to: 0)
    }

    // MARK: Private

    private let lock = NSLock()
    private var _currentTime: TimeInterval = 0

}
