import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case history
    case settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .today: "tab.today"
        case .history: "tab.history"
        case .settings: "tab.settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "bolt.fill"
        case .history: "clock.arrow.circlepath"
        case .settings: "slider.horizontal.3"
        }
    }
}

@MainActor
struct AppView: View {
    @Environment(AppTheme.self) private var theme
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
            }
            .tag(AppTab.today)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label(AppTab.history.title, systemImage: AppTab.history.systemImage)
            }
            .tag(AppTab.history)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
            }
            .tag(AppTab.settings)
        }
        .tint(theme.accent)
    }
}

#Preview {
    AppView()
        .environment(WorkSessionStore.preview)
        .environment(AppTheme())
        .preferredColorScheme(.dark)
}

