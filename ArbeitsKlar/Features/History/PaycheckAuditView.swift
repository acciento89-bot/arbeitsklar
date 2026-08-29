import SwiftUI

@MainActor
struct PaycheckAuditView: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    let month: Date

    @State private var actualGross = 0.0
    @State private var note = ""
    @State private var didLoad = false
    @State private var showsDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(month, format: .dateTime.month(.wide).year())
                                    .font(.title2.bold())
                                Text("paycheck.subtitle")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.secondaryLabel)
                            }
                            Spacer()
                            Image(systemName: difference < 0 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(difference < 0 ? theme.warning : theme.success)
                        }

                        comparisonGrid
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    LabeledContent("paycheck.actual") {
                        HStack(spacing: 5) {
                            TextField(
                                "paycheck.actual",
                                value: $actualGross,
                                format: .number.precision(.fractionLength(2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                            Text(currencyCode)
                                .foregroundStyle(theme.secondaryLabel)
                        }
                    }

                    TextField("paycheck.note", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("paycheck.section.statement")
                } footer: {
                    Text("paycheck.note.help")
                }

                Section {
                    Label("paycheck.privacy", systemImage: "lock.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryLabel)
                    Text("paycheck.disclaimer")
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryLabel)
                }

                if existingAudit != nil {
                    Section {
                        Button("paycheck.delete", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("paycheck.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .disabled(actualGross <= 0)
                }
            }
            .task { loadOnce() }
            .confirmationDialog(
                "paycheck.delete.title",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("paycheck.delete", role: .destructive) { deleteAudit() }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("paycheck.delete.message")
            }
        }
    }

    private var currencyCode: String { store.profile.currencyCode }
    private var expectedGross: Double {
        store.expectedEarnings(forMonthContaining: month, currencyCode: currencyCode)
    }
    private var difference: Double { actualGross - expectedGross }
    private var existingAudit: PaycheckAudit? {
        store.paycheckAudit(forMonthContaining: month, currencyCode: currencyCode)
    }

    private var comparisonGrid: some View {
        let differenceTitle: LocalizedStringKey = difference < 0 ? "paycheck.missing" : "paycheck.difference"
        let statusTitle: LocalizedStringKey = difference < -0.01 ? "paycheck.status.check" : "paycheck.status.ok"

        Grid(horizontalSpacing: 20, verticalSpacing: 12) {
            GridRow {
                comparisonValue("paycheck.expected", amount: expectedGross, color: .primary)
                comparisonValue("paycheck.actual", amount: actualGross, color: .primary)
            }
            GridRow {
                comparisonValue(
                    differenceTitle,
                    amount: abs(difference),
                    color: difference < 0 ? theme.warning : theme.success
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("paycheck.status")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryLabel)
                    Text(statusTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(difference < -0.01 ? theme.warning : theme.success)
                }
            }
        }
    }

    private func comparisonValue(
        _ title: LocalizedStringKey,
        amount: Double,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.secondaryLabel)
            Text(amount, format: .currency(code: currencyCode))
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadOnce() {
        guard !didLoad else { return }
        didLoad = true
        if let audit = existingAudit {
            actualGross = audit.actualGross
            note = audit.note
        }
    }

    private func save() {
        store.savePaycheckAudit(
            forMonthContaining: month,
            actualGross: actualGross,
            currencyCode: currencyCode,
            note: note
        )
        dismiss()
    }

    private func deleteAudit() {
        store.deletePaycheckAudit(forMonthContaining: month, currencyCode: currencyCode)
        dismiss()
    }
}
