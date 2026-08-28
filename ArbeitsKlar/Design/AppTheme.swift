import Observation
import SwiftUI

@MainActor
@Observable
final class AppTheme {
    let accent = Color(red: 0.29, green: 0.61, blue: 1.0)
    let success = Color(red: 0.23, green: 0.85, blue: 0.63)
    let warning = Color(red: 1.0, green: 0.72, blue: 0.27)
    let background = Color(red: 0.035, green: 0.055, blue: 0.09)
    let elevatedBackground = Color(red: 0.075, green: 0.105, blue: 0.16)
    let subtleBackground = Color.white.opacity(0.065)
    let secondaryLabel = Color.white.opacity(0.62)

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.95), Color(red: 0.18, green: 0.85, blue: 0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

