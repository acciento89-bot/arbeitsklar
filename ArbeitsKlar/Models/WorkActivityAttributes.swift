import ActivityKit
import Foundation

struct WorkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let startedAt: Date
        let timerReferenceDate: Date
        let updatedAt: Date
        let elapsedSeconds: TimeInterval
        let earnedAmount: Double
        let hourlyRate: Double
        let currencyCode: String
        let isRunning: Bool
        let isPaused: Bool
    }

    let sessionID: UUID
}
