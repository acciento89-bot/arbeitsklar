import SwiftUI

@MainActor
struct CyclePlannerView: View {
    @Environment(WorkSessionStore.self) private var store
    @State private var selected: ShiftCycle?
    @State private var ending: ShiftCycle?
    @State private var error = false

    var body: some View {
        List {
            Section {
                Button { selected = newCycle() } label: {
                    Label("cycle.create", systemImage: "calendar.badge.plus")
                }
                Text("cycle.intro").font(.subheadline).foregroundStyle(.secondary)
            }
            Section("cycle.saved") {
                if store.shiftCycles.isEmpty { Text("cycle.empty").foregroundStyle(.secondary) }
                ForEach(store.shiftCycles) { cycle in
                    Button { selected = cycle } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(cycle.name).font(.headline)
                            Text(cycle.anchorDate...cycle.endDate).font(.caption)
                            Text(cycle.timeZoneIdentifier).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("cycle.end", role: .destructive) { ending = cycle }
                    }
                }
            }
        }
        .navigationTitle("cycle.title")
        .sheet(item: $selected) { CycleEditorView(cycle: $0) }
        .confirmationDialog("cycle.end", isPresented: Binding(
            get: { ending != nil }, set: { if !$0 { ending = nil } }
        ), titleVisibility: .visible) {
            Button("cycle.end", role: .destructive) {
                guard let id = ending?.id else { return }
                do { try store.endCycle(id: id) } catch { self.error = true }
                ending = nil
            }
            Button("common.cancel", role: .cancel) { ending = nil }
        } message: { Text("cycle.end.message") }
        .alert("cycle.error.title", isPresented: $error) {
            Button("common.ok", role: .cancel) {}
        } message: { Text("cycle.error.save") }
    }

    private func newCycle() -> ShiftCycle {
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: .now)
        let template = store.shiftTemplates.first ?? ShiftTemplate(
            name: String(localized: "cycle.default_shift"), startHour: 8, startMinute: 0,
            plannedHours: store.profile.plannedHours, breakMinutes: 30
        )
        return ShiftCycle(
            name: String(localized: "cycle.default_name"), anchorDate: start,
            endDate: calendar.date(byAdding: .day, value: 27, to: start) ?? start,
            dayTemplates: [template, template, template, template, template, nil, nil]
        )
    }
}

@MainActor
struct CycleEditorView: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var draft: ShiftCycle
    @State private var preview: ShiftCyclePreview?
    @State private var skipsConflicts = false
    @State private var errorKey: String?

    init(cycle: ShiftCycle) { _draft = State(initialValue: cycle) }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: draft.timeZoneIdentifier) ?? .current
        return value
    }
    private var choices: [ShiftTemplate] {
        var result: [ShiftTemplate] = []
        for template in draft.dayTemplates.compactMap({ $0 }) + store.shiftTemplates {
            if !result.contains(where: { $0.id == template.id }) { result.append(template) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("cycle.details") {
                    TextField("cycle.name", text: $draft.name)
                    DatePicker("cycle.from", selection: $draft.anchorDate, displayedComponents: .date)
                    DatePicker("cycle.through", selection: $draft.endDate, displayedComponents: .date)
                    LabeledContent("cycle.time_zone", value: draft.timeZoneIdentifier)
                    Text("cycle.range_hint").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Stepper(value: Binding(
                        get: { draft.dayTemplates.count / 7 },
                        set: { count in
                            let size = count * 7
                            draft.dayTemplates = Array(draft.dayTemplates.prefix(size)) +
                                Array(repeating: nil, count: max(0, size - draft.dayTemplates.count))
                        }
                    ), in: 1...4) {
                        LabeledContent("cycle.weeks", value: "\(draft.dayTemplates.count / 7)")
                    }
                    Text("cycle.pattern_hint").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(0..<(draft.dayTemplates.count / 7), id: \.self) { week in
                    Section {
                        ForEach(0..<7, id: \.self) { day in
                            slotPicker(index: week * 7 + day)
                        }
                    } header: {
                        Text("cycle.week") + Text(" \(week + 1)")
                    }
                }
                Section {
                    Button("cycle.preview") { refreshPreview() }
                    Text("cycle.replace_hint").font(.caption).foregroundStyle(.secondary)
                }
                if let preview {
                    previewSection(preview)
                }
            }
            .environment(\.timeZone, calendar.timeZone)
            .navigationTitle("cycle.editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("cycle.apply") { apply() }
                        .disabled(preview == nil || applicableCount == 0 ||
                                  (!skipsConflicts && !(preview?.conflictingShiftIDs.isEmpty ?? true)))
                }
            }
            .onChange(of: draft) { _, _ in preview = nil; skipsConflicts = false }
            .alert("cycle.error.title", isPresented: Binding(
                get: { errorKey != nil }, set: { if !$0 { errorKey = nil } }
            )) { Button("common.ok", role: .cancel) { errorKey = nil } }
            message: { Text(LocalizedStringKey(errorKey ?? "cycle.error.save")) }
        }
    }

    private var applicableCount: Int {
        guard let preview else { return 0 }
        return skipsConflicts ? preview.nonconflictingShifts.count : preview.shifts.count
    }

    private var weekdayFormat: Date.FormatStyle {
        var format = Date.FormatStyle.dateTime.weekday(.wide).locale(locale)
        format.calendar = calendar
        format.timeZone = calendar.timeZone
        return format
    }

    private func slotPicker(index: Int) -> some View {
        let date = calendar.date(byAdding: .day, value: index, to: draft.anchorDate) ?? draft.anchorDate
        return Picker(selection: Binding<UUID?>(
            get: { draft.dayTemplates[index]?.id },
            set: { id in draft.dayTemplates[index] = choices.first { $0.id == id } }
        )) {
            Text("cycle.rest").tag(Optional<UUID>.none)
            ForEach(choices) { template in Text(template.name).tag(Optional(template.id)) }
        } label: {
            Text(date, format: weekdayFormat)
        }
    }

    private func previewSection(_ value: ShiftCyclePreview) -> some View {
        Section {
            LabeledContent("cycle.count", value: "\(value.shifts.count)")
            LabeledContent("cycle.conflicts", value: "\(value.conflictingShiftIDs.count)")
            if !value.conflictingShiftIDs.isEmpty {
                Toggle("cycle.skip", isOn: $skipsConflicts)
            }
            if value.shifts.isEmpty { Text("cycle.error.no_future").foregroundStyle(.secondary) }
            ForEach(value.shifts) { shift in
                VStack(alignment: .leading, spacing: 4) {
                    Text(shift.startsAt, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
                    Text(shift.title).font(.subheadline)
                    if value.conflictingShiftIDs.contains(shift.id) {
                        Label("cycle.conflict", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        } header: { Text("cycle.preview") }
    }

    private func refreshPreview() {
        do { preview = try store.previewCycle(draft) }
        catch { errorKey = key(for: error) }
    }
    private func apply() {
        do { try store.applyCycle(draft, skipConflicts: skipsConflicts); dismiss() }
        catch { errorKey = key(for: error); refreshPreview() }
    }
    private func key(for error: Error) -> String {
        switch error as? ShiftCycleError {
        case .conflicts: return "cycle.error.conflicts"
        case .noFutureShifts: return "cycle.error.no_future"
        case .emptyName: return "cycle.error.name"
        case .noWorkDays: return "cycle.error.no_work"
        case .invalidDateRange, .rangeTooLong: return "cycle.error.range"
        default: return "cycle.error.save"
        }
    }
}
