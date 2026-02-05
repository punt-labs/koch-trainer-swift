import Foundation
import QuartzCore

// MARK: - PaddleInput

/// Paddle input state.
struct PaddleInput: Equatable, Sendable {
    var ditPressed: Bool = false
    var dahPressed: Bool = false

    /// Whether any paddle is pressed.
    var isPressed: Bool {
        ditPressed || dahPressed
    }

    /// Whether both paddles are pressed (squeeze).
    var isSqueeze: Bool {
        ditPressed && dahPressed
    }
}

// MARK: - KeyerPhase

/// Keyer phase state machine.
///
/// State transitions:
/// - `idle` → `playing`: paddle pressed
/// - `playing` → `gap`: element duration elapsed
/// - `gap` → `playing`: gap elapsed and paddle held
/// - `gap` → `idle`: gap elapsed and no paddle held (emits pattern)
///
/// Mode B: element always completes before stopping.
enum KeyerPhase: Equatable, Sendable {
    /// Waiting for input, no tone active.
    case idle

    /// Playing an element, tone active.
    case playing(element: MorseElement)

    /// Inter-element gap, tone inactive.
    case gap
}

// MARK: - IambicKeyer

/// Iambic Mode B keyer with CADisplayLink timing.
///
/// Key invariant (Z spec): `toneActive = true ⟺ phase = playing`
///
/// Usage:
/// 1. Create keyer with configuration and callbacks
/// 2. Call `start()` to begin timing loop
/// 3. Call `updatePaddle(_:)` when paddle state changes
/// 4. Keyer calls `onToneStart`/`onToneStop` for audio
/// 5. Keyer calls `onPatternComplete` when character boundary detected
/// 6. Call `stop()` when done
final class IambicKeyer {

    // MARK: Lifecycle

    /// Create an iambic keyer.
    /// - Parameters:
    ///   - configuration: Timing and audio configuration.
    ///   - clock: Clock for time measurement (inject MockClock for testing).
    ///   - onToneStart: Called when tone should start (with frequency).
    ///   - onToneStop: Called when tone should stop.
    ///   - onPatternComplete: Called when character pattern is complete.
    ///   - onHaptic: Called for haptic feedback (dit or dah).
    init(
        configuration: KeyerConfiguration = KeyerConfiguration(),
        clock: KeyerClock = RealClock(),
        onToneStart: @escaping (Double) -> Void = { _ in },
        onToneStop: @escaping () -> Void = {},
        onPatternComplete: @escaping (String) -> Void = { _ in },
        onHaptic: @escaping (MorseElement) -> Void = { _ in }
    ) {
        self.configuration = configuration
        self.clock = clock
        self.onToneStart = onToneStart
        self.onToneStop = onToneStop
        self.onPatternComplete = onPatternComplete
        self.onHaptic = onHaptic
    }

    deinit {
        stop()
    }

    // MARK: Internal

    /// Current keyer phase (read-only).
    private(set) var phase: KeyerPhase = .idle

    /// Current paddle input state (read-only).
    private(set) var paddle: PaddleInput = .init()

    /// Current pattern being built.
    private(set) var currentPattern: String = ""

    /// Keyer configuration.
    var configuration: KeyerConfiguration

    /// Start the keyer timing loop.
    func start() {
        guard displayLink == nil else { return }

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTickTime = clock.now()
    }

    /// Stop the keyer timing loop.
    func stop() {
        displayLink?.invalidate()
        displayLink = nil

        // Clean up state
        if case .playing = phase {
            onToneStop()
        }
        phase = .idle
        paddle = PaddleInput()
        currentPattern = ""
        lastElement = nil
        pendingElements.removeAll()
    }

    /// Clear pending input without stopping the keyer.
    /// Call this when starting a new character to prevent queued elements
    /// from carrying over.
    func clearPendingInput() {
        pendingElements.removeAll()
        currentPattern = ""
        lastElement = nil
    }

    /// Update paddle input state.
    /// - Parameter input: New paddle state.
    func updatePaddle(_ input: PaddleInput) {
        let oldPaddle = paddle
        paddle = input

        // If we're idle and paddle just pressed, start immediately
        if case .idle = phase, !oldPaddle.isPressed, input.isPressed {
            startElement()
        }
    }

