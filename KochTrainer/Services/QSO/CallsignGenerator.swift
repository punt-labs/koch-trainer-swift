import Foundation

/// Generates realistic amateur radio callsigns
struct CallsignGenerator {

    /// Generate a random callsign (weighted toward US calls)
    static func random() -> String {
        let roll = Double.random(in: 0...1)
        if roll < 0.7 {
            return randomUS()
        } else if roll < 0.85 {
            return randomEU()
        } else {
            return randomVE()
        }
    }

    // MARK: - US Callsigns

    /// Generate a random US callsign
    /// Format: prefix + digit + suffix
    /// - W, K, N are most common single-letter prefixes
    /// - Two-letter prefixes: AA-AL, KA-KZ, WA-WZ, NA-NZ
    static func randomUS() -> String {
        let prefix = randomUSPrefix()
        let digit = Int.random(in: 0...9)
        let suffix = randomSuffix(length: Int.random(in: 1...3))

        return "\(prefix)\(digit)\(suffix)"
    }

    private static func randomUSPrefix() -> String {
        let roll = Double.random(in: 0...1)

        if roll < 0.6 {
            // Single letter prefix (most common)
            let prefixes = ["W", "K", "N"]
            return prefixes[Int.random(in: 0..<prefixes.count)]
        } else {
            // Two letter prefix
            let firstLetters = ["A", "K", "W", "N"]
            let firstLetter = firstLetters[Int.random(in: 0..<firstLetters.count)]
            let secondLetter = randomLetter()
            return "\(firstLetter)\(secondLetter)"
        }
    }

    // MARK: - European Callsigns

    /// Generate a random European callsign
    static func randomEU() -> String {
        let prefixes = ["DL", "G", "F", "I", "EA", "PA", "ON", "OE", "HB9", "SP", "OK", "OM"]
        let prefix = prefixes[Int.random(in: 0..<prefixes.count)]
        let digit = Int.random(in: 1...9)
        let suffix = randomSuffix(length: Int.random(in: 2...3))

        return "\(prefix)\(digit)\(suffix)"
    }

    // MARK: - Canadian Callsigns

    /// Generate a random Canadian (VE) callsign
    static func randomVE() -> String {
        let prefixes = ["VE", "VA", "VY"]
        let prefix = prefixes[Int.random(in: 0..<prefixes.count)]
        let digit = Int.random(in: 1...9)
        let suffix = randomSuffix(length: Int.random(in: 2...3))

        return "\(prefix)\(digit)\(suffix)"
    }

    // MARK: - Helpers

    private static func randomSuffix(length: Int) -> String {
        var suffix = ""
        for _ in 0..<length {
            suffix += randomLetter()
        }
        return suffix
    }

    private static func randomLetter() -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return String(letters[Int.random(in: 0..<letters.count)])
    }

    /// Validate if a callsign looks reasonable
    static func isValid(_ callsign: String) -> Bool {
        let cleaned = callsign.uppercased().trimmingCharacters(in: .whitespaces)

        // Must be 3-7 characters
        guard cleaned.count >= 3 && cleaned.count <= 7 else { return false }

        // Must contain at least one letter and one digit
        let hasLetter = cleaned.contains { $0.isLetter }
        let hasDigit = cleaned.contains { $0.isNumber }

        return hasLetter && hasDigit
    }
}
