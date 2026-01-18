import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var progressStore: ProgressStore

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Koch Trainer")
                .font(Typography.largeTitle)

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

                Text("Characters: \(progressStore.progress.unlockedCharacters(for: .receive).map { String($0) }.joined())")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(Theme.Spacing.md)
            .background(Color.gray.opacity(0.1))
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

                Text("Characters: \(progressStore.progress.unlockedCharacters(for: .send).map { String($0) }.joined())")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(Theme.Spacing.md)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Spacer()

            NavigationLink(destination: SettingsView()) {
                Text("Settings")
                    .font(Typography.body)
            }
        }
        .padding(Theme.Spacing.lg)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(ProgressStore())
    }
}
