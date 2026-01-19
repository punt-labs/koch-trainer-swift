import SwiftUI

/// Summary view shown after completing a QSO
struct QSOCompletedView: View {

    // MARK: Internal

    let result: QSOResult
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                // Success header
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.success)

                    Text("QSO Complete!")
                        .font(Typography.largeTitle)

                    Text("73 de \(result.theirCallsign)")
                        .font(Typography.headline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // QSO details card
                VStack(spacing: Theme.Spacing.md) {
                    detailRow(label: "Style", value: result.style.displayName)
                    detailRow(label: "Station", value: result.theirCallsign)
                    detailRow(label: "Operator", value: result.theirName)
                    detailRow(label: "QTH", value: result.theirQTH)
                    detailRow(label: "Duration", value: result.formattedDuration)
                    detailRow(label: "Exchanges", value: "\(result.exchangeCount)")
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(12)

                Spacer()

                // Transcript summary
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Transcript")
                        .font(Typography.headline)

                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            ForEach(result.transcript) { message in
                                HStack(alignment: .top) {
                                    Text(message.sender == .station ? "RX:" : "TX:")
                                        .font(Typography.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, alignment: .leading)

                                    Text(message.text)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(message.sender == .station ? Theme.Colors.primary : .primary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(12)

                Spacer()

                // Action buttons
                Button {
                    dismiss()
                    onDismiss()
                } label: {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Done")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(Theme.Spacing.lg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(Typography.body)
        }
    }
}

#Preview {
    let sampleResult = QSOResult(
        from: QSOState(
            style: .contest,
            myCallsign: "W5ABC",
            theirCallsign: "K0XYZ",
            theirName: "MIKE",
            theirQTH: "DENVER CO"
        )
    )

    return QSOCompletedView(result: sampleResult) {}
}
