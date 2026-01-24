import SwiftUI

// MARK: - MorseQSOView

/// View for Morse QSO training sessions.
/// User listens to AI station (text reveals progressively) and keys responses using dit/dah.
struct MorseQSOView: View {

    // MARK: Lifecycle

    init(style: QSOStyle, callsign: String, startMode: QSOStartMode = .answerCQ) {
        _viewModel = StateObject(
            wrappedValue: MorseQSOViewModel(
                style: style,
                callsign: callsign,
                aiStarts: startMode == .answerCQ
            )
        )
    }

    // MARK: Internal

    var body: some View {
        ZStack {
            // Hidden text field for keyboard capture (only during user turn)
            if viewModel.turnState == .userKeying {
                TextField("", text: $hiddenInput)
                    .focused($isKeyboardFocused)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .onChange(of: hiddenInput) { newValue in
                        if let lastChar = newValue.last {
                            viewModel.handleKeyPress(lastChar)
                        }
                        hiddenInput = ""
                    }
            }

            // Main content
            if viewModel.isCompleted {
                MorseQSOCompletedView(result: viewModel.getResult()) {
                    dismiss()
                }
            } else {
                MorseQSOSessionView(viewModel: viewModel)
                    .onTapGesture {
                        isKeyboardFocused = true
                    }
            }
        }
        .navigationTitle("\(viewModel.style.displayName) QSO")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isSessionActive && !viewModel.isCompleted)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if viewModel.isSessionActive, !viewModel.isCompleted {
                    Button("End") {
                        viewModel.endSession()
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityID.QSO.endButton)
                }
            }
        }
        .onAppear {
            viewModel.configure(settingsStore: settingsStore)
            viewModel.startSession()
            isKeyboardFocused = true
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    // MARK: Private

    @StateObject private var viewModel: MorseQSOViewModel
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isKeyboardFocused: Bool
    @State private var hiddenInput: String = ""

}

// MARK: - MorseQSOSessionView

private struct MorseQSOSessionView: View {

    // MARK: Internal

    @ObservedObject var viewModel: MorseQSOViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar

            Divider()

            // Main content area
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // AI message area (during AI turn or after)
                    if !viewModel.aiMessage.isEmpty {
                        aiMessageView
                    }

                    // User keying area (during user turn)
                    if viewModel.turnState == .userKeying {
                        userKeyingView
                    }
                }
                .padding(Theme.Spacing.lg)
            }

            Divider()

            // Input area (only during user turn)
            if viewModel.turnState == .userKeying {
                inputArea
            }

            // Accuracy footer
            accuracyFooter
        }
    }

    // MARK: Private

    private var turnStateText: String {
        switch viewModel.turnState {
        case .idle: return "Starting..."
        case .aiTransmitting: return "Listening..."
        case .userKeying: return "Your turn to send"
        case .completed: return "QSO Complete!"
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            // Station info
            VStack(alignment: .leading, spacing: 2) {
                Text("Working:")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.theirCallsign.isEmpty ? "Calling CQ..." : viewModel.theirCallsign)
                    .font(Typography.headline)
                    .accessibilityIdentifier(AccessibilityID.QSO.stationCallsign)
            }

            Spacer()

            // Turn indicator
            VStack(alignment: .trailing, spacing: 2) {
                Text("Status")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
                Text(turnStateText)
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.primary)
                    .accessibilityIdentifier(AccessibilityID.QSO.turnStatus)
            }

            // Audio indicator
            if viewModel.isPlayingAudio {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(Theme.Colors.primary)
                    .padding(.leading, Theme.Spacing.sm)
                    .accessibilityIdentifier(AccessibilityID.QSO.audioIndicator)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .accessibilityIdentifier(AccessibilityID.QSO.statusBar)
    }

    // MARK: - AI Message View

    private var aiMessageView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(Theme.Colors.primary)
                Text(viewModel.theirCallsign)
                    .font(Typography.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Show/hide toggle
                Button {
                    viewModel.isAITextVisible.toggle()
                } label: {
                    Image(systemName: viewModel.isAITextVisible ? "eye" : "eye.slash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.QSO.aiTextToggle)
            }

            // Progressive reveal text (or hidden indicator)
            if viewModel.isAITextVisible {
                Text(viewModel.revealedText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Theme.Colors.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(AccessibilityID.QSO.revealedText)
            } else {
                Text("Text hidden - listen to copy")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.primary.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.QSO.aiMessageView)
    }

    // MARK: - User Keying View

    private var userKeyingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Typed characters reveal
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text("Send:")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Show WPM if characters have been keyed
                    if viewModel.currentBlockWPM > 0 {
                        Text("\(viewModel.currentBlockWPM) WPM")
                            .font(Typography.caption)
                            .foregroundColor(Theme.Colors.primary)
                            .accessibilityIdentifier(AccessibilityID.QSO.wpmDisplay)
                    }
                }

                // Show typed portion + cursor indicator
                HStack(spacing: 0) {
                    Text(viewModel.typedScript)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Theme.Colors.success)
                        .accessibilityIdentifier(AccessibilityID.QSO.typedScript)

                    if let expected = viewModel.currentExpectedCharacter {
                        Text(String(expected))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Theme.Colors.primary)
                            .background(Theme.Colors.primary.opacity(0.2))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(8)

            // Current character and pattern
            if let expected = viewModel.currentExpectedCharacter {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Current: \(String(expected))")
                        .font(Typography.headline)
                        .accessibilityIdentifier(AccessibilityID.QSO.currentCharacter)

                    Text(viewModel.currentPattern.isEmpty ? "..." : viewModel.currentPattern)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(height: 32)
                        .accessibilityIdentifier(AccessibilityID.QSO.currentPattern)

                    // Input timeout bar
                    if viewModel.inputTimeRemaining > 0 {
                        MorseQSOTimeoutBar(progress: viewModel.inputProgress)
                            .frame(height: 6)
                    }
                }
            }

            // Last keyed feedback
            if let lastKeyed = viewModel.lastKeyedCharacter {
                HStack {
                    Text("Last: \(String(lastKeyed))")
                        .font(Typography.caption)
                    Image(systemName: viewModel.lastKeyedWasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(viewModel.lastKeyedWasCorrect ? Theme.Colors.success : Theme.Colors.error)
                }
                .accessibilityIdentifier(AccessibilityID.QSO.lastKeyedFeedback)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.QSO.userKeyingView)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Keyboard hint
            Text("Keyboard: . or F = dit, - or J = dah")
                .font(Typography.caption)
                .foregroundColor(.secondary)
                .accessibilityIdentifier(AccessibilityID.QSO.keyboardHint)

            // Paddle buttons
            HStack(spacing: 2) {
                Button {
                    viewModel.inputDit()
                } label: {
                    Text("dit")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.primary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.QSO.ditButton)

                Button {
                    viewModel.inputDah()
                } label: {
                    Text("dah")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.QSO.dahButton)
            }
            .frame(height: 100)
            .cornerRadius(12)
            .clipped()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.QSO.inputArea)
    }

    // MARK: - Accuracy Footer

    private var accuracyFooter: some View {
        HStack {
            Text("Keyed: \(viewModel.correctCharactersKeyed)/\(viewModel.totalCharactersKeyed)")
                .accessibilityIdentifier(AccessibilityID.QSO.keyedCount)
            Spacer()
            Text("Accuracy: \(viewModel.accuracyPercentage)%")
                .accessibilityIdentifier(AccessibilityID.QSO.accuracyDisplay)
        }
        .font(Typography.caption)
        .foregroundColor(.secondary)
        .padding(Theme.Spacing.md)
    }
}

