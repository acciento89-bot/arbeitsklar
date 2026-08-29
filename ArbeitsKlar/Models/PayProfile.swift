import Foundation

struct PayProfile: Codable, Hashable {
    var hourlyRate: Double
    var currencyCode: String
    var plannedHours: Double
    var shiftRemindersEnabled: Bool

    init(
        hourlyRate: Double,
        currencyCode: String,
        plannedHours: Double,
        shiftRemindersEnabled: Bool = false
    ) {
        self.hourlyRate = hourlyRate
        self.currencyCode = currencyCode
        self.plannedHours = plannedHours
        self.shiftRemindersEnabled = shiftRemindersEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case hourlyRate
        case currencyCode
        case plannedHours
        case shiftRemindersEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hourlyRate = try container.decode(Double.self, forKey: .hourlyRate)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        plannedHours = try container.decode(Double.self, forKey: .plannedHours)
        shiftRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .shiftRemindersEnabled) ?? false
    }

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
