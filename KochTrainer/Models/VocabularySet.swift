import Foundation

/// A collection of words for vocabulary practice.
struct VocabularySet: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var words: [String]
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, words: [String], isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.words = words.map { $0.uppercased() }
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - Built-in Sets

extension VocabularySet {
    /// Common QSO words and prosigns used in amateur radio
    static let commonWords = VocabularySet(
        name: "Common Words",
        words: [
            "CQ",     // Calling any station
            "DE",     // From (this is)
            "K",      // Over (invitation to transmit)
            "AR",     // End of message
            "SK",     // End of contact
            "73",     // Best regards
            "88",     // Love and kisses
            "RST",    // Signal report
            "QTH",    // Location
            "QSL",    // Acknowledge
            "QRZ",    // Who is calling?
            "QSO",    // Contact
            "QRM",    // Interference
            "QRN",    // Static noise
            "QSB",    // Fading
            "QRP",    // Low power
            "QRT",    // Stop transmitting
            "QRX",    // Wait
            "UR",     // Your
            "FB",     // Fine business (good)
            "OM",     // Old man (male operator)
            "YL",     // Young lady (female operator)
            "XYL",    // Wife
            "ANT",    // Antenna
            "RIG",    // Radio equipment
            "WX",     // Weather
            "ES",     // And
            "TNX",    // Thanks
            "PSE",    // Please
            "AGN",    // Again
            "CFM",    // Confirm
            "RPT",    // Repeat
            "BK",     // Break
            "BTU",    // Back to you
            "CUL",    // See you later
            "HW",     // How
            "NR",     // Number
            "PWR",    // Power
            "SIG",    // Signal
            "TEST"    // Contest exchange
        ],
        isBuiltIn: true
    )

    /// Sample callsign patterns for practice
    static let callsignPatterns = VocabularySet(
        name: "Callsign Patterns",
        words: [
            // US callsigns
            "W1AW",   // ARRL headquarters
            "K0ABC",
            "N5XYZ",
            "WA3DEF",
            "KC2GHI",
            "KD7JKL",
            "W9MNO",
            "K4PQR",
            "N6STU",
            "W2VWX",
            // Canadian callsigns
            "VE3ABC",
            "VA7DEF",
            "VE1GHI",
            // European callsigns
            "G4ABC",   // UK
            "DL1DEF",  // Germany
            "F5GHI",   // France
            "I0JKL",   // Italy
            "ON4MNO",  // Belgium
            "PA3PQR",  // Netherlands
            // Other regions
            "JA1ABC",  // Japan
            "VK2DEF",  // Australia
            "ZL3GHI",  // New Zealand
            "ZS6JKL"   // South Africa
        ],
        isBuiltIn: true
    )

    /// Create a vocabulary set for practicing a single callsign
    static func userCallsign(_ callsign: String) -> VocabularySet {
        VocabularySet(
            name: "Your Callsign",
            words: [callsign],
            isBuiltIn: false
        )
    }
}
