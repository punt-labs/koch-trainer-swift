import SwiftUI

/// Design system colors and spacing constants.
enum Theme {
    enum Colors {
        /// Primary accent color - adapts to light/dark mode
        static let primary = Color.accentColor

        /// Main background - uses system grouped background for accessibility compliance
        static let background = Color(uiColor: .systemGroupedBackground)

        /// Secondary background for cards and sections - uses system color for WCAG contrast compliance
        static let secondaryBackground = Color(uiColor: .secondarySystemGroupedBackground)

        /// Success state color - adapts to light/dark mode
        static let success = Color("Success")

        /// Error state color - adapts to light/dark mode
        static let error = Color("Error")

        /// Warning state color - adapts to light/dark mode
        static let warning = Color("Warning")
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }
}
