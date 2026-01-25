import Foundation

/// Half-duplex radio state machine per Z specification.
///
/// Enforces the following invariants via throwing methods:
/// - `¬(mode = receiving ∧ isKeying)` — can only key while transmitting
/// - `¬(mode = off ∧ isKeying)` — can only key while transmitting
/// - Mode transitions require `mode = off` (must stop before switching)
///
/// From Z specification (docs/koch_trainer.tex):
/// ```
/// RadioMode ::= off | receiving | transmitting
/// ¬(radioMode = receiving ∧ toneActive)
/// ¬(radioMode = off ∧ toneActive)
/// ```
///
/// Thread-safe: uses internal locking for audio callback access.
///
/// NOTE: `Radio` is declared `@unchecked Sendable` instead of being modeled
/// as an `actor` because it is read from real-time audio render callbacks
/// where async actor isolation is not permitted. All mutable state (`_mode`,
/// `_isKeying`) is value-typed and accessed only while holding `lock`.
final class Radio: @unchecked Sendable {

    // MARK: Internal

    /// Error thrown when attempting invalid state transitions.
    enum RadioError: Error, Equatable {
        /// Mode transition requires radio to be off first
        case mustBeOff(current: RadioMode)

        /// Keying requires transmitting mode
        case mustBeTransmitting(current: RadioMode)

        /// Cannot stop radio that is already off
        case alreadyOff
    }

    /// Current radio mode (thread-safe read).
    var mode: RadioMode {
        lock.lock()
        defer { lock.unlock() }
        return _mode
    }

    /// Whether the key is currently pressed (thread-safe read).
    /// Invariant: `isKeying` implies `mode == .transmitting`.
    var isKeying: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isKeying
    }

    // MARK: - Mode Transitions

    /// Start receiving (listening for incoming signals).
    ///
    /// - Throws: `RadioError.mustBeOff` if not currently off.
    func startReceiving() throws {
        lock.lock()
        defer { lock.unlock() }
        guard _mode == .off else {
            throw RadioError.mustBeOff(current: _mode)
        }
        _mode = .receiving
    }

    /// Start transmitting (preparing to send).
    ///
    /// - Throws: `RadioError.mustBeOff` if not currently off.
    func startTransmitting() throws {
        lock.lock()
        defer { lock.unlock() }
        guard _mode == .off else {
            throw RadioError.mustBeOff(current: _mode)
        }
        _mode = .transmitting
    }

    /// Stop the radio (transition to off).
    ///
    /// Automatically clears keying state if transmitting.
    ///
    /// - Throws: `RadioError.alreadyOff` if already off.
    func stop() throws {
        lock.lock()
        defer { lock.unlock() }
        guard _mode != .off else {
            throw RadioError.alreadyOff
        }
        _isKeying = false
        _mode = .off
    }

    // MARK: - Keying (Transmit Only)

    /// Press the key (start sending tone).
    ///
    /// - Throws: `RadioError.mustBeTransmitting` if not in transmitting mode.
    func key() throws {
        lock.lock()
        defer { lock.unlock() }
        guard _mode == .transmitting else {
            throw RadioError.mustBeTransmitting(current: _mode)
        }
        _isKeying = true
    }

    /// Release the key (stop sending tone).
    ///
    /// - Throws: `RadioError.mustBeTransmitting` if not in transmitting mode.
    func unkey() throws {
        lock.lock()
        defer { lock.unlock() }
        guard _mode == .transmitting else {
            throw RadioError.mustBeTransmitting(current: _mode)
        }
        _isKeying = false
    }

    // MARK: Private

    // MARK: - Private State

    private let lock = NSLock()
    private var _mode: RadioMode = .off
    private var _isKeying: Bool = false

}
