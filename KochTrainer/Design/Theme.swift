import SwiftUI

/// Design system colors and spacing constants.
enum Theme {
    enum Colors {
        /// Primary accent color - adapts to light/dark mode
        static let primary = Color.accentColor

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
        static let large: CGFloat = 12
    }
}
