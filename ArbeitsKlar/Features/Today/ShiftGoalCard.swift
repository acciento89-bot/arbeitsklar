import SwiftUI

@MainActor
struct ShiftGoalCard: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme

    let date: Date

    var body: some View {
        let target = max(0, store.profile.shiftEarningsGoal)
        let session = store.activeSession
        let currencyCode = session?.currencyCode ?? store.profile.currencyCode
        let earnings = session?.earnings(asOf: date) ?? 0
        let progress = min(max(earnings / max(target, 1), 0), 1)
        let reached = earnings >= target
        let remainingTitle: LocalizedStringKey = reached ? "goal.shift.reached" : "goal.shift.remaining"

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: reached ? "trophy.fill" : "flag.checkered")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(reached ? theme.success : theme.accent)
                    .frame(width: 44, height: 44)
                    .background((reached ? theme.success : theme.accent).opacity(0.13), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(goalTitle)
                        .font(.headline)
                    Text("goal.shift.subtitle")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryLabel)
                }

                Spacer()

                Text(target, format: .currency(code: currencyCode))
                    .font(.headline.monospacedDigit())
            }

            ProgressView(value: progress)
                .tint(reached ? theme.success : theme.accent)

            if let session {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(remainingTitle)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryLabel)
                        Text(max(0, target - earnings), format: .currency(code: session.currencyCode))
                            .font(.title3.bold().monospacedDigit())
                    }

                    Spacer()

                    if !reached, let projectedDate = session.projectedDate(forEarnings: target, asOf: date) {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("goal.shift.time_left")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryLabel)
                            Text(WorkDurationFormatter.string(from: projectedDate.timeIntervalSince(date)))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                    }
                }
            } else {
                Label("goal.shift.start_hint", systemImage: "play.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryLabel)
            }
        }
        .padding(18)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke((reached ? theme.success : theme.accent).opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .sensoryFeedback(.success, trigger: reached) { oldValue, newValue in
            !oldValue && newValue
        }
    }

    private var goalTitle: String {
        let customTitle = store.profile.shiftGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return customTitle.isEmpty ? String(localized: "goal.shift.default_title") : customTitle
    }
}
