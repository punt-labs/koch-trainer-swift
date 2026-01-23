import Foundation

/// Factory for creating audio engines.
/// Returns a silent engine during UI testing, real engine otherwise.
enum AudioEngineFactory {

    /// Create an appropriate audio engine based on the runtime context.
    @MainActor
    static func makeEngine() -> any AudioEngineProtocol {
        if UITestingConfiguration.isUITesting {
            return UITestAudioEngine()
        }
        return MorseAudioEngine()
    }
}
