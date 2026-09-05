import SwiftUI

@MainActor
struct TodayView: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if store.activeSession != nil {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        LiveEarningsCard(date: timeline.date)
                    }
                } else {
                    LiveEarningsCard(date: .now)
                }

                if store.activeSession != nil || store.tipsToday() > 0 {
                    TipTrackerCard()
                }

                if store.activeSession == nil, let nextShift = store.nextScheduledShift {
                    NextScheduledShiftCard(shift: nextShift)
                }

                if store.activeSession == nil, !store.shiftTemplates.isEmpty {
                    ShiftTemplateQuickStart()
                }

                if store.activeSession != nil {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        metrics(at: timeline.date)
                    }
                } else {
                    metrics(at: .now)
                }

                if store.profile.monthlyEarningsGoal > 0 {
                    if store.activeSession != nil {
                        TimelineView(.periodic(from: .now, by: 60)) { timeline in
                            MonthlyGoalCard(date: timeline.date)
                        }
                    } else {
                        MonthlyGoalCard(date: .now)
                    }
                }

                if store.profile.shiftEarningsGoal > 0 {
                    if store.activeSession != nil {
                        TimelineView(.periodic(from: .now, by: 5)) { timeline in
                            ShiftGoalCard(date: timeline.date)
                        }
                    } else {
                        ShiftGoalCard(date: .now)
                    }
                }

                privacyNote
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("app.name")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: store.activeSession?.id) {
            guard store.activeSession != nil else { return }

            while !Task.isCancelled, store.activeSession != nil {
                await store.refreshLiveActivity()
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("today.kicker")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(theme.success)

            Text("today.headline")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("today.subtitle")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func metrics(at date: Date) -> some View {
        let active = store.activeSession
        let rate = active?.hourlyRate ?? store.profile.hourlyRate
        let currency = active?.currencyCode ?? store.profile.currencyCode
        let duration = store.durationToday(asOf: date)
        let breakDuration = store.breakDurationToday(asOf: date)
        let overtime = store.overtimeToday(asOf: date)
        let projectionSession = active ?? WorkSession(
            startedAt: date,
            hourlyRate: rate,
            currencyCode: currency,
            plannedHours: store.profile.plannedHours,
            payRules: store.profile.payRules
        )
        let projection = projectionSession.projectedEarningsForPlannedDuration(asOf: date)

        return LazyVGrid(columns: columns, spacing: 12) {
            MetricCard("today.metric.duration", systemImage: "timer") {
                Text(WorkDurationFormatter.string(from: duration))
            }

            MetricCard("today.metric.breaks", systemImage: "cup.and.saucer.fill") {
                Text(WorkDurationFormatter.string(from: breakDuration))
            }

            MetricCard("today.metric.projected", systemImage: "chart.line.uptrend.xyaxis") {
                Text(projection, format: .currency(code: currency))
            }

            MetricCard("today.metric.overtime", systemImage: "clock.badge.exclamationmark") {
                Text(WorkDurationFormatter.string(from: overtime))
            }
        }
    }

    private var privacyNote: some View {
        Label {
            Text("today.local_only")
        } icon: {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(theme.success)
        }
        .font(.caption)
        .foregroundStyle(theme.secondaryLabel)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 6)
    }
}

@MainActor
private struct TipTrackerCard: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme
    @State private var customAmount = 0.0
    @FocusState private var isAmountFocused: Bool

    private let quickAmounts = [2.0, 5.0, 10.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("tips.title")
                        .font(.headline)
                    Text("tips.subtitle")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryLabel)
                }
                Spacer()
                Text(store.tipsToday(), format: .currency(code: currencyCode))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(theme.success)
            }

            if store.activeSession != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { quickButtons }
                    VStack(spacing: 8) { quickButtons }
                }

                HStack(spacing: 10) {
                    TextField(
                        "tips.custom",
                        value: $customAmount,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button("tips.add") {
                        store.addTip(customAmount)
                        customAmount = 0
                        isAmountFocused = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(customAmount <= 0)
                }
            }
        }
        .padding(18)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .sensoryFeedback(.success, trigger: store.activeSession?.tips ?? 0)
    }

    @ViewBuilder
    private var quickButtons: some View {
        ForEach(quickAmounts, id: \.self) { amount in
            Button {
                store.addTip(amount)
            } label: {
                Text("+\(amount, format: .currency(code: currencyCode))")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("tips.add")
            .accessibilityValue(Text(amount, format: .currency(code: currencyCode)))
        }
    }

    private var currencyCode: String {
        store.activeSession?.currencyCode ?? store.profile.currencyCode
    }
}

