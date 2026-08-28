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

                if store.activeSession != nil {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        metrics(at: timeline.date)
                    }
                } else {
                    metrics(at: .now)
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
        let projection = EarningsCalculator.projectedEarnings(
            hourlyRate: rate,
            plannedHours: store.profile.plannedHours
        )

        return LazyVGrid(columns: columns, spacing: 12) {
            MetricCard("today.metric.duration", systemImage: "timer") {
                Text(WorkDurationFormatter.string(from: duration))
            }

            MetricCard("today.metric.hourly_rate", systemImage: "banknote.fill") {
                Text(rate, format: .currency(code: currency))
            }

            MetricCard("today.metric.projected", systemImage: "chart.line.uptrend.xyaxis") {
                Text(projection, format: .currency(code: currency))
            }

            MetricCard("today.metric.sessions", systemImage: "calendar.badge.clock") {
                Text(store.completedSessions.count, format: .number)
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
private struct LiveEarningsCard: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme

    let date: Date

    var body: some View {
        let session = store.activeSession
        let actionHint: LocalizedStringKey = session == nil ? "today.start_hint" : "today.stop_hint"
        let currency = session?.currencyCode ?? store.profile.currencyCode
        let amount = session?.earnings(asOf: date) ?? store.earningsToday(asOf: date)
        let hourlyRate = session?.hourlyRate ?? store.profile.hourlyRate
        let progress = min(
            (session?.duration(asOf: date) ?? 0) / max(store.profile.plannedHours * 3_600, 1),
            1
        )

        VStack(alignment: .leading, spacing: 22) {
            HStack {
                statusPill(isActive: session != nil)
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
            }

            HStack(spacing: 18) {
                Label {
                    if let session {
                        Text(session.startedAt, style: .timer)
                            .monospacedDigit()
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

            Button {
                Task {
                    if store.activeSession == nil {
                        store.startShift()
                    } else {
                        await store.stopShift()
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    if session == nil {
                        Label("today.start_shift", systemImage: "play.fill")
                    } else {
                        Label("today.end_shift", systemImage: "stop.fill")
                    }
                    Spacer()
                }
                .font(.headline)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint(actionHint)
        }
        .padding(22)
        .background(theme.heroGradient, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: theme.accent.opacity(0.24), radius: 28, y: 16)
    }

    private func statusPill(isActive: Bool) -> some View {
        let statusKey: LocalizedStringKey = isActive ? "today.status.live" : "today.status.ready"

        return HStack(spacing: 7) {
            Circle()
                .fill(isActive ? Color.green : Color.white.opacity(0.7))
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

#Preview("Active shift") {
    NavigationStack {
        TodayView()
    }
    .environment(WorkSessionStore.preview)
    .environment(AppTheme())
    .preferredColorScheme(.dark)
}
