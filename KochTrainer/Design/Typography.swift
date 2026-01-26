import SwiftUI

/// Typography definitions for consistent text styling.
enum Typography {
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title, design: .rounded, weight: .semibold)
    static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
    static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.system(.body, design: .rounded)
    static let callout = Font.system(.callout, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)

    /// Monospaced font for Morse patterns and code
    static let morse = Font.system(.title, design: .monospaced, weight: .medium)
    static let morseLarge = Font.system(.largeTitle, design: .monospaced, weight: .bold)

    // MARK: - Scalable Display Fonts

    /// Large character display (scales from specified base size)
    /// Use with @ScaledMetric for accessibility compliance
    static func characterDisplay(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    /// Pattern display (scales from specified base size)
    /// Use with @ScaledMetric for accessibility compliance
    static func patternDisplay(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}
