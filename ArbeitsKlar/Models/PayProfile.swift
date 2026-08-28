import Foundation

struct PayProfile: Codable, Hashable {
    var hourlyRate: Double
    var currencyCode: String
    var plannedHours: Double

    static let supportedCurrencyCodes = [
        "EUR", "USD", "GBP", "CHF", "CAD", "AUD", "NZD", "PLN", "SEK", "NOK", "DKK", "CZK", "JPY"
    ]

    static var defaultValue: PayProfile {
        PayProfile(
            hourlyRate: 20,
            currencyCode: Locale.autoupdatingCurrent.currency?.identifier ?? "EUR",
            plannedHours: 8
        )
    }
}
