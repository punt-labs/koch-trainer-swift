@testable import KochTrainer

/// Shared radio state manager for test mocks.
/// Provides consistent radio control behavior across all mock implementations.
final class MockRadioState {
    private(set) var mode: RadioMode = .off

    func startReceiving() throws {
        guard mode == .off else {
            throw Radio.RadioError.mustBeOff(current: mode)
        }
        mode = .receiving
    }

    func startTransmitting() throws {
        guard mode == .off else {
            throw Radio.RadioError.mustBeOff(current: mode)
        }
        mode = .transmitting
    }

    func stopRadio() throws {
        guard mode != .off else {
            throw Radio.RadioError.alreadyOff
        }
        mode = .off
    }

    func startSession() {
        mode = .receiving
    }

    func endSession() {
        mode = .off
    }
}
