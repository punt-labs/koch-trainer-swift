import Foundation

// MARK: - Private Helpers

extension ReceiveTrainingViewModel {
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

    func playNextGroup() {
        guard isPlaying else { return }
        currentGroup = Array(generateGroup())
        currentGroupIndex = 0
        playNextCharacterInGroup()
    }

    private func playNextCharacterInGroup() {
        guard isPlaying else { return }

        if currentGroupIndex >= currentGroup.count {
            Task {
                try? await Task.sleep(nanoseconds: TrainingTiming.correctAnswerDelay)
                if isPlaying { playNextGroup() }
            }
            return
        }

        let char = currentGroup[currentGroupIndex]
        currentCharacter = char
        lastFeedback = nil

        Task {
            audioEngine.reset()
            await audioEngine.playCharacter(char)
            if isPlaying { startResponseTimer() }
        }
    }

    func startResponseTimer() {
        isWaitingForResponse = true
        responseTimeRemaining = responseTimeout

        responseTimer?.invalidate()
        responseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickResponse() }
        }
    }

    private func tickResponse() {
        responseTimeRemaining -= 0.05
        if responseTimeRemaining <= 0 {
            responseTimer?.invalidate()
            isWaitingForResponse = false
            if let expected = currentCharacter {
                recordResponse(expected: expected, wasCorrect: false, userPressed: nil)
                showFeedbackAndContinue(wasCorrect: false, expected: expected, userPressed: nil)
            }
        }
    }

    func recordResponse(expected: Character, wasCorrect: Bool, userPressed: Character?) {
        totalAttempts += 1
        if wasCorrect { correctCount += 1 }

        var stat = characterStats[expected] ?? CharacterStat()
        stat.receiveAttempts += 1
        if wasCorrect { stat.receiveCorrect += 1 }
        stat.lastPracticed = Date()
        characterStats[expected] = stat
    }

    func showFeedbackAndContinue(wasCorrect: Bool, expected: Character, userPressed: Character?) {
        lastFeedback = Feedback(wasCorrect: wasCorrect, expectedCharacter: expected, userPressed: userPressed)

        Task {
            if !wasCorrect {
                try? await Task.sleep(nanoseconds: TrainingTiming.preReplayDelay)
                if isPlaying { await audioEngine.playCharacter(expected) }
                try? await Task.sleep(nanoseconds: TrainingTiming.postReplayDelay)
            } else {
                try? await Task.sleep(nanoseconds: TrainingTiming.correctAnswerDelay)
            }

            checkForProficiency()
            if isPlaying {
                currentGroupIndex += 1
                playNextCharacterInGroup()
            }
        }
    }

    private func generateGroup() -> String {
        var combinedStats = progressStore?.progress.characterStats ?? [:]
        for (char, sessionStat) in characterStats {
            if var existing = combinedStats[char] {
                existing.merge(sessionStat)
                combinedStats[char] = existing
            } else {
                combinedStats[char] = sessionStat
            }
        }

        return GroupGenerator.generateMixedGroup(
            level: currentLevel,
            characterStats: combinedStats,
            sessionType: .receive,
            groupLength: Int.random(in: 3 ... 5),
            availableCharacters: customCharacters
        )
    }
}
