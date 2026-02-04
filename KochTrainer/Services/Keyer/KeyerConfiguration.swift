import Foundation

/// Configuration for the iambic keyer.
///
/// Timing is derived from WPM using PARIS calibration:
/// - PARIS = 50 dit units
/// - At W WPM: dit duration = 1200/W ms = 1.2/W seconds
struct KeyerConfiguration: Equatable, Sendable {

    // MARK: Lifecycle

    init(
        wpm: Int = 13,
        frequency: Double = 700,
        hapticEnabled: Bool = true
    ) {
        _wpm = max(Self.wpmRange.lowerBound, min(Self.wpmRange.upperBound, wpm))
        _frequency = max(Self.frequencyRange.lowerBound, min(Self.frequencyRange.upperBound, frequency))
        self.hapticEnabled = hapticEnabled
    }

    // MARK: Internal

    /// Valid WPM range for keyer (5-40)
    static let wpmRange = 5 ... 40

    /// Valid frequency range for keyer tone (400-1000 Hz)
    static let frequencyRange: ClosedRange<Double> = 400 ... 1000

    /// Whether haptic feedback is enabled
    var hapticEnabled: Bool

    /// Keyer speed in words per minute (5-40)
    var wpm: Int {
        get { _wpm }
        set { _wpm = max(Self.wpmRange.lowerBound, min(Self.wpmRange.upperBound, newValue)) }
    }

    /// Tone frequency in Hz (400-1000)
    var frequency: Double {
        get { _frequency }
        set { _frequency = max(Self.frequencyRange.lowerBound, min(Self.frequencyRange.upperBound, newValue)) }
    }

    // MARK: - Computed Timing (PARIS calibration)

    /// Duration of one dit in seconds.
    /// PARIS calibration: 1200ms at 1 WPM → 1.2/WPM seconds.
    var ditDuration: TimeInterval {
        1.2 / Double(_wpm)
    }

    /// Duration of one dah (3 × dit).
    var dahDuration: TimeInterval {
        ditDuration * 3
    }

    /// Gap between elements within a character (1 dit).
    var elementGap: TimeInterval {
        ditDuration
    }

    /// Gap between characters (3 dits). Used for character boundary detection.
    var characterGap: TimeInterval {
        ditDuration * 3
    }

    /// Idle timeout for character boundary detection (1.5 × dah).
    /// When no paddle is pressed for this duration after input,
    /// the pattern is considered complete.
    var idleTimeout: TimeInterval {
        dahDuration * 1.5
    }

    // MARK: Private

    private var _wpm: Int
    private var _frequency: Double

}
