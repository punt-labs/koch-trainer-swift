import SwiftUI

// MARK: - CharacterGridView

/// A grid of all 26 letters showing Morse patterns with toggleable selection.
struct CharacterGridView: View {

    // MARK: Internal

    @Binding var selectedCharacters: Set<Character>

    var onCharacterSelected: ((Character) -> Void)?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(MorseCode.kochOrder, id: \.self) { character in
                    CharacterCell(
                        character: character,
                        isSelected: selectedCharacters.contains(character),
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

/// Individual character cell in the grid.
private struct CharacterCell: View {

    // MARK: Internal

    let character: Character
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(String(character))
                    .font(Typography.headline)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(pattern)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(width: 60, height: 60)
            .background(isSelected ? Theme.Colors.primary : Theme.Colors.secondaryBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: Private

    private var pattern: String {
        MorseCode.pattern(for: character) ?? ""
    }

}

#Preview {
    CharacterGridView(selectedCharacters: .constant(["K", "M", "R"]))
}
