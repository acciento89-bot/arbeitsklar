import Foundation
import SwiftUI

@main
struct ArbeitsKlarApp: App {
    @Environment(\.scenePhase) private var scenePhase

    #if DEBUG
    @State private var store = ProcessInfo.processInfo.arguments.contains("-demo-data")
        ? WorkSessionStore.demo
        : WorkSessionStore.shared
    #else
    @State private var store = WorkSessionStore.shared
    #endif
    #if DEBUG
    @State private var purchases = PurchaseManager(
        isPro: ProcessInfo.processInfo.arguments.contains("-pro-preview")
    )
    #else
    @State private var purchases = PurchaseManager()
    #endif
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
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                store.reloadFromDisk()
            }
        }
    }
}
