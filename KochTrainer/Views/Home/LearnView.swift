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
                    .accessibilityIdentifier(AccessibilityID.Learn.earTrainingButton)
                }
                .buttonStyle(PrimaryButtonStyle())

                HStack {
                    let chars = MorseCode.charactersByPatternLength(
                        upToLevel: progressStore.progress.earTrainingLevel
                    )
                    Text("Characters: \(chars.map { String($0) }.joined())")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)
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
                    .accessibilityIdentifier(AccessibilityID.Learn.receiveTrainingButton)
                }
                .buttonStyle(PrimaryButtonStyle())

                HStack {
                    Text(
                        "Characters: \(progressStore.progress.unlockedCharacters(for: .receive).map { String($0) }.joined())"
                    )
                    .font(Typography.caption)
                    .foregroundColor(.secondary)

                    Spacer()

                    practiceDueIndicator(for: .receive)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)
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
                    .accessibilityIdentifier(AccessibilityID.Learn.sendTrainingButton)
                }
                .buttonStyle(PrimaryButtonStyle())

                HStack {
                    Text(
                        "Characters: \(progressStore.progress.unlockedCharacters(for: .send).map { String($0) }.joined())"
                    )
                    .font(Typography.caption)
                    .foregroundColor(.secondary)

                    Spacer()

                    practiceDueIndicator(for: .send)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)
            .accessibilityIdentifier(AccessibilityID.Learn.sendSection)

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .navigationTitle("Learn")
        .navigationBarTitleDisplayMode(.inline)
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
        if let nextDate = schedule.nextDate(for: sessionType.baseType) {
            let isPastDue = nextDate < Date()
            if isPastDue {
                Text("Due now")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.warning)
                    .accessibilityIdentifier(identifier)
            } else {
                Text("Next: \(nextDate, style: .relative)")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(identifier)
            }
        }
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
