import SwiftUI

private enum ReminderLead: Int, CaseIterable, Identifiable {
    case atStart = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case oneDay = 1_440

    var id: Int { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .atStart: "planner.reminder.at_start"
        case .fiveMinutes: "planner.reminder.5_minutes"
        case .fifteenMinutes: "planner.reminder.15_minutes"
        case .thirtyMinutes: "planner.reminder.30_minutes"
        case .oneHour: "planner.reminder.1_hour"
        case .twoHours: "planner.reminder.2_hours"
        case .oneDay: "planner.reminder.1_day"
        }
    }
}

@MainActor
struct ScheduledShiftEditor: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    private let shiftID: UUID
    @State private var startsAt: Date
    @State private var plannedHours: Double
    @State private var breakMinutes: Int
    @State private var title: String
    @State private var note: String
    @State private var tagsText: String
    @State private var selectedTemplateID: UUID?
    @State private var reminderEnabled: Bool
    @State private var reminderLead: ReminderLead
    @State private var showsDeleteConfirmation = false
    @State private var showsPermissionAlert = false
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case tags
        case note
    }

    init(shift: ScheduledShift) {
        shiftID = shift.id
        _startsAt = State(initialValue: shift.startsAt)
        _plannedHours = State(initialValue: shift.plannedHours)
        _breakMinutes = State(initialValue: shift.breakMinutes)
        _title = State(initialValue: shift.title)
        _note = State(initialValue: shift.note)
        _tagsText = State(initialValue: shift.tags.joined(separator: ", "))
        _selectedTemplateID = State(initialValue: shift.templateID)
        _reminderEnabled = State(initialValue: shift.reminderMinutesBefore != nil)
        _reminderLead = State(
            initialValue: ReminderLead(rawValue: shift.reminderMinutesBefore ?? 15) ?? .fifteenMinutes
        )
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

                Section("planner.section.time") {
                    DatePicker(
                        "planner.starts_at",
                        selection: $startsAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Stepper(value: $plannedHours, in: 1...16, step: 0.5) {
                        LabeledContent("settings.planned_shift") {
                            Text(plannedHours, format: .number.precision(.fractionLength(0...1)))
                            Text("unit.hours")
                        }
                    }

                    Stepper(value: $breakMinutes, in: 0...240, step: 5) {
                        LabeledContent("edit.break") {
                            Text(breakMinutes, format: .number)
                            Text("unit.minutes")
                        }
                    }

                    LabeledContent("planner.ends_at") {
                        Text(previewShift.endsAt, format: .dateTime.weekday(.abbreviated).hour().minute())
                            .foregroundStyle(theme.secondaryLabel)
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

                Section {
                    Toggle("planner.reminder.toggle", isOn: $reminderEnabled)
                    if reminderEnabled {
                        Picker("planner.reminder.lead", selection: $reminderLead) {
                            ForEach(ReminderLead.allCases) { lead in
                                Text(lead.title).tag(lead)
                            }
                        }
                    }
                } header: {
                    Text("planner.section.reminder")
                } footer: {
                    Text("planner.reminder.note")
                }

                if isExistingShift {
                    Section {
                        Button("planner.delete", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle(isExistingShift ? "planner.edit_title" : "planner.new_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done") { focusedField = nil }
                }
            }
            .onChange(of: selectedTemplateID) { applySelectedTemplate() }
            .confirmationDialog(
                "planner.delete.title",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("planner.delete", role: .destructive) {
                    store.deleteScheduledShift(id: shiftID)
                    dismiss()
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("planner.delete.message")
            }
            .alert("planner.permission.title", isPresented: $showsPermissionAlert) {
                Button("common.ok") { dismiss() }
            } message: {
                Text("planner.permission.message")
            }
        }
    }

    private var isExistingShift: Bool {
        store.scheduledShifts.contains { $0.id == shiftID }
    }

    private var parsedTags: [String] {
        ShiftTemplate.normalizedTags(tagsText.split(separator: ",").map(String.init))
    }

    private var previewShift: ScheduledShift {
        ScheduledShift(
            id: shiftID,
            startsAt: startsAt,
            plannedHours: plannedHours,
            breakMinutes: breakMinutes,
            title: title,
            note: note,
            tags: parsedTags,
            reminderMinutesBefore: reminderEnabled ? reminderLead.rawValue : nil,
            templateID: selectedTemplateID
        )
    }

    private func applySelectedTemplate() {
        guard
            let selectedTemplateID,
            let template = store.shiftTemplates.first(where: { $0.id == selectedTemplateID })
        else { return }

        startsAt = template.startDate(on: startsAt)
        plannedHours = template.plannedHours
        breakMinutes = template.breakMinutes
        title = template.name
        note = template.note
        tagsText = template.tags.joined(separator: ", ")
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        let reminderSucceeded = await store.saveScheduledShift(previewShift)
        isSaving = false
        if reminderEnabled, !reminderSucceeded {
            showsPermissionAlert = true
        } else {
            dismiss()
        }
    }
}

#Preview {
    ScheduledShiftEditor(
        shift: ScheduledShift(
            startsAt: .now.addingTimeInterval(86_400),
            plannedHours: 8,
            breakMinutes: 30,
            title: "Service",
            tags: ["Service"],
            reminderMinutesBefore: 15
        )
    )
    .environment(WorkSessionStore.preview)
    .environment(AppTheme())
    .preferredColorScheme(.dark)
}
