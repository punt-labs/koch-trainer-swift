import Foundation

// MARK: - MorseElement

/// Input element for Morse decoding.
enum MorseElement {
    case dit
    case dah

    // MARK: Internal

    var symbol: String {
        switch self {
        case .dit: return "."
        case .dah: return "-"
        }
    }
}

// MARK: - DecodedResult

/// Result of attempting to decode a Morse pattern.
enum DecodedResult: Equatable {
    case character(Character)
    case invalid(pattern: String)
}

// MARK: - MorseDecoder

/// Decodes Morse code input from paddle buttons with timeout-based character completion.
final class MorseDecoder {

    // MARK: Lifecycle

    deinit {
        cancelTimeout()
    }

    // MARK: Internal

    /// Current pattern being built
    private(set) var currentPattern: String = ""

    /// Timeout duration: 1.5× dah length (~270ms at 20 WPM)
    let timeoutDuration: TimeInterval = MorseCode.Timing.dahDuration * 1.5

    /// Callback when a character is decoded (due to timeout)
    var onCharacterDecoded: ((DecodedResult) -> Void)?

    /// Process an input element (dit or dah).
    /// Returns a DecodedResult if the pattern completes a character,
    /// or nil if more input is needed.
    func processInput(_ element: MorseElement) -> DecodedResult? {
        cancelTimeout()

        currentPattern += element.symbol
        lastInputTime = Date()

        // Check if current pattern uniquely identifies a character
        // and no longer pattern exists
        if let char = MorseCode.character(for: currentPattern) {
            // Check if any valid pattern starts with this one
            let hasExtension = MorseCode.encoding.values.contains { pattern in
                pattern.hasPrefix(currentPattern) && pattern != currentPattern
            }

            if !hasExtension {
                // No possible extension, complete immediately
                let result = DecodedResult.character(char)
                reset()
                return result
            }
        }

        // Start timeout for character completion
        startTimeout()
        return nil
    }

    /// Check if timeout has elapsed and complete the character if so.
    /// Returns the decoded result, or nil if no timeout occurred.
    func checkTimeout() -> DecodedResult? {
        guard !currentPattern.isEmpty,
              let lastTime = lastInputTime,
              Date().timeIntervalSince(lastTime) >= timeoutDuration
        else {
            return nil
        }

        return completeCharacter()
    }

    /// Force completion of the current character.
    func completeCharacter() -> DecodedResult? {
        guard !currentPattern.isEmpty else { return nil }

        let pattern = currentPattern
        reset()

        if let char = MorseCode.character(for: pattern) {
            return .character(char)
        } else {
            return .invalid(pattern: pattern)
        }
    }

    /// Reset decoder state.
    func reset() {
        cancelTimeout()
        currentPattern = ""
        lastInputTime = nil
    }

    // MARK: Private

    /// Time of last input
    private var lastInputTime: Date?

    /// Timer for automatic character completion
    private var timeoutTimer: Timer?

    private func startTimeout() {
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if let result = self.completeCharacter() {
                self.onCharacterDecoded?(result)
            }
        }
    }

    private func cancelTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

}
