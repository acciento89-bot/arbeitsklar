import SwiftUI

@MainActor
struct ShiftTemplatesView: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme
    @State private var editedTemplate: ShiftTemplate?

    var body: some View {
        Group {
            if store.shiftTemplates.isEmpty {
                ContentUnavailableView(
                    "templates.empty.title",
                    systemImage: "calendar.badge.plus",
                    description: Text("templates.empty.message")
                )
            } else {
                List {
                    ForEach(store.shiftTemplates) { template in
                        Button {
                            editedTemplate = template
                        } label: {
                            ShiftTemplateRow(template: template)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(theme.elevatedBackground)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.deleteShiftTemplate(id: template.id)
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(theme.background)
        .navigationTitle("templates.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editedTemplate = ShiftTemplate(
                        name: "",
                        plannedHours: store.profile.plannedHours
                    )
                } label: {
                    Label("templates.add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editedTemplate) { template in
            ShiftTemplateEditor(template: template)
        }
    }
}

private struct ShiftTemplateRow: View {
    @Environment(AppTheme.self) private var theme
    let template: ShiftTemplate

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.headline)
                .foregroundStyle(theme.accent)
                .frame(width: 42, height: 42)
                .background(theme.accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(template.name)
                    .font(.headline)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { metadata(template: template) }
                    VStack(alignment: .leading, spacing: 4) { metadata(template: template) }
                }
                .font(.caption)
                .foregroundStyle(theme.secondaryLabel)

                if !template.tags.isEmpty {
                    Text(template.tags.map { "#\($0)" }.formatted())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.success)
                        .lineLimit(1)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(theme.secondaryLabel)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func metadata(template: ShiftTemplate) -> some View {
        Label {
            Text(templateTime(template), style: .time)
        } icon: {
            Image(systemName: "clock")
        }
        Label {
            Text(template.plannedHours, format: .number.precision(.fractionLength(0...1)))
            Text("unit.hours")
        } icon: {
            Image(systemName: "timer")
        }
        Label {
            Text(template.breakMinutes, format: .number)
            Text("unit.minutes")
        } icon: {
            Image(systemName: "cup.and.saucer")
        }
    }

    private func templateTime(_ template: ShiftTemplate) -> Date {
        template.startDate(on: .now)
    }
}

@MainActor
private struct ShiftTemplateEditor: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    private let templateID: UUID
    @State private var name: String
    @State private var startTime: Date
    @State private var plannedHours: Double
    @State private var breakMinutes: Int
    @State private var note: String
    @State private var tagsText: String
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case tags
        case note
    }

    init(template: ShiftTemplate) {
        templateID = template.id
        _name = State(initialValue: template.name)
        _startTime = State(initialValue: template.startDate(on: .now))
        _plannedHours = State(initialValue: template.plannedHours)
        _breakMinutes = State(initialValue: template.breakMinutes)
        _note = State(initialValue: template.note)
        _tagsText = State(initialValue: template.tags.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("templates.section.details") {
                    TextField("templates.name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)

                    DatePicker(
                        "templates.start_time",
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
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
                }

                Section {
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
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle(name.isEmpty ? "templates.new_title" : "templates.edit_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .disabled(trimmedName.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done") { focusedField = nil }
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedTags: [String] {
        ShiftTemplate.normalizedTags(tagsText.split(separator: ",").map(String.init))
    }

    private func save() {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: startTime)
        store.saveShiftTemplate(
            ShiftTemplate(
                id: templateID,
                name: trimmedName,
                startHour: components.hour ?? 0,
                startMinute: components.minute ?? 0,
                plannedHours: plannedHours,
                breakMinutes: breakMinutes,
                note: note,
                tags: parsedTags
            )
        )
        dismiss()
    }
}

#Preview {
    NavigationStack { ShiftTemplatesView() }
        .environment(WorkSessionStore.preview)
        .environment(AppTheme())
        .preferredColorScheme(.dark)
}
