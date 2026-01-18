import Foundation

/// Manages persistence of application settings to UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            save(settings)
        }
    }

    private let key = "appSettings"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = AppSettings()
        self.settings = load()
    }

    private func load() -> AppSettings {
        guard let data = defaults.data(forKey: key) else {
            return AppSettings()
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("Failed to decode settings: \(error)")
            return AppSettings()
        }
    }

    private func save(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: key)
        } catch {
            print("Failed to encode settings: \(error)")
        }
    }
}
