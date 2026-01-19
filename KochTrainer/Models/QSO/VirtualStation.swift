import Foundation

// MARK: - VirtualStation

/// Represents an AI-controlled virtual ham radio station
struct VirtualStation: Codable, Equatable {

    // MARK: Lifecycle

    init(callsign: String, name: String, qth: String, rig: String = "100W", serialNumber: Int = 1) {
        self.callsign = callsign.uppercased()
        self.name = name.uppercased()
        self.qth = qth.uppercased()
        self.rig = rig.uppercased()
        self.serialNumber = serialNumber
    }

    // MARK: Internal

    let callsign: String
    let name: String
    let qth: String // Location (city, state/country)
    let rig: String // Equipment description
    let serialNumber: Int // Contest serial number

    /// Generate a random RST (Readability, Strength, Tone) report
    /// Typical contest reports are 599, but we vary slightly for realism
    var randomRST: String {
        let readabilityOptions = [5, 5, 5, 5, 4]
        let strengthOptions = [9, 9, 9, 8, 7]
        let readability = readabilityOptions[Int.random(in: 0 ..< readabilityOptions.count)]
        let strength = strengthOptions[Int.random(in: 0 ..< strengthOptions.count)]
        return "\(readability)\(strength)9"
    }

    /// Format serial number for contest exchange (3 digits, padded)
    var formattedSerialNumber: String {
        String(format: "%03d", serialNumber)
    }
}

// MARK: - Random Station Generation

extension VirtualStation {
    /// Generate a random virtual station
    static func random(serialNumber: Int = Int.random(in: 1 ... 500)) -> VirtualStation {
        let callsign = CallsignGenerator.random()
        let name = randomName()
        let qth = randomQTH()
        let rig = randomRig()

        return VirtualStation(
            callsign: callsign,
            name: name,
            qth: qth,
            rig: rig,
            serialNumber: serialNumber
        )
    }

    private static func randomName() -> String {
        let names = [
            "JACK", "MIKE", "BOB", "JIM", "TOM", "BILL", "JOHN", "DAVE",
            "STEVE", "RICK", "GARY", "PAUL", "DAN", "RON", "KEN", "DON",
            "ED", "PHIL", "MARK", "JEFF", "TONY", "AL", "JOE", "PETE",
            "SAM", "RAY", "LEE", "ART", "HAL", "VIC", "WALT", "FRED"
        ]
        return names[Int.random(in: 0 ..< names.count)]
    }

    private static func randomQTH() -> String {
        let locations = [
            "AUSTIN TX", "DENVER CO", "PORTLAND OR", "SEATTLE WA",
            "ATLANTA GA", "BOSTON MA", "CHICAGO IL", "DALLAS TX",
            "HOUSTON TX", "MIAMI FL", "NEW YORK NY", "PHOENIX AZ",
            "SAN DIEGO CA", "SAN JOSE CA", "DETROIT MI", "COLUMBUS OH",
            "PITTSBURGH PA", "CLEVELAND OH", "TAMPA FL", "RALEIGH NC",
            "TUCSON AZ", "OMAHA NE", "TULSA OK", "FRESNO CA",
            "SACRAMENTO CA", "KANSAS CITY MO", "MILWAUKEE WI", "MEMPHIS TN"
        ]
        return locations[Int.random(in: 0 ..< locations.count)]
    }

    private static func randomRig() -> String {
        let rigs = [
            "100W", "50W", "5W QRP", "ICOM 7300", "YAESU FT991",
            "KENWOOD TS590", "ELECRAFT K3", "FLEX 6600", "100W DIPOLE",
            "KW AMP", "QRP 5W", "HOMEBREW", "PORTABLE"
        ]
        return rigs[Int.random(in: 0 ..< rigs.count)]
    }
}

// MARK: - Preset Stations

extension VirtualStation {
    /// Famous/notable stations for variety
    static let presets: [VirtualStation] = [
        VirtualStation(callsign: "W1AW", name: "ARRL HQ", qth: "NEWINGTON CT", rig: "BEAM ANT"),
        VirtualStation(callsign: "K3LR", name: "TIM", qth: "WEST MIDDLESEX PA", rig: "CONTEST STN"),
        VirtualStation(callsign: "N1MM", name: "TOM", qth: "CONNECTICUT", rig: "N1MM LOGGER"),
        VirtualStation(callsign: "W3LPL", name: "FRANK", qth: "GLENWOOD MD", rig: "BIG GUN"),
        VirtualStation(callsign: "K1TTT", name: "DAVE", qth: "BARRE MA", rig: "CONTEST STN")
    ]

    /// Get a random station (80% chance random, 20% chance preset)
    static func randomOrPreset() -> VirtualStation {
        if Double.random(in: 0 ... 1) < 0.2, let preset = presets.randomElement() {
            return VirtualStation(
                callsign: preset.callsign,
                name: preset.name,
                qth: preset.qth,
                rig: preset.rig,
                serialNumber: Int.random(in: 1 ... 500)
            )
        }
        return random()
    }
}
