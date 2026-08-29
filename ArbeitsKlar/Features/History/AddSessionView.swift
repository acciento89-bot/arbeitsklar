import SwiftUI

@MainActor
struct AddSessionView: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var breakMinutes: Int = 30
    @State private var hourlyRate: Double
    @State private var currencyCode: String
    @State private var plannedHours: Double
    @FocusState private var isRateFocused: Bool

    init(profile: PayProfile) {
        let end = Date.now
        _endedAt = State(initialValue: end)
        _startedAt = State(initialValue: end.addingTimeInterval(-profile.plannedHours * 3_600 - 1_800))
        _hourlyRate = State(initialValue: profile.hourlyRate)
        _currencyCode = State(initialValue: profile.currencyCode)
        _plannedHours = State(initialValue: profile.plannedHours)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("edit.section.time") {
                    DatePicker("edit.start", selection: $startedAt, in: ...endedAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("edit.end", selection: $endedAt, in: startedAt..., displayedComponents: [.date, .hourAndMinute])

                    Stepper(value: $breakMinutes, in: 0...maximumBreakMinutes) {
                        LabeledContent("edit.break") {
                            HStack(spacing: 4) {
                                Text(breakMinutes, format: .number)
                                Text("unit.minutes")
                            }
                            .monospacedDigit()
                        }
                    }
                }

                Section("edit.section.pay") {
                    LabeledContent("settings.hourly_rate") {
                        TextField("settings.hourly_rate", value: $hourlyRate, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isRateFocused)
                            .frame(maxWidth: 120)
                    }

                    Picker("settings.currency", selection: $currencyCode) {
                        ForEach(PayProfile.supportedCurrencyCodes, id: \.self) { code in
                            Text(currencyName(for: code)).tag(code)
                        }
                    }

                    Stepper(value: $plannedHours, in: 1...16, step: 0.5) {
                        LabeledContent("settings.planned_shift") {
                            HStack(spacing: 4) {
                                Text(plannedHours, format: .number.precision(.fractionLength(0...1)))
                                Text("unit.hours")
                            }
                            .monospacedDigit()
                        }
                    }
                }

                Section("edit.section.preview") {
                    LabeledContent("edit.work_time") {
                        Text(WorkDurationFormatter.string(from: adjustedWorkDuration)).monospacedDigit()
                    }
                    LabeledContent("edit.earnings") {
                        Text(
                            EarningsCalculator.earnings(hourlyRate: hourlyRate, elapsedTime: adjustedWorkDuration),
                            format: .currency(code: currencyCode)
                        )
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("add.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }.disabled(!isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done") { isRateFocused = false }
                }
            }
            .onChange(of: startedAt) { clampBreakDuration() }
            .onChange(of: endedAt) { clampBreakDuration() }
        }
    }

    private var totalDuration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }
    private var adjustedWorkDuration: TimeInterval { max(0, totalDuration - TimeInterval(breakMinutes * 60)) }
    private var maximumBreakMinutes: Int { max(0, Int(totalDuration / 60) - 1) }
    private var isValid: Bool { endedAt > startedAt && hourlyRate > 0 && plannedHours > 0 && adjustedWorkDuration >= 60 }

    private func clampBreakDuration() {
        breakMinutes = min(breakMinutes, maximumBreakMinutes)
    }

    private func save() {
        guard isValid else { return }
        if store.addCompletedSession(
            startedAt: startedAt,
            endedAt: endedAt,
            breakDuration: TimeInterval(breakMinutes * 60),
            hourlyRate: hourlyRate,
            currencyCode: currencyCode,
            plannedHours: plannedHours
        ) {
            dismiss()
        }
    }

    private func currencyName(for code: String) -> String {
        guard let name = Locale.autoupdatingCurrent.localizedString(forCurrencyCode: code) else { return code }
        return "\(code) · \(name)"
    }
}

#Preview("Add shift") {
    AddSessionView(profile: .defaultValue)
        .environment(WorkSessionStore.preview)
        .environment(AppTheme())
        .preferredColorScheme(.dark)
}
