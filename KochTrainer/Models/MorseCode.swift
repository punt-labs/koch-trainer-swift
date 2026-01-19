import Foundation

/// Morse code encoding and Koch method character ordering.
/// Character speed fixed at 20 WPM (dit = 60ms).
enum MorseCode {
    /// Koch method character order for learning Morse code.
    /// Characters are introduced in this specific sequence based on
    /// Ludwig Koch's research on optimal learning order.
    static let kochOrder: [Character] = [
        "K", "M", "R", "S", "U", "A", "P", "T", "L", "O",
        "W", "I", "N", "J", "E", "F", "Y", "V", "G", "Q",
        "Z", "H", "B", "C", "D", "X"
    ]

    /// Morse code patterns: dot (.) = dit, dash (-) = dah
    static let encoding: [Character: String] = [
        "A": ".-", "B": "-...", "C": "-.-.", "D": "-..",
        "E": ".", "F": "..-.", "G": "--.", "H": "....",
        "I": "..", "J": ".---", "K": "-.-", "L": ".-..",
        "M": "--", "N": "-.", "O": "---", "P": ".--.",
        "Q": "--.-", "R": ".-.", "S": "...", "T": "-",
        "U": "..-", "V": "...-", "W": ".--", "X": "-..-",
        "Y": "-.--", "Z": "--.."
    ]

    /// Reverse lookup: pattern to character
    static let decoding: [String: Character] = {
        var result: [String: Character] = [:]
        for (char, pattern) in encoding {
            result[pattern] = char
        }
        return result
    }()

    /// Returns characters unlocked at a given level (1-26).
    /// Level 1 = [K], Level 2 = [K, M], etc.
    static func characters(forLevel level: Int) -> [Character] {
        let clampedLevel = max(1, min(level, kochOrder.count))
        return Array(kochOrder.prefix(clampedLevel))
    }

    /// Returns the Morse pattern for a character, or nil if not found.
    static func pattern(for character: Character) -> String? {
        encoding[Character(character.uppercased())]
    }

    /// Decodes a Morse pattern to a character, or nil if invalid.
    static func character(for pattern: String) -> Character? {
        decoding[pattern]
    }

    /// Timing at 20 WPM character speed
    enum Timing {
        /// Duration of one dit (basic unit) at 20 WPM: 60ms
        static let ditDuration: TimeInterval = 0.060

        /// Duration of one dah (3 dits): 180ms
        static let dahDuration: TimeInterval = 0.180

        /// Gap between elements within a character (1 dit): 60ms
        static let elementGap: TimeInterval = 0.060

        /// Standard inter-character gap (3 dits): 180ms
        static let standardCharacterGap: TimeInterval = 0.180

        /// Standard inter-word gap (7 dits): 420ms
        static let standardWordGap: TimeInterval = 0.420

        /// Calculate Farnsworth-adjusted character gap.
        /// Character speed stays at 20 WPM, but gaps are extended.
        /// - Parameter effectiveWPM: Target overall speed (10-18 WPM)
        /// - Returns: Adjusted inter-character gap in seconds
        static func farnsworthCharacterGap(effectiveWPM: Int) -> TimeInterval {
            let charWPM: Double = 20
            let effWPM = Double(max(10, min(18, effectiveWPM)))
            // Farnsworth formula: extra time = (50/effWPM - 50/charWPM) * 60 / 19
            let extraTime = (50.0 / effWPM - 50.0 / charWPM) * 60.0 / 19.0
            return standardCharacterGap + extraTime * 3.0 / 19.0
        }

        /// Calculate Farnsworth-adjusted word gap.
        /// - Parameter effectiveWPM: Target overall speed (10-18 WPM)
        /// - Returns: Adjusted inter-word gap in seconds
        static func farnsworthWordGap(effectiveWPM: Int) -> TimeInterval {
            let charWPM: Double = 20
            let effWPM = Double(max(10, min(18, effectiveWPM)))
            let extraTime = (50.0 / effWPM - 50.0 / charWPM) * 60.0 / 19.0
            return standardWordGap + extraTime * 7.0 / 19.0
        }
    }
}
