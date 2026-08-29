import SwiftUI
import UniformTypeIdentifiers

private enum HistorySheet: Identifiable {
    case add
    case edit(WorkSession)
    case paycheck(Date)
    case pro

    var id: String {
        switch self {
        case .add:
            "add"
        case let .edit(session):
            "edit-\(session.id)"
        case let .paycheck(month):
            "paycheck-\(month.timeIntervalSinceReferenceDate)"
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
    @State private var exportDocument = WorkSessionCSVDocument()
    @State private var showsExporter = false
    @State private var showsExportError = false
    @State private var selectedPeriod: HistoryPeriod = .month
    @State private var referenceDate = Date.now
    @State private var filteredSessions: [WorkSession] = []
    @State private var searchQuery = ""

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
                            HistoryInsightsCard(
                                period: $selectedPeriod,
                                referenceDate: $referenceDate,
                                summary: periodSummary,
                                earningsPoints: earningsPoints
                            )
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)

                            if selectedPeriod == .month {
                                Button {
                                    presentedSheet = .paycheck(referenceDate)
                                } label: {
                                    PaycheckAuditCard(
                                        expectedGross: paycheckExpectedGross,
                                        audit: paycheckAudit,
                                        currencyCode: store.profile.currencyCode
                                    )
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
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
                        if filteredSessions.isEmpty {
                            ContentUnavailableView(
                                "history.period.empty.title",
                                systemImage: "calendar.badge.exclamationmark",
                                description: Text("history.period.empty.message")
                            )
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(filteredSessions) { session in
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
        .searchable(text: $searchQuery, prompt: "history.search.prompt")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentedSheet = purchases.isPro ? .add : .pro
                } label: {
                    Label("history.add", systemImage: "plus")
                }
            }

            if !store.completedSessions.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportHistory()
                    } label: {
                        Label("history.export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .add:
                AddSessionView(profile: store.profile)
            case let .edit(session):
                EditSessionView(session: session)
            case let .paycheck(month):
                PaycheckAuditView(month: month)
            case .pro:
                ProView()
            }
        }
        .fileExporter(
            isPresented: $showsExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "ArbeitsKlar-Shifts"
        ) { result in
            if case .failure = result {
                showsExportError = true
            }
        }
        .alert("export.error.title", isPresented: $showsExportError) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text("export.error.message")
        }
        .onChange(of: store.completedSessions, initial: true) {
            refreshFilteredSessions()
        }
        .onChange(of: selectedPeriod) {
            referenceDate = .now
            refreshFilteredSessions()
        }
        .onChange(of: referenceDate) {
            refreshFilteredSessions()
        }
        .onChange(of: purchases.isPro) {
            refreshFilteredSessions()
        }
        .onChange(of: searchQuery) {
            refreshFilteredSessions()
        }
    }

    private var periodSummary: WorkPeriodSummary {
        HistoryAnalytics.summary(
            for: filteredSessions,
            fallbackCurrencyCode: store.profile.currencyCode
        )
    }

    private var earningsPoints: [HistoryEarningsPoint] {
        HistoryAnalytics.earningsPoints(
            for: filteredSessions,
            period: selectedPeriod,
            currencyCode: periodSummary.currencyCode
        )
    }

    private var paycheckExpectedGross: Double {
        store.expectedEarnings(
            forMonthContaining: referenceDate,
            currencyCode: store.profile.currencyCode
        )
    }

    private var paycheckAudit: PaycheckAudit? {
        store.paycheckAudit(
            forMonthContaining: referenceDate,
            currencyCode: store.profile.currencyCode
        )
    }

    private func openEditor(for session: WorkSession) {
        presentedSheet = purchases.isPro ? .edit(session) : .pro
    }

    private func exportHistory() {
        guard purchases.isPro else {
            presentedSheet = .pro
            return
        }
        exportDocument = WorkSessionCSVDocument(sessions: filteredSessions)
        showsExporter = true
    }

    private func refreshFilteredSessions() {
        let periodSessions: [WorkSession]
        if purchases.isPro {
            periodSessions = HistoryAnalytics.sessions(
                from: store.completedSessions,
                period: selectedPeriod,
                asOf: referenceDate
            )
        } else {
            periodSessions = store.completedSessions
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            filteredSessions = periodSessions
            return
        }
        filteredSessions = periodSessions.filter { session in
            session.title.localizedStandardContains(query)
                || session.note.localizedStandardContains(query)
                || session.tags.contains(where: { $0.localizedStandardContains(query) })
        }
    }
}

private struct PaycheckAuditCard: View {
    @Environment(AppTheme.self) private var theme

    let expectedGross: Double
    let audit: PaycheckAudit?
    let currencyCode: String

    var body: some View {
        let difference = (audit?.actualGross ?? 0) - expectedGross
        let resultTitle: LocalizedStringKey = difference < -0.01
            ? "paycheck.card.missing"
            : "paycheck.card.checked"

        HStack(spacing: 14) {
            Image(systemName: audit == nil ? "doc.text.magnifyingglass" : difference < -0.01 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(audit == nil ? theme.accent : difference < -0.01 ? theme.warning : theme.success)
                .frame(width: 46, height: 46)
                .background(theme.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("paycheck.card.title")
                    .font(.headline)
                if let audit {
                    Text(resultTitle)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryLabel)
                    Text(abs(difference), format: .currency(code: currencyCode))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                } else {
                    Text("paycheck.card.message")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryLabel)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(theme.secondaryLabel)
        }
        .padding(17)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
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

private struct SessionRow: View {
    @Environment(AppTheme.self) private var theme

    let session: WorkSession

    var body: some View {
        let breakDuration = session.breakDuration()
        let overtime = session.overtime()
        let premiumEarnings = session.earningsBreakdown().premiumEarnings

        HStack(spacing: 14) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 42, height: 42)
                .background(theme.accent.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                if session.title.isEmpty {
                    Text(session.startedAt, format: .dateTime.weekday(.abbreviated).day().month())
                        .font(.headline)
                } else {
                    Text(session.title)
                        .font(.headline)
                    Text(session.startedAt, format: .dateTime.weekday(.abbreviated).day().month())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryLabel)
                }

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

                if !session.tags.isEmpty {
                    Text(session.tags.prefix(4).map { "#\($0)" }.joined(separator: "  "))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.success)
                        .lineLimit(1)
                }

                if breakDuration > 0 || overtime > 0 || premiumEarnings > 0 {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            statPills(
                                breakDuration: breakDuration,
                                overtime: overtime,
                                premiumEarnings: premiumEarnings
                            )
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            statPills(
                                breakDuration: breakDuration,
                                overtime: overtime,
                                premiumEarnings: premiumEarnings
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

    @ViewBuilder
    private func statPills(
        breakDuration: TimeInterval,
        overtime: TimeInterval,
        premiumEarnings: Double
    ) -> some View {
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
        if premiumEarnings > 0 {
            SessionStatPill(
                title: "earnings.premiums",
                value: premiumEarnings.formatted(.currency(code: session.currencyCode)),
                systemImage: "sparkles"
            )
        }
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
