import SwiftUI

// MARK: - PrimaryButtonStyle

/// Primary button style with filled background.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.lg)
            .background(Theme.Colors.primary)
            .cornerRadius(Theme.CornerRadius.large)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - SecondaryButtonStyle

/// Secondary button style with outlined border.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundColor(Theme.Colors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.lg)
            .contentShape(Rectangle())
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .stroke(Theme.Colors.primary, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - DestructiveButtonStyle

/// Destructive button style for dangerous actions.
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.lg)
            .background(Theme.Colors.error)
            .cornerRadius(Theme.CornerRadius.large)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        Button("Primary Button") {}
            .buttonStyle(PrimaryButtonStyle())

        Button("Secondary Button") {}
            .buttonStyle(SecondaryButtonStyle())

        Button("Destructive Button") {}
            .buttonStyle(DestructiveButtonStyle())
    }
    .padding()
}
