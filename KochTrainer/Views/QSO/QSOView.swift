import SwiftUI

// MARK: - QSOStartMode

/// Who initiates the QSO
enum QSOStartMode: String, CaseIterable {
    case callCQ // User calls CQ, AI responds
    case answerCQ // AI calls CQ, user responds

    // MARK: Internal

    var displayName: String {
        switch self {
        case .callCQ: return "Call CQ"
        case .answerCQ: return "Answer CQ"
        }
    }

    var description: String {
        switch self {
        case .callCQ: return "You call CQ and wait for a response"
        case .answerCQ: return "Listen for CQ and respond to it"
        }
    }

    var icon: String {
        switch self {
        case .callCQ: return "megaphone"
        case .answerCQ: return "ear"
        }
    }
}

// MARK: - QSOView

/// Mode selection screen for QSO Simulation
struct QSOView: View {

    // MARK: Internal

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Text("QSO Simulation")
                    .font(Typography.largeTitle)

                Text("Practice realistic on-air conversations")
                    .font(Typography.body)
                    .foregroundColor(.secondary)

                // Start mode picker (Call CQ vs Answer CQ)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Start Mode")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)

                    Picker("Start Mode", selection: $startMode) {
                        ForEach(QSOStartMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(AccessibilityID.QSO.startModePicker)

                    Text(startMode.description)
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

                // Callsign display
                VStack(spacing: Theme.Spacing.xs) {
                    Text("Your Callsign")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                    Text(userCallsign)
                        .font(Typography.headline)
                        .accessibilityIdentifier(AccessibilityID.QSO.callsignDisplay)

                    if settingsStore.settings.userCallsign.isEmpty {
                        Text("Set your callsign in Settings")
                            .font(Typography.caption)
                            .foregroundColor(Theme.Colors.warning)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(12)

                // Start button
                NavigationLink(
                    destination: MorseQSOView(
                        style: selectedStyle,
                        callsign: userCallsign,
                        startMode: startMode
                    )
                ) {
                    HStack {
                        Image(systemName: startMode == .callCQ ? "megaphone" : "ear")
                        Text("Start QSO")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.QSO.startButton)
            }
            .padding(Theme.Spacing.lg)
        }
        .navigationTitle("QSO")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.QSO.view)
    }

    // MARK: Private

    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedStyle: QSOStyle = .firstContact
    @State private var startMode: QSOStartMode = .answerCQ

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
                    HStack {
                        Text(style.displayName)
                            .font(Typography.headline)
                            .foregroundColor(selectedStyle == style ? .white : .primary)

                        Text(style.difficulty)
                            .font(Typography.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(selectedStyle == style ? Color.white.opacity(0.2) : Theme.Colors.primary
                                .opacity(0.1))
                            .foregroundColor(selectedStyle == style ? .white : Theme.Colors.primary)
                            .cornerRadius(4)
                    }

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
        .accessibilityIdentifier(AccessibilityID.QSO.styleCard(style.rawValue))
    }
}

#Preview {
    NavigationStack {
        QSOView()
            .environmentObject(SettingsStore())
    }
}
