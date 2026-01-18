import SwiftUI

struct ResultsView: View {
    let result: SessionResult
    let didLevelUp: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if didLevelUp {
                Text("🎉")
                    .font(.system(size: 80))
                Text("Level Up!")
                    .font(Typography.largeTitle)
                    .foregroundColor(Theme.Colors.success)
            } else {
                Text("Session Complete")
                    .font(Typography.largeTitle)
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
            .background(Theme.Colors.background.opacity(0.5))
            .cornerRadius(12)

            if result.accuracy >= 0.90 {
                Text("Excellent work! ≥90% accuracy achieved.")
                    .font(Typography.body)
                    .foregroundColor(Theme.Colors.success)
            } else {
                Text("Keep practicing! Need ≥90% to advance.")
                    .font(Typography.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.Spacing.lg)
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

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
