import SwiftUI

// MARK: - CharacterGridView

/// A grid of all 26 letters showing Morse patterns with toggleable selection.
/// Optionally displays proficiency indicators when characterStats are provided.
struct CharacterGridView: View {

    // MARK: Internal

    @Binding var selectedCharacters: Set<Character>

    /// Per-character performance statistics. When provided, displays proficiency rings.
    var characterStats: [Character: CharacterStat] = [:]

    var onCharacterSelected: ((Character) -> Void)?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(MorseCode.kochOrder, id: \.self) { character in
                    CharacterCell(
                        character: character,
                        isSelected: selectedCharacters.contains(character),
                        stat: characterStats[character],
                        onTap: { toggleSelection(character) }
                    )
                }
            }
            .padding(Theme.Spacing.sm)
        }
    }

    // MARK: Private

    private let columns = [
        GridItem(.adaptive(minimum: 60, maximum: 80), spacing: Theme.Spacing.sm)
    ]

    private func toggleSelection(_ character: Character) {
        if selectedCharacters.contains(character) {
            selectedCharacters.remove(character)
        } else {
            selectedCharacters.insert(character)
            onCharacterSelected?(character)
        }
    }
}

// MARK: - CharacterCell

/// Individual character cell in the grid with optional proficiency indicator.
private struct CharacterCell: View {

    // MARK: Internal

    let character: Character
    let isSelected: Bool
    let stat: CharacterStat?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Circular background - always same size
                Circle()
                    .fill(isSelected ? Theme.Colors.primary : Theme.Colors.secondaryBackground)

                // Content
                VStack(spacing: 2) {
                    Text(String(character))
                        .font(Typography.headline)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(pattern)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                // Progress ring overlays the edge (inset by half line width so outer edge aligns)
                if hasPracticeData {
                    ProficiencyRing(
                        proficiency: stat?.combinedAccuracy ?? 0,
                        lineWidth: 4
                    )
                    .padding(2)
                }
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(AccessibilityID.Practice.characterCell(character))
    }

    // MARK: Private

    private var pattern: String {
        MorseCode.pattern(for: character) ?? ""
    }

    private var hasPracticeData: Bool {
        guard let stat else { return false }
        return stat.totalAttempts > 0
    }

    private var accessibilityLabel: String {
        var label = "\(character)"
        if hasPracticeData, let accuracy = stat?.combinedAccuracy {
            let percentage = Int(accuracy * 100)
            label += ", \(percentage)% proficiency"
        }
        if isSelected {
            label += ", selected"
        }
        return label
    }
}

#Preview("Without Stats") {
    CharacterGridView(selectedCharacters: .constant(["K", "M", "R"]))
}

#Preview("With Proficiency Stats") {
    let sampleStats: [Character: CharacterStat] = [
        "K": CharacterStat(receiveAttempts: 50, receiveCorrect: 48, sendAttempts: 30, sendCorrect: 28),
        "M": CharacterStat(receiveAttempts: 40, receiveCorrect: 30, sendAttempts: 20, sendCorrect: 14),
        "R": CharacterStat(receiveAttempts: 10, receiveCorrect: 3, sendAttempts: 5, sendCorrect: 2),
        "S": CharacterStat(receiveAttempts: 20, receiveCorrect: 18, sendAttempts: 15, sendCorrect: 14)
    ]
    return CharacterGridView(
        selectedCharacters: .constant(["K", "M"]),
        characterStats: sampleStats
    )
}
