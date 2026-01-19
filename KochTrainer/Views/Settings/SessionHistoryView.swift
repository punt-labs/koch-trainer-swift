import SwiftUI

// MARK: - SessionHistoryView

/// Displays session history with swipe-to-delete functionality.
struct SessionHistoryView: View {

    // MARK: Internal

    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .navigationTitle("Session History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !sessions.isEmpty {
                    EditButton()
                }
            }
        }
    }

    // MARK: Private

    @EnvironmentObject private var progressStore: ProgressStore
    @State private var showCleanupAlert = false
    @State private var showRecalculateAlert = false
    @State private var invalidSessionsDeleted = 0

    private var sessions: [SessionResult] {
        progressStore.progress.sessionHistory.sorted { $0.date > $1.date }
    }

    private var schedule: PracticeSchedule {
        progressStore.progress.schedule
    }

    private var invalidSessionCount: Int {
        sessions.filter { $0.totalAttempts == 0 }.count
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Sessions Yet")
                .font(Typography.headline)

            Text("Complete a training session to see your history here.")
                .font(Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }

    private var sessionList: some View {
        List {
            #if DEBUG
                // Advanced schedule details (debug builds only)
                Section("Schedule Details") {
                    debugRow(label: "Last Streak Date", date: schedule.lastStreakDate)
                    debugRow(label: "Receive Next", date: schedule.receiveNextDate)
                    debugRow(label: "Send Next", date: schedule.sendNextDate)

                    HStack {
                        Text("Receive Interval")
                        Spacer()
                        Text("\(String(format: "%.2f", schedule.receiveInterval)) days")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Send Interval")
                        Spacer()
                        Text("\(String(format: "%.2f", schedule.sendInterval)) days")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Current Streak")
                        Spacer()
                        Text("\(schedule.currentStreak) days")
                            .foregroundColor(.secondary)
                    }

                    if let lastSession = sessions.first {
                        debugRow(label: "Most Recent Session", date: lastSession.date)
                    }
                }
            #endif

            // Schedule info section
            Section("Next Practice") {
                if let receiveNext = schedule.receiveNextDate {
                    scheduleRow(label: "Receive", date: receiveNext, interval: schedule.receiveInterval)
                } else {
                    Text("Receive: Not scheduled")
                        .foregroundColor(.secondary)
                }

                if let sendNext = schedule.sendNextDate {
                    scheduleRow(label: "Send", date: sendNext, interval: schedule.sendInterval)
                } else {
                    Text("Send: Not scheduled")
                        .foregroundColor(.secondary)
                }
            }

            // Data maintenance section
            Section("Data Maintenance") {
                Button {
                    let deleted = progressStore.deleteInvalidSessions()
                    invalidSessionsDeleted = deleted
                    showCleanupAlert = true
                } label: {
                    HStack {
                        Text("Delete Invalid Sessions")
                        Spacer()
                        Text("\(invalidSessionCount) found")
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(invalidSessionCount == 0)

                Button("Recalculate Schedule from History") {
                    progressStore.recalculateScheduleFromHistory()
                    showRecalculateAlert = true
                }
            }

            // Session history section
            Section("Sessions (\(sessions.count))") {
                ForEach(sessions) { session in
                    SessionHistoryRow(session: session)
                }
                .onDelete(perform: deleteSessions)
            }
        }
        .alert("Cleanup Complete", isPresented: $showCleanupAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Deleted \(invalidSessionsDeleted) invalid session(s).")
        }
        .alert("Schedule Recalculated", isPresented: $showRecalculateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Next practice dates have been recalculated from your valid session history.")
        }
    }

    private func debugRow(label: String, date: Date?) -> some View {
        HStack {
            Text(label)
            Spacer()
            if let date {
                Text(date, format: .dateTime.month().day().hour().minute())
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("nil")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func scheduleRow(label: String, date: Date, interval: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(Typography.body)
                Spacer()
                if date < Date() {
                    Text("Due now")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.warning)
                } else {
                    Text(date, style: .relative)
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text("Interval: \(String(format: "%.1f", interval)) days")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(date, format: .dateTime.month().day().hour().minute())
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        let sessionsToDelete = offsets.map { sessions[$0] }
        for session in sessionsToDelete {
            progressStore.deleteSession(id: session.id)
        }
    }
}

// MARK: - SessionHistoryRow

private struct SessionHistoryRow: View {

    // MARK: Internal

    let session: SessionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Session type badge
                Text(session.sessionType.displayName)
                    .font(Typography.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.2))
                    .foregroundColor(badgeColor)
                    .cornerRadius(4)

                Spacer()

                // Accuracy
                Text("\(session.accuracyPercentage)%")
                    .font(Typography.headline)
                    .foregroundColor(accuracyColor)
            }

            HStack {
                // Date
                Text(session.date, format: .dateTime.month().day().year().hour().minute())
                    .font(Typography.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Duration
                Text(session.formattedDuration)
                    .font(Typography.caption)
                    .foregroundColor(.secondary)

                // Attempts
                Text("\(session.correctCount)/\(session.totalAttempts)")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Private

    private var badgeColor: Color {
        switch session.sessionType.baseType {
        case .receive: return Theme.Colors.primary
        case .send: return Theme.Colors.success
        default: return .secondary
        }
    }

    private var accuracyColor: Color {
        if session.accuracy >= 0.9 {
            return Theme.Colors.success
        } else if session.accuracy >= 0.7 {
            return Theme.Colors.warning
        } else {
            return Theme.Colors.error
        }
    }
}

#Preview {
    NavigationStack {
        SessionHistoryView()
            .environmentObject(ProgressStore())
    }
}
