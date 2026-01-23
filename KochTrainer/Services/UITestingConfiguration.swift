import Foundation

/// Configuration for UI testing mode.
/// Detects `--uitesting` launch argument and provides test-specific settings.
enum UITestingConfiguration {

    /// Environment variable keys for test configuration.
    enum EnvironmentKey {
        /// Initial receive level (1-26)
        static let receiveLevel = "UITEST_RECEIVE_LEVEL"
        /// Initial send level (1-26)
        static let sendLevel = "UITEST_SEND_LEVEL"
        /// Initial ear training level (1-5)
        static let earLevel = "UITEST_EAR_LEVEL"
    }

    /// Whether the app is running in UI testing mode.
    static let isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("--uitesting")

    /// Get an integer value from environment, or nil if not set.
    static func environmentInt(_ key: String) -> Int? {
        guard let value = ProcessInfo.processInfo.environment[key] else { return nil }
        return Int(value)
    }
}
