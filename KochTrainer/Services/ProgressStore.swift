import Foundation

/// Protocol for progress persistence.
protocol ProgressStoreProtocol: AnyObject {
    var progress: StudentProgress { get set }
    func load() -> StudentProgress
    func save(_ progress: StudentProgress)
    func resetProgress()
}

/// Manages persistence of student progress to UserDefaults.
@MainActor
final class ProgressStore: ObservableObject, ProgressStoreProtocol {
    @Published var progress: StudentProgress

    private let key = "studentProgress"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.progress = StudentProgress()
        self.progress = load()
    }

    func load() -> StudentProgress {
        guard let data = defaults.data(forKey: key) else {
            return StudentProgress()
        }
        do {
            return try JSONDecoder().decode(StudentProgress.self, from: data)
        } catch {
            print("Failed to decode progress: \(error)")
            return StudentProgress()
        }
    }

    func save(_ progress: StudentProgress) {
        do {
            let data = try JSONEncoder().encode(progress)
            defaults.set(data, forKey: key)
            self.progress = progress
        } catch {
            print("Failed to encode progress: \(error)")
        }
    }

    func resetProgress() {
        let fresh = StudentProgress()
        save(fresh)
    }

    /// Overall accuracy as a whole percentage (0-100)
    var overallAccuracyPercentage: Int {
        Int((progress.overallAccuracy * 100).rounded())
    }

    /// Update progress after a session and check for level advancement.
    /// Returns true if the student leveled up.
    @discardableResult
    func recordSession(_ result: SessionResult) -> Bool {
        var updated = progress
        updated.updateStats(from: result)
        let didAdvance = updated.advanceIfEligible(sessionAccuracy: result.accuracy, sessionType: result.sessionType)
        save(updated)
        return didAdvance
    }
}
