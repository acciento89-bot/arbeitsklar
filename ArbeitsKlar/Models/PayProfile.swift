import Foundation

struct PayProfile: Codable, Hashable {
    var hourlyRate: Double
    var currencyCode: String
    var plannedHours: Double

    static var defaultValue: PayProfile {
        PayProfile(
            hourlyRate: 20,
            currencyCode: Locale.autoupdatingCurrent.currency?.identifier ?? "EUR",
            plannedHours: 8
        )
    }
}

