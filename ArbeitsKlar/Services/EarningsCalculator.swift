import Foundation

enum EarningsCalculator {
    static func earnings(hourlyRate: Double, elapsedTime: TimeInterval) -> Double {
        guard hourlyRate > 0, elapsedTime > 0 else { return 0 }
        return hourlyRate * elapsedTime / 3_600
    }

    static func projectedEarnings(hourlyRate: Double, plannedHours: Double) -> Double {
        max(0, hourlyRate) * max(0, plannedHours)
    }
}

