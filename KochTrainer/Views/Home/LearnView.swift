import SwiftUI

struct LearnView: View {

    // MARK: Internal

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Koch Trainer")
                .font(Typography.largeTitle)
                .accessibilityIdentifier(AccessibilityID.Learn.title)

            // Streak card (only shown if streak > 0)
            if schedule.currentStreak > 0 {
                streakCard
            }

            Spacer()

            // Ear training section
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Ear Training")
                        .font(Typography.headline)
                    Spacer()
                    Text("Level \(progressStore.progress.earTrainingLevel)/\(MorseCode.maxEarTrainingLevel)")
                        .font(Typography.body)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier(AccessibilityID.Learn.earTrainingLevel)
                }

                NavigationLink(destination: EarTrainingView()) {
                    HStack {
                        Image(systemName: "ear")
                        Text("Start Ear Training")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.Learn.earTrainingButton)

                HStack {
                    let chars = MorseCode.charactersByPatternLength(
                        upToLevel: progressStore.progress.earTrainingLevel
                    )
                    Text("Characters: \(chars.map { String($0) }.joined())")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Characters: \(chars.map { String($0) }.joined(separator: " "))")

                    Spacer()
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Learn.earTrainingSection)

            // Receive training section
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Receive")
                        .font(Typography.headline)
                    Spacer()
                    Text("Level \(progressStore.progress.receiveLevel)/26")
                        .font(Typography.body)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier(AccessibilityID.Learn.receiveLevel)
                }

                NavigationLink(destination: ReceiveTrainingView()) {
                    HStack {
                        Image(systemName: "waveform")
                        Text("Start Receive Training")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.Learn.receiveTrainingButton)

                HStack {
                    let receiveChars = progressStore.progress.unlockedCharacters(for: .receive)
                    Text("Characters: \(receiveChars.map { String($0) }.joined())")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Characters: \(receiveChars.map { String($0) }.joined(separator: " "))")

                    Spacer()

                    practiceDueIndicator(for: .receive)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Learn.receiveSection)

            // Send training section
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Send")
                        .font(Typography.headline)
                    Spacer()
                    Text("Level \(progressStore.progress.sendLevel)/26")
                        .font(Typography.body)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier(AccessibilityID.Learn.sendLevel)
                }

                NavigationLink(destination: SendTrainingView()) {
                    HStack {
                        Image(systemName: "hand.tap")
                        Text("Start Send Training")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.Learn.sendTrainingButton)

                HStack {
                    let sendChars = progressStore.progress.unlockedCharacters(for: .send)
                    Text("Characters: \(sendChars.map { String($0) }.joined())")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Characters: \(sendChars.map { String($0) }.joined(separator: " "))")

                    Spacer()

                    practiceDueIndicator(for: .send)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Learn.sendSection)

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .navigationTitle("Learn")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Learn.view)
    }

    // MARK: Private

    @EnvironmentObject private var progressStore: ProgressStore

    private var schedule: PracticeSchedule {
        progressStore.progress.schedule
    }

    // MARK: - Subviews

    private var streakCard: some View {
        HStack {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
            Text("\(schedule.currentStreak) day streak")
                .font(Typography.body)
            Spacer()
            if schedule.currentStreak == schedule.longestStreak, schedule.longestStreak > 1 {
                Text("Personal best!")
                    .font(Typography.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(12)
        .accessibilityIdentifier(AccessibilityID.Learn.streakCard)
    }

    @ViewBuilder
    private func practiceDueIndicator(for sessionType: SessionType) -> some View {
        let identifier = sessionType == .receive
            ? AccessibilityID.Learn.receivePracticeDue
            : AccessibilityID.Learn.sendPracticeDue
        let modeName = sessionType == .receive ? "receive" : "send"
        if let nextDate = schedule.nextDate(for: sessionType.baseType) {
            if nextDate < Date() {
                Text("Due now")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.warning)
                    .accessibilityLabel("\(modeName.capitalized) practice due now")
                    .accessibilityIdentifier(identifier)
            } else {
                Text("Next: \(nextDate, style: .relative)")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel(
                        "Next \(modeName) practice due \(relativeTimeString(for: nextDate))"
                    )
                    .accessibilityIdentifier(identifier)
            }
        }
    }

    private func relativeTimeString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        LearnView()
            .environmentObject(ProgressStore())
            .environmentObject(SettingsStore())
            .environmentObject(NotificationManager())
    }
}
