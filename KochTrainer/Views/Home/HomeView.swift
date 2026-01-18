import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var progressStore: ProgressStore

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Koch Trainer")
                .font(Typography.largeTitle)

            Text("Level \(progressStore.progress.currentLevel) of 26")
                .font(Typography.headline)

            Spacer()

            NavigationLink(destination: ReceiveTrainingView()) {
                Text("Receive Training")
            }
            .buttonStyle(PrimaryButtonStyle())

            NavigationLink(destination: SendTrainingView()) {
                Text("Send Training")
            }
            .buttonStyle(PrimaryButtonStyle())

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