@MainActor
private struct NextScheduledShiftCard: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme
    let shift: ScheduledShift

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("planner.next_shift")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.success)
                    Text(shift.title.isEmpty ? String(localized: "planner.untitled") : shift.title)
                        .font(.title3.bold())
                }
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 42, height: 42)
                    .background(theme.accent.opacity(0.14), in: Circle())
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { timing }
                VStack(alignment: .leading, spacing: 6) { timing }
            }
            .font(.subheadline)
            .foregroundStyle(theme.secondaryLabel)

            Button {
                Task { await store.startShift(from: shift) }
            } label: {
                Label("planner.start_now", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var timing: some View {
        Label {
            Text(shift.startsAt, format: .dateTime.weekday(.wide).day().month().hour().minute())
        } icon: {
            Image(systemName: "clock.fill")
        }
        Label {
            Text(shift.plannedHours, format: .number.precision(.fractionLength(0...1)))
            Text("unit.hours")
        } icon: {
            Image(systemName: "timer")
        }
    }
}

@MainActor
private struct ShiftTemplateQuickStart: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("templates.quick.title")
                        .font(.headline)
                    Text("templates.quick.subtitle")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryLabel)
                }
                Spacer()
                Image(systemName: "bolt.badge.clock.fill")
                    .foregroundStyle(theme.accent)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(store.shiftTemplates) { template in
                        Button {
                            Task { await store.startShift(using: template) }
                        } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(template.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)

                                HStack(spacing: 10) {
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
                                .font(.caption)
                                .foregroundStyle(theme.secondaryLabel)
                            }
                            .frame(width: 210, alignment: .leading)
                            .padding(14)
                            .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(theme.accent.opacity(0.22), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("templates.quick.hint")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
    }
}

@MainActor
private struct LiveEarningsCard: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme

    let date: Date

    var body: some View {
        let session = store.activeSession
        let currency = session?.currencyCode ?? store.profile.currencyCode
        let amount = session?.earnings(asOf: date) ?? store.earningsToday(asOf: date)
        let premiumEarnings = session?.earningsBreakdown(asOf: date).premiumEarnings ?? 0
        let hourlyRate = session?.hourlyRate ?? store.profile.hourlyRate
        let progress = min(
            (session?.duration(asOf: date) ?? 0) / max((session?.plannedHours ?? store.profile.plannedHours) * 3_600, 1),
            1
        )

        VStack(alignment: .leading, spacing: 22) {
            HStack {
                statusPill(session: session)
                Spacer()

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 42, height: 42)
                .accessibilityLabel("today.progress")
                .accessibilityValue(
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("today.earned")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))

                Text(amount, format: .currency(code: currency))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: amount))
                    .accessibilityLabel("today.earned")

                if premiumEarnings > 0 {
                    Label {
                        Text(premiumEarnings, format: .currency(code: currency))
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .accessibilityLabel("earnings.premiums")
                }

                if let session, session.tips > 0 {
                    Label {
                        Text(session.tips, format: .currency(code: currency))
                    } icon: {
                        Image(systemName: "heart.fill")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .accessibilityLabel("tips.amount")
                }
            }

            HStack(spacing: 18) {
                Label {
                    if let session {
                        if session.isPaused {
                            Text(WorkDurationFormatter.string(from: session.duration(asOf: date)))
                                .monospacedDigit()
                        } else {
                            Text(session.timerReferenceDate(asOf: date), style: .timer)
                                .monospacedDigit()
                        }
                    } else {
                        Text("today.timer.ready")
                    }
                } icon: {
                    Image(systemName: "clock.fill")
                }

                HStack(spacing: 3) {
                    Image(systemName: "banknote.fill")
                    Text(hourlyRate, format: .currency(code: currency))
                    Text("unit.per_hour")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))

            shiftActions(session: session)
        }
        .padding(22)
        .background(theme.heroGradient, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: theme.accent.opacity(0.24), radius: 28, y: 16)
    }

    @ViewBuilder
    private func shiftActions(session: WorkSession?) -> some View {
        if let session {
            let pauseTitle: LocalizedStringKey = session.isPaused
                ? "today.resume_shift"
                : "today.pause_shift"
            let pauseHint: LocalizedStringKey = session.isPaused
                ? "today.resume_hint"
                : "today.pause_hint"

            HStack(spacing: 10) {
                Button {
                    Task {
                        if session.isPaused {
                            await store.resumeShift()
                        } else {
                            await store.pauseShift()
                        }
                    }
                } label: {
                    Label {
                        Text(pauseTitle)
                    } icon: {
                        Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                    }
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .buttonStyle(HeroActionButtonStyle(background: .white.opacity(0.2)))
                .accessibilityHint(Text(pauseHint))

                Button {
                    Task { await store.stopShift() }
                } label: {
                    Label("today.end_shift", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .buttonStyle(HeroActionButtonStyle(background: .black.opacity(0.72)))
                .accessibilityHint("today.stop_hint")
            }
        } else {
            Button {
                Task { await store.startShift() }
            } label: {
                Label("today.start_shift", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HeroActionButtonStyle(background: .black.opacity(0.72)))
            .accessibilityHint("today.start_hint")
        }
    }

    private func statusPill(session: WorkSession?) -> some View {
        let statusKey: LocalizedStringKey
        let statusColor: Color

        if session?.isPaused == true {
            statusKey = "today.status.paused"
            statusColor = theme.warning
        } else if session != nil {
            statusKey = "today.status.live"
            statusColor = theme.success
        } else {
            statusKey = "today.status.ready"
            statusColor = .white.opacity(0.7)
        }

        return HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusKey)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.2), in: Capsule())
        .foregroundStyle(.white)
    }
}

private struct HeroActionButtonStyle: ButtonStyle {
    let background: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 15)
            .padding(.horizontal, 10)
            .foregroundStyle(.white)
            .background(
                background.opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

#Preview("Active shift") {
    NavigationStack {
        TodayView()
    }
    .environment(WorkSessionStore.preview)
    .environment(AppTheme())
    .preferredColorScheme(.dark)
}

#Preview("Paused shift") {
    NavigationStack {
        TodayView()
    }
    .environment(WorkSessionStore.pausedPreview)
    .environment(AppTheme())
    .preferredColorScheme(.dark)
}
