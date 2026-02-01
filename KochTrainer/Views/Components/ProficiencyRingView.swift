import SwiftUI

// MARK: - ProficiencyRing

/// Displays a circular progress ring overlay to indicate proficiency level.
/// Draws on top of existing content - use in a ZStack.
struct ProficiencyRing: View {

    // MARK: Lifecycle

    init(proficiency: Double, lineWidth: CGFloat = 4) {
        self.proficiency = max(0, min(1, proficiency))
        self.lineWidth = lineWidth
    }

    // MARK: Internal

    var body: some View {
        Circle()
            .trim(from: 0, to: proficiency)
            .stroke(
                ringColor,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .accessibilityHidden(true) // Decorative; proficiency announced via parent label
    }

    // MARK: Private

    private let proficiency: Double
    private let lineWidth: CGFloat

    private var ringColor: Color {
        if proficiency < 0.5 {
            return Color.orange
        } else if proficiency < 0.8 {
            return Color.yellow
        } else {
            return Theme.Colors.success
        }
    }
}

#Preview("High Proficiency") {
    ZStack {
        Circle()
            .fill(Color.gray.opacity(0.2))
        Text("K")
            .font(.title)
        ProficiencyRing(proficiency: 0.95)
    }
    .frame(width: 60, height: 60)
}

#Preview("Medium Proficiency") {
    ZStack {
        Circle()
            .fill(Color.gray.opacity(0.2))
        Text("M")
            .font(.title)
        ProficiencyRing(proficiency: 0.65)
    }
    .frame(width: 60, height: 60)
}

#Preview("Low Proficiency") {
    ZStack {
        Circle()
            .fill(Color.gray.opacity(0.2))
        Text("R")
            .font(.title)
        ProficiencyRing(proficiency: 0.30)
    }
    .frame(width: 60, height: 60)
}

#Preview("No Ring") {
    ZStack {
        Circle()
            .fill(Color.gray.opacity(0.2))
        Text("S")
            .font(.title)
    }
    .frame(width: 60, height: 60)
}
