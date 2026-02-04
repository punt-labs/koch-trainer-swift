import CoreHaptics
import Foundation
import os

/// Manager for Core Haptics tactile feedback.
/// Provides different haptic patterns for dit and dah elements.
final class HapticManager {

    // MARK: Lifecycle

    init() {
        prepareHaptics()
    }

    // MARK: Internal

    /// Shared instance for convenience.
    static let shared = HapticManager()

    /// Whether haptics are supported on this device.
    var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Play haptic feedback for a Morse element.
    /// - Parameter element: The element type (dit or dah).
    func playHaptic(for element: MorseElement) {
        guard supportsHaptics, let engine else { return }

        do {
            let pattern = try hapticPattern(for: element)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("Failed to play haptic: \(error.localizedDescription)")
        }
    }

    /// Prepare the haptic engine (call on app launch or when needed).
    func prepareHaptics() {
        guard supportsHaptics else {
            logger.info("Haptics not supported on this device")
            return
        }

        do {
            engine = try CHHapticEngine()
            engine?.stoppedHandler = { [weak self] reason in
                self?.logger.info("Haptic engine stopped: \(String(describing: reason))")
            }
            engine?.resetHandler = { [weak self] in
                self?.logger.info("Haptic engine reset")
                try? self?.engine?.start()
            }
            try engine?.start()
        } catch {
            logger.error("Failed to create haptic engine: \(error.localizedDescription)")
            engine = nil
        }
    }

    // MARK: Private

    private let logger = Logger(subsystem: "com.kochtrainer", category: "HapticManager")
    private var engine: CHHapticEngine?

    private func hapticPattern(for element: MorseElement) throws -> CHHapticPattern {
        switch element {
        case .dit:
            // Short, sharp tap
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: 0
            )
            return try CHHapticPattern(events: [event], parameters: [])

        case .dah:
            // Longer, slightly softer tap
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [intensity, sharpness],
                relativeTime: 0,
                duration: 0.1 // 100ms feel, shorter than actual dah audio
            )
            return try CHHapticPattern(events: [event], parameters: [])
        }
    }

}
