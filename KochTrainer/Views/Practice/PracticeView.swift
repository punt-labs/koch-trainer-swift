import SwiftUI

/// View for custom character practice with selectable character grid.
struct PracticeView: View {

    // MARK: Internal

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Text("Custom Practice")
                    .font(Typography.largeTitle)

                Text("Select characters to practice")
                    .font(Typography.body)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(AccessibilityID.Practice.instructionText)

                CharacterGridView(
                    selectedCharacters: $selectedCharacters,
                    characterStats: progressStore.progress.characterStats,
                    onCharacterSelected: playCharacter
                )
                .accessibilityIdentifier(AccessibilityID.Practice.characterGrid)

                HStack(spacing: Theme.Spacing.md) {
                    NavigationLink(destination: ReceiveTrainingView(customCharacters: Array(selectedCharacters))) {
                        HStack {
                            Image(systemName: "ear")
                            Text("Receive")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedCharacters.count < 2)
                    .accessibilityIdentifier(AccessibilityID.Practice.receiveButton)

                    NavigationLink(destination: SendTrainingView(customCharacters: Array(selectedCharacters))) {
                        HStack {
                            Image(systemName: "hand.tap")
                            Text("Send")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedCharacters.count < 2)
                    .accessibilityIdentifier(AccessibilityID.Practice.sendButton)
                }

                if selectedCharacters.count < 2 {
                    Text("Select at least 2 characters")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.Practice.view)
        .onAppear {
            audioEngineWrapper.engine.setFrequency(settingsStore.settings.toneFrequency)
            audioEngineWrapper.engine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)
            audioEngineWrapper.engine.configureBandConditions(from: settingsStore.settings)
        }
    }

    // MARK: Private

    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedCharacters: Set<Character> = []
    @StateObject private var audioEngineWrapper = ObservableAudioEngine()

    private func playCharacter(_ character: Character) {
        Task {
            await audioEngineWrapper.engine.playCharacter(character)
        }
    }
}

#Preview {
    NavigationStack {
        PracticeView()
            .environmentObject(ProgressStore())
            .environmentObject(SettingsStore())
    }
}
