import Foundation
import os

/// Manages persistence of application settings to UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {

    // MARK: Lifecycle

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = AppSettings()
        settings = load()
    }

    // MARK: Internal

    @Published var settings: AppSettings {
        didSet {
            save(settings)
        }
    }

    // MARK: Private

    private let key = "appSettings"
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.kochtrainer", category: "SettingsStore")

    private func load() -> AppSettings {
        guard let data = defaults.data(forKey: key) else {
            return AppSettings()
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            logger.error("Failed to decode settings: \(error.localizedDescription)")
            return AppSettings()
        }
    }

    private func save(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: key)
        } catch {
            logger.error("Failed to encode settings: \(error.localizedDescription)")
        }
    }
}
