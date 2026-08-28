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
                            Text("live_activity.earned")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(
                                context.state.earnedAmount,
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
                }
            } compactLeading: {
                Image(systemName: "bolt.fill")
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
        if state.isRunning {
            Text(state.startedAt, style: .timer)
        } else {
            Text(WorkDurationFormatter.string(from: state.elapsedSeconds))
        }
    }
}

private struct LockScreenWorkView: View {
    let context: ActivityViewContext<WorkActivityAttributes>

    var body: some View {
        let statusKey: LocalizedStringKey = context.state.isRunning
            ? "live_activity.running"
            : "live_activity.finished"

        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.16))
                Image(systemName: "bolt.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.blue)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 5) {
                Text(statusKey)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Text(
                    context.state.earnedAmount,
                    format: .currency(code: context.state.currencyCode)
                )
                .font(.title.bold())
                .monospacedDigit()
                .contentTransition(.numericText(value: context.state.earnedAmount))
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
}

private struct WorkActivityTimer: View {
    let state: WorkActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isRunning {
                Text(state.startedAt, style: .timer)
            } else {
                Text(WorkDurationFormatter.string(from: state.elapsedSeconds))
            }
        }
        .font(.headline)
        .monospacedDigit()
    }
}
