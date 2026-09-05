import ActivityKit
import SwiftUI
import WidgetKit

struct WorkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkActivityAttributes.self) { context in
            LockScreenWorkView(context: context)
                .activityBackgroundTint(Color(red: 0.035, green: 0.055, blue: 0.09))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("app.name", systemImage: "bolt.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    activityTimer(for: context.state)
                        .font(.headline)
                        .monospacedDigit()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(amountTitle(for: context.state))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(
                                displayedAmount(for: context.state),
                                format: .currency(code: context.state.currencyCode)
                            )
                            .font(.title2.bold())
                            .monospacedDigit()
                        }

                        Spacer()

                        HStack(spacing: 3) {
                            Text(
                                context.state.hourlyRate,
                                format: .currency(code: context.state.currencyCode)
                            )
                            Text("unit.per_hour")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    if context.state.isRunning, !context.state.isPaused {
                        activityProgress(for: context.state)
                            .tint(.blue)
                            .padding(.horizontal, 4)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "bolt.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                activityTimer(for: context.state)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.blue)
            }
            .keylineTint(.blue)
        }
    }

    @ViewBuilder
    private func activityTimer(
        for state: WorkActivityAttributes.ContentState
    ) -> some View {
        if state.isRunning, !state.isPaused {
            Text(state.timerReferenceDate, style: .timer)
        } else {
            Text(WorkDurationFormatter.string(from: state.elapsedSeconds))
        }
    }

    private func displayedAmount(for state: WorkActivityAttributes.ContentState) -> Double {
        state.isRunning && !state.isPaused
            ? state.projectedEarnings
            : state.earnedAmount
    }

    private func amountTitle(
        for state: WorkActivityAttributes.ContentState
    ) -> LocalizedStringKey {
        state.isRunning && !state.isPaused
            ? "live_activity.shift_target"
            : "live_activity.earned"
    }

    @ViewBuilder
    private func activityProgress(
        for state: WorkActivityAttributes.ContentState
    ) -> some View {
        if state.timerReferenceDate < state.plannedWorkEndDate {
            ProgressView(
                timerInterval: state.timerReferenceDate...state.plannedWorkEndDate,
                countsDown: false
            )
        }
    }
}

private struct LockScreenWorkView: View {
    let context: ActivityViewContext<WorkActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.16))
                Image(systemName: context.state.isPaused ? "pause.fill" : "bolt.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.blue)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 5) {
                Text(statusKey)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                amountLabel
                    .font(.title.bold())
                    .monospacedDigit()

                if context.state.isRunning, !context.state.isPaused {
                    ProgressView(
                        timerInterval: context.state.timerReferenceDate...context.state.plannedWorkEndDate,
                        countsDown: false
                    )
                    .tint(.blue)
                    .accessibilityLabel("live_activity.progress")
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                WorkActivityTimer(state: context.state)

                HStack(spacing: 3) {
                    Text(
                        context.state.hourlyRate,
                        format: .currency(code: context.state.currencyCode)
                    )
                    Text("unit.per_hour")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    private var statusKey: LocalizedStringKey {
        if context.state.isPaused {
            return "live_activity.paused"
        }
        if context.state.isRunning {
            return "live_activity.running"
        }
        return "live_activity.finished"
    }

    private var amountLabel: Text {
        let labelKey: LocalizedStringKey = context.state.isRunning && !context.state.isPaused
            ? "live_activity.shift_target"
            : "live_activity.earned"
        let amount = context.state.isRunning && !context.state.isPaused
            ? context.state.projectedEarnings
            : context.state.earnedAmount

        return Text(labelKey)
            + Text(" ")
            + Text(amount, format: .currency(code: context.state.currencyCode))
    }
}

private struct WorkActivityTimer: View {
    let state: WorkActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isRunning, !state.isPaused {
                Text(state.timerReferenceDate, style: .timer)
            } else {
                Text(WorkDurationFormatter.string(from: state.elapsedSeconds))
            }
        }
        .font(.headline)
        .monospacedDigit()
    }
}
