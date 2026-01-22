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
            .accessibilityIdentifier(AccessibilityID.Tab.learn)

            NavigationStack {
                PracticeView()
            }
            .tabItem {
                Label("Practice", systemImage: "checklist")
            }
            .accessibilityIdentifier(AccessibilityID.Tab.practice)

            NavigationStack {
                VocabularyView()
            }
            .tabItem {
                Label("Vocab", systemImage: "text.book.closed")
            }
            .accessibilityIdentifier(AccessibilityID.Tab.vocab)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .accessibilityIdentifier(AccessibilityID.Tab.settings)
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
