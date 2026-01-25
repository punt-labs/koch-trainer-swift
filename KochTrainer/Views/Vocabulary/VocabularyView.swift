import SwiftUI

/// View for vocabulary (word/callsign) practice.
struct VocabularyView: View {

    // MARK: Internal

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
                    descriptionAccessibilityLabel: nil,
                    set: VocabularySet.commonWords,
                    receiveId: AccessibilityID.Vocab.commonWordsReceiveButton,
                    sendId: AccessibilityID.Vocab.commonWordsSendButton
                )

                vocabularySetRow(
                    name: "Callsign Patterns",
                    description: "W1AW, K0ABC, VE3XYZ...",
                    descriptionAccessibilityLabel: "W 1 A W, K 0 A B C, V E 3 X Y Z, and more",
                    set: VocabularySet.callsignPatterns,
                    receiveId: AccessibilityID.Vocab.callsignReceiveButton,
                    sendId: AccessibilityID.Vocab.callsignSendButton
                )
            }

            // QSO Simulation (advanced)
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Text("QSO Simulation")
                        .font(Typography.headline)
                    Spacer()
                    Text("Advanced")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                }

                NavigationLink(destination: QSOView()) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Start QSO Practice")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.Vocab.qsoButton)

                Text("Practice realistic ham radio conversations")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)
            .accessibilityElement(children: .contain)

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .navigationTitle("Vocabulary")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Vocab.view)
    }

    // MARK: Private

    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore

    private var callsignCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("Your Callsign")
                    .font(Typography.headline)
                Spacer()
                Text(settingsStore.settings.userCallsign)
                    .font(Typography.body)
                    .foregroundColor(.secondary)
                    .accessibilityLabel(spellOut(settingsStore.settings.userCallsign))
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

    private func vocabularySetRow(
        name: String,
        description: String,
        descriptionAccessibilityLabel: String?,
        set: VocabularySet,
        receiveId: String,
        sendId: String
    ) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(Typography.headline)
                    Text(description)
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(descriptionAccessibilityLabel ?? description)
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
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(receiveId)

                NavigationLink(destination: VocabularyTrainingView(vocabularySet: set, sessionType: .send)) {
                    HStack {
                        Image(systemName: "hand.tap")
                        Text("Send")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(sendId)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
    }

    private func spellOut(_ text: String) -> String {
        text.map { String($0) }.joined(separator: " ")
    }

}

#Preview {
    NavigationStack {
        VocabularyView()
            .environmentObject(ProgressStore())
            .environmentObject(SettingsStore())
    }
}
