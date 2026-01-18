import SwiftUI

/// View for vocabulary (word/callsign) practice.
struct VocabularyView: View {
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Vocabulary")
                .font(Typography.largeTitle)

            // User's callsign shortcut (if set)
            if !settingsStore.settings.userCallsign.isEmpty {
                callsignCard
            }

            // Built-in vocabulary sets
            VStack(spacing: Theme.Spacing.md) {
                vocabularySetRow(
                    name: "Common Words",
                    description: "CQ, DE, K, AR, SK, 73, QTH, QSL...",
                    set: VocabularySet.commonWords
                )

                vocabularySetRow(
                    name: "Callsign Patterns",
                    description: "W1AW, K0ABC, VE3XYZ...",
                    set: VocabularySet.callsignPatterns
                )
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .navigationTitle("Vocabulary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var callsignCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("Your Callsign")
                    .font(Typography.headline)
                Spacer()
                Text(settingsStore.settings.userCallsign)
                    .font(Typography.body)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: Theme.Spacing.md) {
                NavigationLink(destination: VocabularyTrainingView(
                    vocabularySet: VocabularySet.userCallsign(settingsStore.settings.userCallsign),
                    sessionType: .receive
                )) {
                    HStack {
                        Image(systemName: "ear")
                        Text("Receive")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                NavigationLink(destination: VocabularyTrainingView(
                    vocabularySet: VocabularySet.userCallsign(settingsStore.settings.userCallsign),
                    sessionType: .send
                )) {
                    HStack {
                        Image(systemName: "hand.tap")
                        Text("Send")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(12)
    }

    private func vocabularySetRow(name: String, description: String, set: VocabularySet) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(Typography.headline)
                    Text(description)
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            HStack(spacing: Theme.Spacing.md) {
                NavigationLink(destination: VocabularyTrainingView(vocabularySet: set, sessionType: .receive)) {
                    HStack {
                        Image(systemName: "ear")
                        Text("Receive")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                NavigationLink(destination: VocabularyTrainingView(vocabularySet: set, sessionType: .send)) {
                    HStack {
                        Image(systemName: "hand.tap")
                        Text("Send")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        VocabularyView()
            .environmentObject(ProgressStore())
            .environmentObject(SettingsStore())
    }
}
