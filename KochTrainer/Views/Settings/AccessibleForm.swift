import SwiftUI

// MARK: - AccessibleForm

/// A Form-like container that uses VStack instead of List to avoid
/// lazy loading issues with VoiceOver. All elements are rendered
/// immediately, allowing VoiceOver to navigate smoothly.
struct AccessibleForm<Content: View>: View {

    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content
            }
        }
        .accessibilityElement(children: .contain)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - AccessibleSection

/// A section container styled like Form sections.
struct AccessibleSection<Content: View>: View {

    // MARK: Lifecycle

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    // MARK: Internal

    let title: String?
    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title.uppercased())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(spacing: 0) {
                content
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

// MARK: - AccessibleRow

/// A row styled like Form rows with separator support.
struct AccessibleRow<Content: View>: View {

    // MARK: Lifecycle

    init(showDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.showDivider = showDivider
        self.content = content()
    }

    // MARK: Internal

    let showDivider: Bool
    let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 12)

            if showDivider {
                Divider()
                    .padding(.leading)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AccessibleForm {
            AccessibleSection("Section One") {
                AccessibleRow { Text("Row 1") }
                AccessibleRow { Text("Row 2") }
                AccessibleRow(showDivider: false) { Text("Row 3") }
            }

            AccessibleSection("Section Two") {
                AccessibleRow { Toggle("Option", isOn: .constant(true)) }
                AccessibleRow(showDivider: false) {
                    TextField("Text", text: .constant(""))
                }
            }
        }
        .navigationTitle("Test")
    }
}