// MARK: - MorseQSOCompletedView

private struct MorseQSOCompletedView: View {
    let result: MorseQSOResult
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // Success header
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.success)

                Text("QSO Complete!")
                    .font(Typography.largeTitle)
                    .accessibilityIdentifier(AccessibilityID.QSO.completedTitle)

                Text("73 de \(result.theirCallsign)")
                    .font(Typography.headline)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(AccessibilityID.QSO.completedCallsign)
            }

            Spacer()

            // Stats card
            VStack(spacing: Theme.Spacing.md) {
                MorseQSOResultRow(label: "Style", value: result.style.displayName)
                MorseQSOResultRow(label: "Station", value: result.theirCallsign)
                MorseQSOResultRow(label: "Operator", value: result.theirName)
                MorseQSOResultRow(label: "QTH", value: result.theirQTH)
                MorseQSOResultRow(label: "Duration", value: result.formattedDuration)
                MorseQSOResultRow(label: "Exchanges", value: "\(result.exchangesCompleted)")

                Divider()

                MorseQSOResultRow(label: "Characters Keyed", value: "\(result.totalCharactersKeyed)")
                MorseQSOResultRow(
                    label: "Keying Accuracy",
                    value: result.formattedAccuracy,
                    valueColor: result.keyingAccuracy >= 0.9 ? Theme.Colors.success : nil
                )
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.QSO.statsCard)

            Spacer()

            Button("Done") {
                onDismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(AccessibilityID.QSO.doneButton)

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .accessibilityIdentifier(AccessibilityID.QSO.completedView)
    }
}

// MARK: - MorseQSOResultRow

private struct MorseQSOResultRow: View {
    let label: String
    let value: String
    var valueColor: Color?

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(valueColor ?? .primary)
        }
        .font(Typography.body)
    }
}

// MARK: - MorseQSOTimeoutBar

private struct MorseQSOTimeoutBar: View {

    // MARK: Internal

    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.Colors.secondaryBackground)

                RoundedRectangle(cornerRadius: 3)
                    .fill(progressColor)
                    .frame(width: geometry.size.width * max(0, min(1, progress)))
            }
        }
    }

    // MARK: Private

    private var progressColor: Color {
        if progress > 0.5 {
            return Theme.Colors.success
        } else if progress > 0.25 {
            return Theme.Colors.warning
        } else {
            return Theme.Colors.error
        }
    }

}

#Preview {
    NavigationStack {
        MorseQSOView(style: .contest, callsign: "W5ABC")
            .environmentObject(SettingsStore())
    }
}
