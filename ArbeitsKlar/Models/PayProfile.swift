import Foundation

struct PayProfile: Codable, Hashable {
    var hourlyRate: Double
    var currencyCode: String
    var plannedHours: Double
    var shiftRemindersEnabled: Bool
    var monthlyEarningsGoal: Double
    var shiftEarningsGoal: Double
    var shiftGoalTitle: String
    var payRules: PayRules

    init(
        hourlyRate: Double,
        currencyCode: String,
        plannedHours: Double,
        shiftRemindersEnabled: Bool = false,
        monthlyEarningsGoal: Double = 0,
        shiftEarningsGoal: Double = 0,
        shiftGoalTitle: String = "",
        payRules: PayRules = .none
    ) {
        self.hourlyRate = hourlyRate
        self.currencyCode = currencyCode
        self.plannedHours = plannedHours
        self.shiftRemindersEnabled = shiftRemindersEnabled
        self.monthlyEarningsGoal = monthlyEarningsGoal
        self.shiftEarningsGoal = shiftEarningsGoal
        self.shiftGoalTitle = shiftGoalTitle
        self.payRules = payRules
    }

    private enum CodingKeys: String, CodingKey {
        case hourlyRate
        case currencyCode
        case plannedHours
        case shiftRemindersEnabled
        case monthlyEarningsGoal
        case shiftEarningsGoal
        case shiftGoalTitle
        case payRules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hourlyRate = try container.decode(Double.self, forKey: .hourlyRate)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        plannedHours = try container.decode(Double.self, forKey: .plannedHours)
        shiftRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .shiftRemindersEnabled) ?? false
        monthlyEarningsGoal = try container.decodeIfPresent(Double.self, forKey: .monthlyEarningsGoal) ?? 0
        shiftEarningsGoal = try container.decodeIfPresent(Double.self, forKey: .shiftEarningsGoal) ?? 0
        shiftGoalTitle = try container.decodeIfPresent(String.self, forKey: .shiftGoalTitle) ?? ""
        payRules = try container.decodeIfPresent(PayRules.self, forKey: .payRules) ?? .none
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
