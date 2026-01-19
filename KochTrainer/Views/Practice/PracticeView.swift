import SwiftUI

/// View for custom character practice with selectable character grid.
struct PracticeView: View {

    // MARK: Internal

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Custom Practice")
                .font(Typography.largeTitle)

            Text("Select characters to practice")
                .font(Typography.body)
                .foregroundColor(.secondary)

            CharacterGridView(
                selectedCharacters: $selectedCharacters,
                characterStats: progressStore.progress.characterStats,
                onCharacterSelected: playCharacter
            )

            Spacer()

            HStack(spacing: Theme.Spacing.md) {
                NavigationLink(destination: ReceiveTrainingView(customCharacters: Array(selectedCharacters))) {
                    HStack {
                        Image(systemName: "ear")
                        Text("Receive")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedCharacters.count < 2)

                NavigationLink(destination: SendTrainingView(customCharacters: Array(selectedCharacters))) {
                    HStack {
                        Image(systemName: "hand.tap")
                        Text("Send")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedCharacters.count < 2)
            }

            if selectedCharacters.count < 2 {
                Text("Select at least 2 characters")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Theme.Spacing.lg)
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            audioEngine.setFrequency(settingsStore.settings.toneFrequency)
            audioEngine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)
            audioEngine.configureBandConditions(from: settingsStore.settings)
        }
    }

    // MARK: Private

    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedCharacters: Set<Character> = []
    @StateObject private var audioEngine = MorseAudioEngine()

    private func playCharacter(_ character: Character) {
        Task {
            audioEngine.reset()
            await audioEngine.playCharacter(character)
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
