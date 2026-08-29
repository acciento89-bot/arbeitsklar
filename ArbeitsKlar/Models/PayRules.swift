import Foundation

struct PayRules: Codable, Hashable {
    var overtimeMultiplier: Double
    var nightBonusPercent: Double
    var weekendBonusPercent: Double
    var nightStartHour: Int
    var nightEndHour: Int

    init(
        overtimeMultiplier: Double = 1,
        nightBonusPercent: Double = 0,
        weekendBonusPercent: Double = 0,
        nightStartHour: Int = 22,
        nightEndHour: Int = 6
    ) {
        self.overtimeMultiplier = overtimeMultiplier
        self.nightBonusPercent = nightBonusPercent
        self.weekendBonusPercent = weekendBonusPercent
        self.nightStartHour = nightStartHour
        self.nightEndHour = nightEndHour
    }

    static let none = PayRules()

    var hasPremiums: Bool {
        overtimeMultiplier > 1 || nightBonusPercent > 0 || weekendBonusPercent > 0
    }
}

struct EarningsBreakdown: Equatable {
    let baseEarnings: Double
    let overtimePremium: Double
    let nightPremium: Double
    let weekendPremium: Double

    var premiumEarnings: Double {
        overtimePremium + nightPremium + weekendPremium
    }

    var totalEarnings: Double {
        baseEarnings + premiumEarnings
    }
}
