import SwiftUI

@MainActor
struct PayRulesView: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                Section {
                    LabeledContent("payrules.overtime") {
                        HStack(spacing: 5) {
                            TextField(
                                "payrules.overtime",
                                value: $store.profile.payRules.overtimeMultiplier,
                                format: .number.precision(.fractionLength(0...2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                            Text("payrules.multiplier")
                                .foregroundStyle(theme.secondaryLabel)
                        }
                    }

                    LabeledContent("payrules.night_bonus") {
                        percentageTextField(value: $store.profile.payRules.nightBonusPercent)
                            .accessibilityLabel("payrules.night_bonus")
                    }
                    LabeledContent("payrules.weekend_bonus") {
                        percentageTextField(value: $store.profile.payRules.weekendBonusPercent)
                            .accessibilityLabel("payrules.weekend_bonus")
                    }
                } header: {
                    Text("payrules.section.premiums")
                } footer: {
                    Text("payrules.premiums.note")
                }

                Section {
                    Picker("payrules.night_start", selection: $store.profile.payRules.nightStartHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }

                    Picker("payrules.night_end", selection: $store.profile.payRules.nightEndHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }
                } header: {
                    Text("payrules.section.night")
                } footer: {
                    Text("payrules.night.note")
                }

                Section {
                    Button("payrules.reset", role: .destructive) {
                        store.profile.payRules = .none
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("payrules.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .onDisappear { normalizeRules() }
        }
    }

    private func percentageTextField(value: Binding<Double>) -> some View {
        HStack(spacing: 5) {
            TextField("", value: value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text("%")
                .foregroundStyle(theme.secondaryLabel)
        }
    }

    private func normalizeRules() {
        store.profile.payRules.overtimeMultiplier = max(1, store.profile.payRules.overtimeMultiplier)
        store.profile.payRules.nightBonusPercent = max(0, store.profile.payRules.nightBonusPercent)
        store.profile.payRules.weekendBonusPercent = max(0, store.profile.payRules.weekendBonusPercent)
    }

    private func hourLabel(_ hour: Int) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

#Preview("Pay rules") {
    PayRulesView()
        .environment(WorkSessionStore.preview)
        .environment(AppTheme())
        .preferredColorScheme(.dark)
}
