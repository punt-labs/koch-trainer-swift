import Foundation

// MARK: - AudioEngineFactory

/// Factory for creating audio engines.
/// Returns a silent engine during UI testing, real engine otherwise.
enum AudioEngineFactory {

    /// Create an appropriate audio engine based on the runtime context.
    @MainActor
    static func makeEngine() -> AudioEngineProtocol {
        if UITestingConfiguration.isUITesting {
            return UITestAudioEngine()
        }
        return MorseAudioEngine()
    }
}

// MARK: - ObservableAudioEngine

/// Observable wrapper for AudioEngineProtocol, enabling use with @StateObject in SwiftUI Views.
/// Uses AudioEngineFactory internally to select the appropriate engine.
@MainActor
final class ObservableAudioEngine: ObservableObject {

    // MARK: Lifecycle

    init() {
        engine = AudioEngineFactory.makeEngine()
    }

    // MARK: Internal

    /// The wrapped audio engine instance.
    let engine: AudioEngineProtocol

}
