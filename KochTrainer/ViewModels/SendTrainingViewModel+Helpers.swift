import Foundation

// MARK: - Private Helpers

extension SendTrainingViewModel {
    func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickSession() }
        }
    }

    private func tickSession() {
        guard timeRemaining > 0 else {
            endSession()
            return
        }
        timeRemaining -= 1
    }

    func resetInputTimer() {
        inputTimeRemaining = currentInputTimeout
        inputTimer?.invalidate()
        inputTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickInput() }
        }
    }

    private func tickInput() {
        inputTimeRemaining -= 0.05
        if inputTimeRemaining <= 0 {
            inputTimer?.invalidate()
            completeCurrentInput()
        }
    }

    private func completeCurrentInput() {
        isWaitingForInput = false

        let decodedChar = currentPattern.isEmpty ? nil : MorseCode.character(for: currentPattern)
        let isCorrect = !currentPattern.isEmpty && decodedChar == targetCharacter
        let displayPattern = currentPattern.isEmpty ? "(no response)" : currentPattern
        recordResponse(expected: targetCharacter, wasCorrect: isCorrect, pattern: displayPattern, decoded: decodedChar)
        showFeedbackAndContinue(
            wasCorrect: isCorrect,
            expected: targetCharacter,
            pattern: displayPattern,
            decoded: decodedChar
        )
    }

    func recordResponse(expected: Character, wasCorrect: Bool, pattern: String, decoded: Character?) {
        totalAttempts += 1
        if wasCorrect { correctCount += 1 }

        var stat = characterStats[expected] ?? CharacterStat()
        stat.sendAttempts += 1
        if wasCorrect { stat.sendCorrect += 1 }
        stat.lastPracticed = Date()
        characterStats[expected] = stat
    }

    func showFeedbackAndContinue(wasCorrect: Bool, expected: Character, pattern: String, decoded: Character?) {
        lastFeedback = Feedback(
            wasCorrect: wasCorrect,
            expectedCharacter: expected,
            sentPattern: pattern,
            decodedCharacter: decoded
        )

        Task {
            if !wasCorrect {
                try? await Task.sleep(nanoseconds: TrainingTiming.preReplayDelay)
                if isPlaying { await audioEngine.playCharacter(expected) }
                try? await Task.sleep(nanoseconds: TrainingTiming.postReplayDelay)
            } else {
                try? await Task.sleep(nanoseconds: TrainingTiming.correctAnswerDelay)
            }

            checkForProficiency()
            if isPlaying { showNextCharacter() }
        }
    }

    func showNextCharacter() {
        var combinedStats = progressStore?.progress.characterStats ?? [:]
        for (char, sessionStat) in characterStats {
            if var existing = combinedStats[char] {
                existing.merge(sessionStat)
                combinedStats[char] = existing
            } else {
                combinedStats[char] = sessionStat
            }
        }

        let group = GroupGenerator.generateMixedGroup(
            level: currentLevel,
            characterStats: combinedStats,
            sessionType: .send,
            groupLength: 1,
            availableCharacters: customCharacters
        )

        if let char = group.first { targetCharacter = char }
        currentPattern = ""
        lastFeedback = nil
        isWaitingForInput = true
        resetInputTimer()
    }
}
