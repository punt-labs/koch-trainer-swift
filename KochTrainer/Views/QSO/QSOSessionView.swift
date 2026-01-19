import SwiftUI

/// Live QSO session view with transcript and input
struct QSOSessionView: View {

    // MARK: Lifecycle

    init(style: QSOStyle, callsign: String) {
        _viewModel = StateObject(wrappedValue: QSOViewModel(style: style, callsign: callsign))
    }

    // MARK: Internal

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar

            Divider()

            // Transcript
            transcriptView

            Divider()

            // Hint area (if visible)
            if viewModel.showHint {
                hintView
                Divider()
            }

            // Input area
            inputArea
        }
        .navigationTitle("\(viewModel.style.displayName) QSO")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isSessionActive)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if viewModel.isSessionActive, !viewModel.isCompleted {
                    Button("End") {
                        viewModel.endSession()
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.toggleHint()
                } label: {
                    Image(systemName: viewModel.showHint ? "lightbulb.fill" : "lightbulb")
                }
                .disabled(viewModel.isCompleted)
            }
        }
        .onAppear {
            viewModel.configure(settingsStore: settingsStore)
            viewModel.startSession()
            isInputFocused = true
        }
        .onDisappear {
            viewModel.endSession()
        }
        .sheet(isPresented: .constant(viewModel.isCompleted)) {
            QSOCompletedView(result: viewModel.getResult()) {
                dismiss()
            }
        }
    }

    // MARK: Private

    @EnvironmentObject private var settingsStore: SettingsStore
    @StateObject private var viewModel: QSOViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            // Station info
            VStack(alignment: .leading, spacing: 2) {
                Text("Working:")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.theirCallsign.isEmpty ? "Waiting..." : viewModel.theirCallsign)
                    .font(Typography.headline)
            }

            Spacer()

            // Phase indicator
            VStack(alignment: .trailing, spacing: 2) {
                Text("Phase")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.phase.userAction)
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.primary)
            }

            // Audio indicator
            if viewModel.isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(Theme.Colors.primary)
                    .padding(.leading, Theme.Spacing.sm)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
    }

    // MARK: - Transcript

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.transcript) { message in
                        messageRow(message)
                            .id(message.id)
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .onChange(of: viewModel.transcript.count) { _ in
                if let lastMessage = viewModel.transcript.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Hint View

    private var hintView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Suggested:")
                .font(Typography.caption)
                .foregroundColor(.secondary)

            Text(viewModel.currentHint)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Theme.Colors.primary)

            if let validationHint = viewModel.validationHint {
                Text(validationHint)
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.primary.opacity(0.05))
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Enter message...", text: $viewModel.userInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .focused($isInputFocused)
                .onSubmit {
                    submitMessage()
                }
                .disabled(viewModel.isCompleted || viewModel.isPlaying)

            Button {
                submitMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .padding(Theme.Spacing.sm)
                    .background(viewModel.userInput.isEmpty ? Color.gray : Theme.Colors.primary)
                    .clipShape(Circle())
            }
            .disabled(viewModel.userInput.isEmpty || viewModel.isCompleted || viewModel.isPlaying)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
    }

    private func messageRow(_ message: QSOMessage) -> some View {
        HStack(alignment: .top) {
            if message.sender == .station {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(Theme.Colors.primary)
                    .frame(width: 24)
            } else {
                Image(systemName: "person.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(message.sender == .station ? viewModel.theirCallsign : "You")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)

                Text(message.text)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(message.sender == .station ? Theme.Colors.primary : .primary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(message.sender == .station ? Theme.Colors.primary.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    private func submitMessage() {
        Task {
            await viewModel.submitInput()
        }
    }
}

#Preview {
    NavigationStack {
        QSOSessionView(style: .contest, callsign: "W5ABC")
            .environmentObject(SettingsStore())
    }
}
