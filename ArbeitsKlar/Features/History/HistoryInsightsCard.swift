import Charts
import SwiftUI

struct HistoryInsightsCard: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.locale) private var locale
    @Binding var period: HistoryPeriod
    @Binding var referenceDate: Date

    let summary: WorkPeriodSummary
    let earningsPoints: [HistoryEarningsPoint]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            periodPicker
            periodNavigation

            if summary.isEmpty {
                Text("history.insights.empty")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryLabel)
            } else {
                summaryGrid
                earningsChart
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

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(period.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.success)

                Text("history.insights.title")
                    .font(.title2.bold())
            }

            Spacer()

            Image(systemName: "chart.bar.xaxis")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 42, height: 42)
                .background(theme.accent.opacity(0.14), in: Circle())
        }
    }

    private var periodPicker: some View {
        Picker("history.period.label", selection: $period) {
            ForEach(HistoryPeriod.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var periodNavigation: some View {
        if period != .all {
            HStack(spacing: 12) {
                Button {
                    referenceDate = period.moving(referenceDate, by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 32)
                }
                .accessibilityLabel("history.period.previous")

                Spacer()
                periodTitle
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                Spacer()

                Button {
                    referenceDate = period.moving(referenceDate, by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 32)
                }
                .disabled(!period.canMoveForward(from: referenceDate))
                .accessibilityLabel("history.period.next")
            }
            .foregroundStyle(theme.accent)
        }
    }

    @ViewBuilder
    private var periodTitle: some View {
        switch period {
        case .week:
            if let interval = period.interval(containing: referenceDate) {
                HStack(spacing: 4) {
                    Text(interval.start, format: .dateTime.day().month(.abbreviated))
                    Text("history.period.range_separator")
                    Text(interval.end.addingTimeInterval(-1), format: .dateTime.day().month(.abbreviated).year())
                }
            }
        case .month:
            Text(referenceDate, format: .dateTime.month(.wide).year())
        case .all:
            EmptyView()
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            HistorySummaryValue(
                title: "history.insights.work_time",
                value: WorkDurationFormatter.string(from: summary.workDuration)
            )
            HistorySummaryValue(
                title: "history.insights.earnings",
                value: summary.earnings.formatted(
                    .currency(code: summary.currencyCode).locale(locale)
                )
            )
            HistorySummaryValue(
                title: "history.insights.breaks",
                value: WorkDurationFormatter.string(from: summary.breakDuration)
            )
            HistorySummaryValue(
                title: "history.insights.overtime",
                value: WorkDurationFormatter.string(from: summary.overtimeDuration)
            )
            HistorySummaryValue(
                title: "history.insights.average_time",
                value: WorkDurationFormatter.string(from: summary.averageWorkDuration)
            )
            HistorySummaryValue(
                title: "history.insights.average_earnings",
                value: summary.averageEarnings.formatted(
                    .currency(code: summary.currencyCode).locale(locale)
                )
            )
        }
    }

    private var earningsChart: some View {
        Chart(earningsPoints) { point in
            BarMark(
                x: .value(String(localized: "history.chart.period"), point.periodStart),
                y: .value(String(localized: "history.chart.earnings"), point.earnings)
            )
            .foregroundStyle(theme.accent.gradient)
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                AxisValueLabel(format: .currency(code: summary.currencyCode))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) {
                AxisValueLabel()
            }
        }
        .frame(height: 170)
        .accessibilityLabel("history.chart.accessibility")
    }
}

private struct HistorySummaryValue: View {
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
