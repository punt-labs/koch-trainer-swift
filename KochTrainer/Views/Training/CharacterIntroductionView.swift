import SwiftUI

// MARK: - CharacterIntroducing

/// Protocol for view models that support character introduction
@MainActor
protocol CharacterIntroducing: ObservableObject {
    var introCharacters: [Character] { get }
    var currentIntroCharacter: Character? { get }
    var introProgress: String { get }
    var isLastIntroCharacter: Bool { get }

    func playCurrentIntroCharacter()
    func nextIntroCharacter()
}

// MARK: - CharacterIntroductionView

/// Shared character introduction view used by both receive and send training
struct CharacterIntroductionView<ViewModel: CharacterIntroducing>: View {
    @ObservedObject var viewModel: ViewModel

    let startButtonKey: LocalizedStringKey

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Character \(viewModel.introProgress)")
                .font(Typography.body)
                .foregroundColor(.secondary)
                .accessibilityIdentifier(AccessibilityID.Training.introProgress)

            Spacer()

            if let char = viewModel.currentIntroCharacter {
                Text(String(char))
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.primary)
                    .accessibilityIdentifier(AccessibilityID.Training.introCharacter)

                Text(MorseCode.pattern(for: char) ?? "")
                    .font(.system(size: 36, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(AccessibilityID.Training.introPattern)

                Spacer()

                Button {
                    viewModel.playCurrentIntroCharacter()
                } label: {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("Play Sound")
                    }
                    .font(Typography.headline)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.Training.playSoundButton)

                Button {
                    viewModel.nextIntroCharacter()
                } label: {
                    Text(viewModel.isLastIntroCharacter ? startButtonKey : "Next Character")
                        .font(Typography.headline)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(
                    viewModel.isLastIntroCharacter
                        ? AccessibilityID.Training.startTrainingButton
                        : AccessibilityID.Training.nextCharacterButton
                )
                .padding(.top, Theme.Spacing.sm)
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Training.introView)
    }
}
