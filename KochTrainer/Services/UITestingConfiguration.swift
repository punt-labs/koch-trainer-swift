import Foundation

/// Configuration for UI testing mode.
/// Detects `--uitesting` launch argument.
enum UITestingConfiguration {

    /// Whether the app is running in UI testing mode.
    static let isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("--uitesting")
}
