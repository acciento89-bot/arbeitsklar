import SwiftUI

private enum PlannerSheet: Identifiable {
    case add(Date)
    case edit(ScheduledShift)

    var id: String {
        switch self {
        case let .add(date): "add-\(date.timeIntervalSinceReferenceDate)"
        case let .edit(shift): "edit-\(shift.id)"
        }
    }
}

@MainActor
struct PlannerView: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme
    @Environment(\.locale) private var locale
    @State private var visibleMonth = Date.now
    @State private var selectedDate = Date.now
    @State private var presentedSheet: PlannerSheet?

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                monthCard
                agenda
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("planner.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentedSheet = .add(defaultStartDate(for: selectedDate))
                } label: {
                    Label("planner.add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case let .add(date):
                ScheduledShiftEditor(
                    shift: ScheduledShift(
                        startsAt: date,
                        plannedHours: store.profile.plannedHours
                    )
                )
            case let .edit(shift):
                ScheduledShiftEditor(shift: shift)
            }
        }
    }

    private var monthCard: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 38, height: 34)
                }
                .accessibilityLabel("planner.previous_month")

                Spacer()
                Text(visibleMonth, format: .dateTime.month(.wide).year().locale(locale))
                    .font(.title3.bold())
                Spacer()

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 38, height: 34)
                }
                .accessibilityLabel("planner.next_month")
            }
            .foregroundStyle(theme.accent)

            LazyVGrid(columns: calendarColumns, spacing: 10) {
                ForEach(weekdayLabels) { weekday in
                    Text(weekday.symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.secondaryLabel)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthDates, id: \.self) { date in
                    calendarDay(date)
                }
            }
        }
        .padding(18)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("planner.agenda")
                        .font(.title2.bold())
                    Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryLabel)
                }
                Spacer()
                Button {
                    presentedSheet = .add(defaultStartDate(for: selectedDate))
                } label: {
                    Label("planner.add_short", systemImage: "plus.circle.fill")
                }
                .font(.subheadline.weight(.semibold))
            }

            if selectedShifts.isEmpty {
                ContentUnavailableView(
                    "planner.empty.title",
                    systemImage: "calendar.badge.plus",
                    description: Text("planner.empty.message")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                ForEach(selectedShifts) { shift in
                    ScheduledShiftCard(
                        shift: shift,
                        canStart: store.activeSession == nil,
                        onEdit: { presentedSheet = .edit(shift) },
                        onStart: { Task { await store.startShift(from: shift) } }
                    )
                }
            }
        }
    }

    private var selectedShifts: [ScheduledShift] {
        store.scheduledShifts(on: selectedDate)
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    }

    private var monthDates: [Date] {
        guard
            let month = calendar.dateInterval(of: .month, for: visibleMonth),
            let gridStart = calendar.dateInterval(of: .weekOfYear, for: month.start)?.start
        else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private var weekdayLabels: [WeekdayLabel] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { offset in
            let weekday = ((calendar.firstWeekday - 1 + offset) % 7) + 1
            return WeekdayLabel(weekday: weekday, symbol: symbols[weekday - 1])
        }
    }

    private func calendarDay(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isVisibleMonth = calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month)
        let hasShifts = !store.scheduledShifts(on: date).isEmpty

        return Button {
            selectedDate = date
            if !isVisibleMonth {
                visibleMonth = date
            }
        } label: {
            VStack(spacing: 4) {
                Text(date, format: .dateTime.day())
                    .font(.subheadline.weight(isSelected ? .bold : .medium))
                Circle()
                    .fill(hasShifts ? theme.success : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .foregroundStyle(isSelected ? .white : isVisibleMonth ? .primary : theme.secondaryLabel.opacity(0.55))
            .background(isSelected ? theme.accent : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                if isToday, !isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.accent.opacity(0.7), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(locale)))
        .accessibilityValue(hasShifts ? Text("planner.day.has_shifts") : Text("planner.day.empty"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func moveMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        visibleMonth = next
        selectedDate = calendar.dateInterval(of: .month, for: next)?.start ?? next
    }

    private func defaultStartDate(for date: Date) -> Date {
        if calendar.isDateInToday(date), Date.now > date {
            return Date.now.addingTimeInterval(300)
        }
        if let template = store.shiftTemplates.first {
            return template.startDate(on: date)
        }
        return calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? date
    }
}

private struct WeekdayLabel: Identifiable {
    let weekday: Int
    let symbol: String
    var id: Int { weekday }
}

private struct ScheduledShiftCard: View {
    @Environment(AppTheme.self) private var theme
    let shift: ScheduledShift
    let canStart: Bool
    let onEdit: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shift.title.isEmpty ? String(localized: "planner.untitled") : shift.title)
                        .font(.headline)
                    HStack(spacing: 5) {
                        Text(shift.startsAt, format: .dateTime.hour().minute())
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                        Text(shift.endsAt, format: .dateTime.hour().minute())
                        Text("history.separator")
                        Text(shift.plannedHours, format: .number.precision(.fractionLength(0...1)))
                        Text("unit.hours")
                    }
                    .font(.caption)
                    .foregroundStyle(theme.secondaryLabel)
                }

                Spacer()
                if shift.isPast() {
                    Text("planner.missed")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.warning)
                } else if shift.reminderMinutesBefore != nil {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(theme.success)
                        .accessibilityLabel("planner.reminder.enabled")
                }
            }

            if !shift.tags.isEmpty {
                Text(shift.tags.map { "#\($0)" }.joined(separator: "  "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.success)
                    .lineLimit(1)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { actions }
                VStack(spacing: 10) { actions }
            }
        }
        .padding(17)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var actions: some View {
        Button(action: onEdit) {
            Label("common.edit", systemImage: "pencil")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        Button(action: onStart) {
            Label("planner.start_now", systemImage: "play.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canStart)
    }
}

#Preview {
    NavigationStack { PlannerView() }
        .environment(WorkSessionStore.preview)
        .environment(AppTheme())
        .preferredColorScheme(.dark)
}
