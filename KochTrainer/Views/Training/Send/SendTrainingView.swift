import SwiftUI

struct SendTrainingView: View {
    @StateObject private var viewModel = SendTrainingViewModel()
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Timer display
            Text(viewModel.formattedTime)
                .font(Typography.largeTitle)
                .monospacedDigit()

            Spacer()

            // Target character
            Text(String(viewModel.targetCharacter))
                .font(.system(size: 120, weight: .bold, design: .monospaced))
                .foregroundColor(viewModel.feedbackColor)

            // Feedback text
            Text(viewModel.feedbackText)
                .font(Typography.headline)
                .foregroundColor(viewModel.feedbackColor)

            Spacer()

            // Score display
            HStack {
                Text("Correct: \(viewModel.correctCount)")
                Spacer()
                Text("Accuracy: \(viewModel.accuracyPercentage)%")
            }
            .font(Typography.body)

            // Paddle area
            HStack(spacing: 0) {
                // Dit button
                Button {
                    viewModel.inputDit()
                } label: {
                    Text("·")
                        .font(.system(size: 80, weight: .bold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.primary.opacity(0.2))
                }
                .buttonStyle(.plain)

                // Dah button
                Button {
                    viewModel.inputDah()
                } label: {
                    Text("—")
                        .font(.system(size: 80, weight: .bold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.primary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .frame(height: 200)
            .cornerRadius(12)
            .clipped()

            // Stop button
            Button("Stop") {
                viewModel.endSession()
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.Spacing.lg)
        .navigationTitle("Send Training")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

#Preview {
    NavigationStack {
        SendTrainingView()
            .environmentObject(ProgressStore())
            .environmentObject(SettingsStore())
    }
}
