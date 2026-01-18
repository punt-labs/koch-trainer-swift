import SwiftUI

@main
struct KochTrainerApp: App {
    @StateObject private var progressStore = ProgressStore()
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(progressStore)
                .environmentObject(settingsStore)
        }
    }
}
