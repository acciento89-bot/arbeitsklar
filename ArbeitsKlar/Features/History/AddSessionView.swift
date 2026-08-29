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
    @State private var selectedTemplateID: UUID?
    @State private var title: String
    @State private var note: String
    @State private var tagsText: String
    private let payRules: PayRules
    @FocusState private var focusedField: Field?

    private enum Field {
        case rate
        case title
        case tags
        case note
    }

    init(profile: PayProfile) {
        let end = Date.now
        _endedAt = State(initialValue: end)
        _startedAt = State(initialValue: end.addingTimeInterval(-profile.plannedHours * 3_600 - 1_800))
        _hourlyRate = State(initialValue: profile.hourlyRate)
        _currencyCode = State(initialValue: profile.currencyCode)
        _plannedHours = State(initialValue: profile.plannedHours)
        _selectedTemplateID = State(initialValue: nil)
        _title = State(initialValue: "")
        _note = State(initialValue: "")
        _tagsText = State(initialValue: "")
        payRules = profile.payRules
    }

    var body: some View {
        NavigationStack {
            Form {
                if !store.shiftTemplates.isEmpty {
                    Section("templates.apply.section") {
                        Picker("templates.apply", selection: $selectedTemplateID) {
                            Text("templates.apply.none").tag(Optional<UUID>.none)
                            ForEach(store.shiftTemplates) { template in
                                Text(template.name).tag(Optional(template.id))
                            }
                        }
                    }
                }

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
                            .focused($focusedField, equals: .rate)
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

                Section {
                    TextField("session.title.placeholder", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .focused($focusedField, equals: .title)
                    TextField("session.tags.placeholder", text: $tagsText)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .tags)
                    TextField("session.note.placeholder", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .note)
                } header: {
                    Text("session.section.details")
                } footer: {
                    Text("session.tags.help")
                }

                Section("edit.section.preview") {
                    LabeledContent("edit.work_time") {
                        Text(WorkDurationFormatter.string(from: adjustedWorkDuration)).monospacedDigit()
                    }
                    LabeledContent("edit.earnings") {
                        Text(previewBreakdown.totalEarnings, format: .currency(code: currencyCode))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    }

                    if previewBreakdown.premiumEarnings > 0 {
                        LabeledContent("earnings.premiums") {
                            Text(previewBreakdown.premiumEarnings, format: .currency(code: currencyCode))
                                .monospacedDigit()
                        }
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
                    Button("common.done") { focusedField = nil }
                }
            }
            .onChange(of: startedAt) { clampBreakDuration() }
            .onChange(of: endedAt) { clampBreakDuration() }
            .onChange(of: selectedTemplateID) { applySelectedTemplate() }
        }
    }

    private var totalDuration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }
    private var adjustedWorkDuration: TimeInterval { max(0, totalDuration - TimeInterval(breakMinutes * 60)) }
    private var maximumBreakMinutes: Int { max(0, Int(totalDuration / 60) - 1) }
    private var isValid: Bool { endedAt > startedAt && hourlyRate > 0 && plannedHours > 0 && adjustedWorkDuration >= 60 }

    private var previewBreakdown: EarningsBreakdown {
        let breakStart = startedAt.addingTimeInterval(max(0, (totalDuration - TimeInterval(breakMinutes * 60)) / 2))
        let previewBreaks = breakMinutes > 0
            ? [WorkBreak(startedAt: breakStart, endedAt: breakStart.addingTimeInterval(TimeInterval(breakMinutes * 60)))]
            : []
        let previewSession = WorkSession(
            startedAt: startedAt,
            endedAt: endedAt,
            hourlyRate: hourlyRate,
            currencyCode: currencyCode,
            plannedHours: plannedHours,
            breaks: previewBreaks,
            payRules: payRules,
            title: title,
            note: note,
            tags: parsedTags
        )
        return previewSession.earningsBreakdown()
    }

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
            plannedHours: plannedHours,
            payRules: payRules,
            title: title,
            note: note,
            tags: parsedTags
        ) {
            dismiss()
        }
    }

    private var parsedTags: [String] {
        ShiftTemplate.normalizedTags(tagsText.split(separator: ",").map(String.init))
    }

    private func applySelectedTemplate() {
        guard
            let selectedTemplateID,
            let template = store.shiftTemplates.first(where: { $0.id == selectedTemplateID })
        else { return }

        let templateStart = template.startDate(on: startedAt)
        startedAt = templateStart
        plannedHours = template.plannedHours
        breakMinutes = template.breakMinutes
        endedAt = templateStart.addingTimeInterval(
            template.plannedHours * 3_600 + TimeInterval(template.breakMinutes * 60)
        )
        title = template.name
        note = template.note
        tagsText = template.tags.joined(separator: ", ")
        clampBreakDuration()
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
