import SwiftUI

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

/// Shared character introduction view used by both receive and send training
struct CharacterIntroductionView<ViewModel: CharacterIntroducing>: View {
    @ObservedObject var viewModel: ViewModel
    let trainingType: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Character \(viewModel.introProgress)")
                .font(Typography.body)
                .foregroundColor(.secondary)

            Spacer()

            if let char = viewModel.currentIntroCharacter {
                Text(String(char))
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.primary)

                Text(MorseCode.pattern(for: char) ?? "")
                    .font(.system(size: 36, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

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

                Button {
                    viewModel.nextIntroCharacter()
                } label: {
                    Text(viewModel.isLastIntroCharacter ? "Start \(trainingType)" : "Next Character")
                        .font(Typography.headline)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, Theme.Spacing.sm)
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
    }
}
