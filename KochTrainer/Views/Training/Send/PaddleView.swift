import SwiftUI
import UIKit

// MARK: - PaddleView

/// A single paddle (dit or dah) with immediate touch response.
/// Uses UIKit for precise touch tracking without gesture recognizer delays.
struct PaddleView: View {

    /// Label displayed on the paddle.
    let label: String

    /// Color for the paddle background.
    let color: Color

    /// Called when paddle press state changes.
    let onPressChange: (Bool) -> Void

    /// Accessibility hint for the paddle.
    let accessibilityHint: String

    /// Accessibility identifier for UI tests.
    let accessibilityIdentifier: String

    var body: some View {
        TouchTrackingView(onPressChange: onPressChange)
            .background(color)
            .overlay(
                Text(label)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .allowsHitTesting(false)
            )
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(accessibilityIdentifier)
    }

}

// MARK: - TouchTrackingView

/// UIKit-backed view for immediate touch response.
/// SwiftUI gesture recognizers have minimum movement thresholds and delays;
/// this view fires callbacks immediately on touchesBegan/touchesEnded.
struct TouchTrackingView: UIViewRepresentable {

    let onPressChange: (Bool) -> Void

    func makeUIView(context: Context) -> TouchTrackingUIView {
        let view = TouchTrackingUIView()
        view.onPressChange = onPressChange
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        return view
    }

    func updateUIView(_ uiView: TouchTrackingUIView, context: Context) {
        uiView.onPressChange = onPressChange
    }

}

// MARK: - TouchTrackingUIView

/// UIView subclass that tracks touches and reports press state.
final class TouchTrackingUIView: UIView {

    // MARK: Internal

    var onPressChange: ((Bool) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.formUnion(touches)
        if activeTouches.count == touches.count {
            // First touch(es), now pressed
            onPressChange?(true)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        if activeTouches.isEmpty {
            // All touches ended, now released
            onPressChange?(false)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        if activeTouches.isEmpty {
            onPressChange?(false)
        }
    }

    // MARK: Private

    private var activeTouches: Set<UITouch> = []

}

// MARK: - DualPaddleView

/// Dual paddle view with dit (left) and dah (right).
struct DualPaddleView: View {

    /// Called when dit paddle press state changes.
    let onDitChange: (Bool) -> Void

    /// Called when dah paddle press state changes.
    let onDahChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 2) {
            PaddleView(
                label: "dit",
                color: Theme.Colors.primary.opacity(0.8),
                onPressChange: onDitChange,
                accessibilityHint: "Short Morse element",
                accessibilityIdentifier: AccessibilityID.Send.ditButton
            )

            PaddleView(
                label: "dah",
                color: Theme.Colors.primary,
                onPressChange: onDahChange,
                accessibilityHint: "Long Morse element",
                accessibilityIdentifier: AccessibilityID.Send.dahButton
            )
        }
        .frame(height: 120)
        .cornerRadius(12)
        .clipped()
    }

}

#Preview {
    VStack {
        DualPaddleView(
            onDitChange: { pressed in
                print("Dit: \(pressed ? "pressed" : "released")")
            },
            onDahChange: { pressed in
                print("Dah: \(pressed ? "pressed" : "released")")
            }
        )
        .padding()
    }
}
