import SwiftUI

// MARK: - WhatsNewView

/// Displays the app's changelog/release notes.
struct WhatsNewView: View {

    // MARK: Internal

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Current version highlights
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label("Version \(appVersion)", systemImage: "app.badge")
                        .font(Typography.headline)

                    Text("Koch Trainer for iOS")
                        .font(Typography.body)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Features list
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    FeatureRow(
                        icon: "ear",
                        title: "Ear Training",
                        description: "whatsnew.ear.description"
                    )

                    FeatureRow(
                        icon: "waveform",
                        title: "Receive Training",
                        description: "whatsnew.receive.description"
                    )

                    FeatureRow(
                        icon: "hand.tap",
                        title: "Send Training",
                        description: "whatsnew.send.description"
                    )

                    FeatureRow(
                        icon: "character.textbox",
                        title: "Koch Method",
                        description: "whatsnew.koch.description"
                    )

                    FeatureRow(
                        icon: "text.word.spacing",
                        title: "Vocabulary Practice",
                        description: "whatsnew.vocab.description"
                    )

                    FeatureRow(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "QSO Simulation",
                        description: "whatsnew.qso.description"
                    )

                    FeatureRow(
                        icon: "waveform",
                        title: "Band Conditions",
                        description: "whatsnew.band.description"
                    )

                    FeatureRow(
                        icon: "flame",
                        title: "Streak Tracking",
                        description: "whatsnew.streak.description"
                    )

                    FeatureRow(
                        icon: "circle.dotted",
                        title: "Proficiency Indicators",
                        description: "whatsnew.proficiency.description"
                    )
                }

                Divider()

                // Link to full changelog
                if let url = URL(string: "https://github.com/punt-labs/koch-trainer-swift/blob/main/CHANGELOG.md") {
                    Link(destination: url) {
                        Label("View Full Changelog", systemImage: "arrow.up.right.square")
                    }
                    .font(Typography.body)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Private

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.body)
                Text(description)
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WhatsNewView()
    }
}
