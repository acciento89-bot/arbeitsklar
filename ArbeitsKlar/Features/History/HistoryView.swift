import SwiftUI

private enum HistorySheet: Identifiable {
    case edit(WorkSession)
    case pro

    var id: String {
        switch self {
        case let .edit(session):
            "edit-\(session.id)"
        case .pro:
            "pro"
        }
    }
}

@MainActor
struct HistoryView: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(PurchaseManager.self) private var purchases
    @Environment(AppTheme.self) private var theme
    @State private var presentedSheet: HistorySheet?

    var body: some View {
        Group {
            if store.completedSessions.isEmpty {
                ContentUnavailableView(
                    "history.empty.title",
                    systemImage: "clock.badge.questionmark",
                    description: Text("history.empty.description")
                )
                .background(theme.background)
            } else {
                List {
                    Section {
                        if purchases.isPro {
                            WeekSummaryCard(summary: store.currentWeekSummary())
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            Button {
                                presentedSheet = .pro
                            } label: {
                                ProHistoryTeaser()
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }

                    Section {
                        ForEach(store.completedSessions) { session in
                            Button {
                                openEditor(for: session)
                            } label: {
                                SessionRow(session: session)
                            }
                            .buttonStyle(.plain)
                                .listRowBackground(theme.elevatedBackground)
                                .swipeActions {
                                    Button {
                                        openEditor(for: session)
                                    } label: {
                                        Label("history.edit", systemImage: "pencil")
                                    }
                                    .tint(theme.accent)

                                    Button(role: .destructive) {
                                        store.deleteSession(id: session.id)
                                    } label: {
                                        Label("history.delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text("history.section.completed")
                    } footer: {
                        Text("history.footer")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(theme.background)
            }
        }
        .navigationTitle("history.title")
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case let .edit(session):
                EditSessionView(session: session)
            case .pro:
                ProView()
            }
        }
    }

    private func openEditor(for session: WorkSession) {
        presentedSheet = purchases.isPro ? .edit(session) : .pro
    }
}

private struct ProHistoryTeaser: View {
    @Environment(AppTheme.self) private var theme

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 48, height: 48)
                .background(theme.accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("history.pro.title")
                        .font(.headline)
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(theme.warning)
                }

                Text("history.pro.message")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(theme.secondaryLabel)
        }
        .padding(18)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("history.pro.hint")
    }
}

private struct WeekSummaryCard: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.locale) private var locale

    let summary: WorkPeriodSummary

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("history.week.kicker")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(theme.success)

                    Text("history.week.title")
                        .font(.title2.bold())
                }

                Spacer()

                Image(systemName: "calendar.badge.clock")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 42, height: 42)
                    .background(theme.accent.opacity(0.14), in: Circle())
            }

            if summary.isEmpty {
                Text("history.week.empty")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryLabel)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    WeekSummaryValue(
                        title: "history.week.work_time",
                        value: WorkDurationFormatter.string(from: summary.workDuration)
                    )
                    WeekSummaryValue(
                        title: "history.week.earnings",
                        value: summary.earnings.formatted(
                            .currency(code: summary.currencyCode).locale(locale)
                        )
                    )
                    WeekSummaryValue(
                        title: "history.week.breaks",
                        value: WorkDurationFormatter.string(from: summary.breakDuration)
                    )
                    WeekSummaryValue(
                        title: "history.week.overtime",
                        value: WorkDurationFormatter.string(from: summary.overtimeDuration)
                    )
                }
            }
        }
        .padding(20)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct WeekSummaryValue: View {
    @Environment(AppTheme.self) private var theme

    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(.caption)
                .foregroundStyle(theme.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct SessionRow: View {
    @Environment(AppTheme.self) private var theme

    let session: WorkSession

    var body: some View {
        let breakDuration = session.breakDuration()
        let overtime = session.overtime()

        HStack(spacing: 14) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 42, height: 42)
                .background(theme.accent.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(session.startedAt, format: .dateTime.weekday(.abbreviated).day().month())
                    .font(.headline)

                HStack(spacing: 5) {
                    Text(session.startedAt, format: .dateTime.hour().minute())
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    if let endedAt = session.endedAt {
                        Text(endedAt, format: .dateTime.hour().minute())
                    }
                    Text("history.separator")
                    Text(WorkDurationFormatter.string(from: session.duration()))
                }
                .font(.caption)
                .foregroundStyle(theme.secondaryLabel)

                if breakDuration > 0 || overtime > 0 {
                    HStack(spacing: 8) {
                        if breakDuration > 0 {
                            SessionStatPill(
                                title: "history.breaks",
                                value: WorkDurationFormatter.string(from: breakDuration),
                                systemImage: "cup.and.saucer.fill"
                            )
                        }

                        if overtime > 0 {
                            SessionStatPill(
                                title: "history.overtime",
                                value: WorkDurationFormatter.string(from: overtime),
                                systemImage: "clock.badge.exclamationmark"
                            )
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            Text(session.earnings(), format: .currency(code: session.currencyCode))
                .font(.headline.weight(.bold))
                .monospacedDigit()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct SessionStatPill: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String

    var body: some View {
        Label(value, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.white.opacity(0.07), in: Capsule())
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(value))
    }
}

#Preview("History") {
    NavigationStack {
        HistoryView()
    }
    .environment(WorkSessionStore.preview)
    .environment(PurchaseManager.previewPro)
    .environment(AppTheme())
    .preferredColorScheme(.dark)
}
