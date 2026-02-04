import Foundation
import QuartzCore

// MARK: - KeyerClock

/// Protocol for time measurement, enabling deterministic testing of the keyer.
protocol KeyerClock: Sendable {
    /// Returns the current time as a monotonic timestamp.
    func now() -> TimeInterval
}

// MARK: - RealClock

/// Real clock implementation using CACurrentMediaTime for high-precision timing.
struct RealClock: KeyerClock {
    func now() -> TimeInterval {
        CACurrentMediaTime()
    }
}
