import Foundation

/// Half-duplex radio mode for training sessions.
///
/// Amateur radio is half-duplex: the operator either receives (listens to incoming
/// signals) or transmits (sends outgoing signals), but not both simultaneously.
///
/// From Z specification (docs/koch_trainer.tex):
/// ```
/// RadioMode ::= off | receiving | transmitting
/// ```
///
/// Constraints:
/// - Non-training phases (introduction, paused, completed) → off
/// - Receive training → always receiving
/// - Send training → receiving (waiting) or transmitting (keying)
/// - transmitting requires direction = send
enum RadioMode: Equatable, Sendable {
    /// Radio not active (session not started, paused, or completed)
    case off

    /// Radio on, listening: continuous noise floor with band conditions (QRN, QSB, QRM),
    /// incoming Morse signals audible
    case receiving

    /// Radio on, sending: sidetone only, receiver muted (no noise or band conditions)
    case transmitting
}
