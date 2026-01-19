import SwiftUI

struct LearnView: View {

    // MARK: Internal

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Koch Trainer")
                .font(Typography.largeTitle)

            // Streak card (only shown if streak > 0)
            if schedule.currentStreak > 0 {
                streakCard
            }

            Spacer()

            // Receive training section
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Receive")
                        .font(Typography.headline)
                    Spacer()
                    Text("Level \(progressStore.progress.receiveLevel)/26")
                        .font(Typography.body)
                        .foregroundColor(.secondary)
                }

                NavigationLink(destination: ReceiveTrainingView()) {
                    HStack {
                        Image(systemName: "ear")
                        Text("Start Receive Training")
                    }
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

            // Send training section
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Send")
                        .font(Typography.headline)
                    Spacer()
                    Text("Level \(progressStore.progress.sendLevel)/26")
                        .font(Typography.body)
                        .foregroundColor(.secondary)
                }

                NavigationLink(destination: SendTrainingView()) {
                    HStack {
                        Image(systemName: "hand.tap")
                        Text("Start Send Training")
                    }
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

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .navigationTitle("Learn")
        .navigationBarTitleDisplayMode(.inline)
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
            if schedule.currentStreak == schedule.longestStreak && schedule.longestStreak > 1 {
                Text("Personal best!")
                    .font(Typography.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func practiceDueIndicator(for sessionType: SessionType) -> some View {
        if let nextDate = schedule.nextDate(for: sessionType) {
            let isPastDue = nextDate < Date()
            if isPastDue {
                Text("Due now")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.warning)
            } else {
                Text("Next: \(nextDate, style: .relative)")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
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
