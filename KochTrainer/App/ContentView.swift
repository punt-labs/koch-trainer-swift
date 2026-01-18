import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ProgressStore())
        .environmentObject(SettingsStore())
}
