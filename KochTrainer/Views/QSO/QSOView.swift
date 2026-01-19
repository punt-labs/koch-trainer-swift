import SwiftUI

/// Mode selection screen for QSO Simulation
struct QSOView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedStyle: QSOStyle = .contest
    @State private var isShowingSession = false

    private var userCallsign: String {
        let callsign = settingsStore.settings.userCallsign
        return callsign.isEmpty ? "W5ABC" : callsign
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("QSO Simulation")
                .font(Typography.largeTitle)

            Text("Practice realistic on-air conversations")
                .font(Typography.body)
                .foregroundColor(.secondary)

            Spacer()

            // Mode selection cards
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

            // Start button
            NavigationLink(destination: QSOSessionView(style: selectedStyle, callsign: userCallsign)) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Start QSO")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .navigationTitle("QSO")
        .navigationBarTitleDisplayMode(.inline)
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
