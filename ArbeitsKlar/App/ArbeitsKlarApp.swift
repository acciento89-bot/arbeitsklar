import SwiftUI

@main
struct ArbeitsKlarApp: App {
    @State private var store = WorkSessionStore()
    @State private var purchases = PurchaseManager()
    @State private var theme = AppTheme()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(store)
                .environment(purchases)
                .environment(theme)
                .preferredColorScheme(.dark)
                .task {
                    await purchases.prepare()
                    await purchases.observeTransactionUpdates()
                }
        }
    }
}
