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

    // MARK: Internal

    @ObservedObject var viewModel: ViewModel

    let trainingType: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Character \(viewModel.introProgress)")
                .font(Typography.body)
                .foregroundColor(.secondary)
                .accessibilityLabel("Introducing character \(viewModel.introProgress)")
                .accessibilityIdentifier(AccessibilityID.Training.introProgress)

            Spacer()

            if let char = viewModel.currentIntroCharacter {
                Text(String(char))
                    .font(Typography.characterDisplay(size: characterSize))
                    .foregroundColor(Theme.Colors.primary)
                    .accessibilityIdentifier(AccessibilityID.Training.introCharacter)

                Text(MorseCode.pattern(for: char) ?? "")
                    .font(Typography.patternDisplay(size: patternSize))
                    .foregroundColor(.secondary)
                    .accessibilityLabel(AccessibilityAnnouncer.spokenPattern(MorseCode.pattern(for: char) ?? ""))
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
                .accessibilityHint("Plays the Morse code pattern for this character")
                .accessibilityIdentifier(AccessibilityID.Training.playSoundButton)

                Button {
                    viewModel.nextIntroCharacter()
                } label: {
                    Text(viewModel.isLastIntroCharacter ? "Start \(trainingType)" : "Next Character")
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

    // MARK: Private

    @ScaledMetric(relativeTo: .largeTitle) private var characterSize: CGFloat = 120
    @ScaledMetric(relativeTo: .title) private var patternSize: CGFloat = 36

}