    /// Queue a discrete element for playback.
    /// Use this for keyboard input where quick taps should each produce one element.
    /// - Parameter element: The element to queue (.dit or .dah)
    func queueElement(_ element: MorseElement) {
        pendingElements.append(element)

        // If idle, start immediately
        if case .idle = phase {
            startNextQueuedElement()
        }
    }

    /// Process a single tick of the keyer (called from display link or tests).
    /// - Parameter now: Current timestamp.
    func processTick(at now: TimeInterval) {
        switch phase {
        case .idle:
            processIdlePhase(at: now)

        case let .playing(element):
            processPlayingPhase(element: element, at: now)

        case .gap:
            processGapPhase(at: now)
        }

        lastTickTime = now
    }

    // MARK: Private

    private let clock: KeyerClock
    private let onToneStart: (Double) -> Void
    private let onToneStop: () -> Void
    private let onPatternComplete: (String) -> Void
    private let onHaptic: (MorseElement) -> Void

    private var displayLink: CADisplayLink?
    private var lastTickTime: TimeInterval = 0
    private var phaseStartTime: TimeInterval = 0
    private var idleStartTime: TimeInterval = 0
    private var lastElement: MorseElement?
    private var pendingElements: [MorseElement] = []

    @objc
    private func tick() {
        processTick(at: clock.now())
    }

    // MARK: - Phase Processing

    private func processIdlePhase(at now: TimeInterval) {
        // Check for pattern timeout if we have accumulated pattern
        // Only emit if no queued elements waiting (user may still be typing)
        if !currentPattern.isEmpty, pendingElements.isEmpty {
            let idleElapsed = now - idleStartTime
            if idleElapsed >= configuration.idleTimeout {
                emitPattern()
            }
        }

        // Start element if paddle pressed or queued
        if paddle.isPressed {
            startElement()
        } else if !pendingElements.isEmpty {
            startNextQueuedElement()
        }
    }

    private func processPlayingPhase(element: MorseElement, at now: TimeInterval) {
        let elapsed = now - phaseStartTime
        let duration = element == .dit ? configuration.ditDuration : configuration.dahDuration

        // Mode B: element always completes
        if elapsed >= duration {
            // Element complete, transition to gap
            onToneStop()
            phase = .gap
            phaseStartTime = now
        }
    }

    private func processGapPhase(at now: TimeInterval) {
        let elapsed = now - phaseStartTime

        // Gap must complete before next element
        if elapsed >= configuration.elementGap {
            if paddle.isPressed {
                // Continue with next element (iambic paddle mode)
                startElement()
            } else if !pendingElements.isEmpty {
                // Play queued element (discrete input mode)
                startNextQueuedElement()
            } else {
                // No paddle pressed and no queued elements, go to idle
                phase = .idle
                idleStartTime = now
            }
        }
    }

    private func startNextQueuedElement() {
        guard !pendingElements.isEmpty else { return }
        let element = pendingElements.removeFirst()
        startElement(element)
    }

    // MARK: - Element Control

    private func startElement(_ element: MorseElement? = nil) {
        let elementToPlay = element ?? selectNextElement()
        phase = .playing(element: elementToPlay)
        phaseStartTime = clock.now()
        lastElement = elementToPlay

        // Append to pattern
        currentPattern.append(elementToPlay.patternCharacter)

        // Start tone
        onToneStart(configuration.frequency)

        // Haptic feedback
        if configuration.hapticEnabled {
            onHaptic(elementToPlay)
        }
    }

    private func selectNextElement() -> MorseElement {
        // Squeeze: alternate from last element
        if paddle.isSqueeze {
            if let last = lastElement {
                return last == .dit ? .dah : .dit
            }
            // First element in squeeze defaults to dit
            return .dit
        }

        // Single paddle: use that paddle
        if paddle.ditPressed {
            return .dit
        }
        if paddle.dahPressed {
            return .dah
        }

        // Fallback (shouldn't happen): dit
        return .dit
    }

    private func emitPattern() {
        guard !currentPattern.isEmpty else { return }
        let pattern = currentPattern
        currentPattern = ""
        lastElement = nil
        onPatternComplete(pattern)
    }

}
