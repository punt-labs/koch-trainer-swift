import SwiftUI

// MARK: - QSOInputMode

/// Input mode for QSO simulation
enum QSOInputMode: String, CaseIterable {
    case text
    case morse

    // MARK: Internal

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .morse: return "Morse"
        }
    }

    var description: String {
        switch self {
        case .text: return "Type messages with keyboard"
        case .morse: return "Key dit/dah with paddles"
        }
    }
}

// MARK: - QSOView

/// Mode selection screen for QSO Simulation
struct QSOView: View {

    // MARK: Internal

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("QSO Simulation")
                .font(Typography.largeTitle)

            Text("Practice realistic on-air conversations")
                .font(Typography.body)
                .foregroundColor(.secondary)

            Spacer()

            // Input mode picker
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Input Mode")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)

                Picker("Input Mode", selection: $inputMode) {
                    ForEach(QSOInputMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(inputMode.description)
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)

            // QSO style selection cards
            VStack(spacing: Theme.Spacing.md) {
                ForEach(QSOStyle.allCases, id: \.self) { style in
                    modeCard(for: style)
                }
            }

            Spacer()

            // Callsign display
            VStack(spacing: Theme.Spacing.xs) {
                Text("Your Callsign")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
                Text(userCallsign)
                    .font(Typography.headline)

                if settingsStore.settings.userCallsign.isEmpty {
                    Text("Set your callsign in Settings")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.warning)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)

            // Start button - destination varies by input mode
            if inputMode == .text {
                NavigationLink(destination: QSOSessionView(style: selectedStyle, callsign: userCallsign)) {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("Start Text QSO")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                NavigationLink(destination: MorseQSOView(style: selectedStyle, callsign: userCallsign)) {
                    HStack {
                        Image(systemName: "waveform")
                        Text("Start Morse QSO")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .navigationTitle("QSO")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Private

    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedStyle: QSOStyle = .contest
    @State private var inputMode: QSOInputMode = .morse

    private var userCallsign: String {
        let callsign = settingsStore.settings.userCallsign
        return callsign.isEmpty ? "W5ABC" : callsign
    }

    // MARK: - Subviews

    private func modeCard(for style: QSOStyle) -> some View {
        Button {
            selectedStyle = style
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(style.displayName)
                        .font(Typography.headline)
                        .foregroundColor(selectedStyle == style ? .white : .primary)

                    Text(style.description)
                        .font(Typography.caption)
                        .foregroundColor(selectedStyle == style ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if selectedStyle == style {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(Theme.Spacing.md)
            .background(selectedStyle == style ? Theme.Colors.primary : Theme.Colors.secondaryBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        QSOView()
            .environmentObject(SettingsStore())
    }
}
