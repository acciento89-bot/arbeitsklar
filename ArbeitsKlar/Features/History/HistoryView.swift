import SwiftUI

@MainActor
struct HistoryView: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme

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
                        ForEach(store.completedSessions) { session in
                            SessionRow(session: session)
                                .listRowBackground(theme.elevatedBackground)
                                .swipeActions {
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
    }
}

private struct SessionRow: View {
    @Environment(AppTheme.self) private var theme

    let session: WorkSession

    var body: some View {
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

#Preview("History") {
    NavigationStack {
        HistoryView()
    }
    .environment(WorkSessionStore.preview)
    .environment(AppTheme())
    .preferredColorScheme(.dark)
}

