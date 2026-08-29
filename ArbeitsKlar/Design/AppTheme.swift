import Foundation
import Observation
import SwiftUI

enum AppThemeStyle: String, CaseIterable, Codable, Equatable, Identifiable {
    case classic
    case aurora
    case sunset

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .classic: "theme.classic"
        case .aurora: "theme.aurora"
        case .sunset: "theme.sunset"
        }
    }

    var requiresPro: Bool { self != .classic }

    var swatchColors: [Color] {
        switch self {
        case .classic:
            [Color(red: 0.29, green: 0.61, blue: 1.0), Color(red: 0.18, green: 0.85, blue: 0.72)]
        case .aurora:
            [Color(red: 0.14, green: 0.75, blue: 0.67), Color(red: 0.30, green: 0.42, blue: 0.96)]
        case .sunset:
            [Color(red: 1.0, green: 0.34, blue: 0.42), Color(red: 0.72, green: 0.22, blue: 0.90)]
        }
    }
}

@MainActor
@Observable
final class AppTheme {
    var style: AppThemeStyle {
        didSet { defaults.set(style.rawValue, forKey: Self.styleKey) }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    private static let styleKey = "app_theme_style_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.style = defaults.string(forKey: Self.styleKey)
            .flatMap(AppThemeStyle.init(rawValue:)) ?? .classic
    }

    var accent: Color {
        switch style {
        case .classic: Color(red: 0.29, green: 0.61, blue: 1.0)
        case .aurora: Color(red: 0.30, green: 0.91, blue: 0.72)
        case .sunset: Color(red: 1.0, green: 0.45, blue: 0.42)
        }
    }

    var success: Color {
        switch style {
        case .classic, .aurora: Color(red: 0.23, green: 0.85, blue: 0.63)
        case .sunset: Color(red: 1.0, green: 0.76, blue: 0.35)
        }
    }

    var warning: Color { Color(red: 1.0, green: 0.72, blue: 0.27) }

    var background: Color {
        switch style {
        case .classic: Color(red: 0.035, green: 0.055, blue: 0.09)
        case .aurora: Color(red: 0.025, green: 0.075, blue: 0.075)
        case .sunset: Color(red: 0.105, green: 0.035, blue: 0.075)
        }
    }

    var elevatedBackground: Color {
        switch style {
        case .classic: Color(red: 0.075, green: 0.105, blue: 0.16)
        case .aurora: Color(red: 0.045, green: 0.14, blue: 0.14)
        case .sunset: Color(red: 0.18, green: 0.065, blue: 0.12)
        }
    }

    var subtleBackground: Color { Color.white.opacity(0.065) }
    var secondaryLabel: Color { Color.white.opacity(0.62) }

    var heroGradient: LinearGradient {
        let colors: [Color]
        switch style {
        case .classic:
            colors = [accent.opacity(0.95), Color(red: 0.18, green: 0.85, blue: 0.72)]
        case .aurora:
            colors = [Color(red: 0.14, green: 0.75, blue: 0.67), Color(red: 0.30, green: 0.42, blue: 0.96)]
        case .sunset:
            colors = [Color(red: 1.0, green: 0.34, blue: 0.42), Color(red: 0.72, green: 0.22, blue: 0.90)]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    func enforceEntitlement(isPro: Bool) {
        if !isPro, style.requiresPro {
            style = .classic
        }
    }
}
