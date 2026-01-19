import SwiftUI

// MARK: - AcknowledgmentsView

/// Displays acknowledgments and credits.
struct AcknowledgmentsView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Koch Method
                AcknowledgmentSection(
                    title: "The Koch Method",
                    description: """
                    This app implements the Koch method for learning Morse code, developed by \
                    German psychologist Ludwig Koch in the 1930s. The method teaches characters \
                    at full speed from the start, adding new characters only after achieving \
                    90% accuracy with the current set.
                    """
                )

                Divider()

                // Inspirations
                AcknowledgmentSection(
                    title: "Inspirations",
                    description: """
                    Koch Trainer was inspired by several excellent Morse code training programs:

                    • G4FON Koch Trainer — The classic Windows Koch method trainer
                    • Morse Runner — Contest simulation software
                    • LCWO.net — Learn CW Online web-based trainer
                    • Ham Morse — iOS Morse code app

                    We're grateful to the amateur radio community for decades of Morse code \
                    education resources.
                    """
                )

                Divider()

                // Open Source
                AcknowledgmentSection(
                    title: "Open Source",
                    description: """
                    Koch Trainer is open source software released under the MIT License. \
                    The source code is available on GitHub.

                    This app uses no external dependencies — it's built entirely with \
                    Apple's frameworks: SwiftUI, AVFoundation, and UserNotifications.
                    """
                )

                Divider()

                // Ham Radio Community
                AcknowledgmentSection(
                    title: "The Amateur Radio Community",
                    description: """
                    Thank you to the worldwide amateur radio community for keeping Morse code \
                    alive. Whether you're a seasoned brass-pounder or just starting your CW \
                    journey, 73 and good luck!
                    """
                )

                Spacer(minLength: Theme.Spacing.lg)

                // Footer
                Text("73 de Koch Trainer")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(Theme.Spacing.lg)
        }
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - AcknowledgmentSection

private struct AcknowledgmentSection: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Typography.headline)

            Text(description)
                .font(Typography.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        AcknowledgmentsView()
    }
}
