import SwiftUI

struct ContentView: View {

    // MARK: Internal

    var body: some View {
        TabView {
            NavigationStack {
                LearnView()
            }
            .tabItem {
                Label("Learn", systemImage: "graduationcap")
            }

            NavigationStack {
                PracticeView()
            }
            .tabItem {
                Label("Practice", systemImage: "checklist")
            }

            NavigationStack {
                VocabularyView()
            }
            .tabItem {
                Label("Vocab", systemImage: "text.book.closed")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }

    // MARK: Private

    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var notificationManager: NotificationManager

}

#Preview {
    ContentView()
        .environmentObject(ProgressStore())
        .environmentObject(SettingsStore())
        .environmentObject(NotificationManager())
}
