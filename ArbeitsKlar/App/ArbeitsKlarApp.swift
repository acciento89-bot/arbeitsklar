import SwiftUI

@main
struct ArbeitsKlarApp: App {
    @State private var store = WorkSessionStore()
    @State private var theme = AppTheme()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(store)
                .environment(theme)
                .preferredColorScheme(.dark)
        }
    }
}

