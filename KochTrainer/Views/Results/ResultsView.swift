import SwiftUI

// MARK: - ResultsView

struct ResultsView: View {

    // MARK: Internal

    let result: SessionResult
    let didLevelUp: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if didLevelUp {
                Text("🎉")
                    .font(.system(size: 80))
                    .accessibilityLabel("Celebration")
                Text("Level Up!")
                    .font(Typography.largeTitle)
                    .foregroundColor(Theme.Colors.success)
                    .accessibilityIdentifier(AccessibilityID.Results.levelUpTitle)
            } else {
                Text("Session Complete")
                    .font(Typography.largeTitle)
                    .accessibilityIdentifier(AccessibilityID.Results.sessionCompleteTitle)
            }

            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                ResultRow(label: "Type", value: result.sessionType.displayName)
                ResultRow(label: "Duration", value: result.formattedDuration)
                ResultRow(label: "Characters", value: "\(result.totalAttempts)")
                ResultRow(label: "Correct", value: "\(result.correctCount)")
                ResultRow(label: "Accuracy", value: "\(result.accuracyPercentage)%")
            }
            .padding()
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Results.statsCard)

            if result.accuracy >= 0.90 {
                Text("Excellent work! ≥90% accuracy achieved.")
                    .font(Typography.body)
                    .foregroundColor(Theme.Colors.success)
                    .accessibilityIdentifier(AccessibilityID.Results.feedbackText)
            } else {
                Text("Keep practicing! Need ≥90% to advance.")
                    .font(Typography.body)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(AccessibilityID.Results.feedbackText)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(AccessibilityID.Results.doneButton)
        }
        .padding(Theme.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Results.view)
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss

}

// MARK: - ResultRow

struct ResultRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(Typography.body)
            Spacer()
            Text(value)
                .font(Typography.headline)
        }
    }
}

#Preview {
    NavigationStack {
        ResultsView(
            result: SessionResult(
                sessionType: .receive,
                duration: 300,
                totalAttempts: 50,
                correctCount: 45,
                characterStats: [:],
                date: Date()
            ),
            didLevelUp: true
        )
    }
}
