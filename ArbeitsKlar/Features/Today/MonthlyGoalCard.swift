import SwiftUI

@MainActor
struct MonthlyGoalCard: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme

    let date: Date

    var body: some View {
        let goal = store.profile.monthlyEarningsGoal
        let earnings = store.earningsThisMonth(asOf: date)
        let progress = min(max(earnings / max(goal, 1), 0), 1)
        let remaining = max(goal - earnings, 0)
        let remainingTitle: LocalizedStringKey = progress >= 1 ? "goal.reached" : "goal.remaining"

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("goal.title", systemImage: "target")
                    .font(.headline)
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(progress >= 1 ? theme.success : theme.accent)
            }

            ProgressView(value: progress)
                .tint(progress >= 1 ? theme.success : theme.accent)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("goal.earned")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryLabel)
                    Text(earnings, format: .currency(code: store.profile.currencyCode))
                        .font(.title3.bold().monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(remainingTitle)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryLabel)
                    Text(remaining, format: .currency(code: store.profile.currencyCode))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
        }
        .padding(18)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
