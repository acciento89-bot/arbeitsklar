import Foundation

enum WorkDurationFormatter {
    static func string(from duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3_600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .pad
        formatter.calendar = .autoupdatingCurrent
        return formatter.string(from: max(0, duration)) ?? "0"
    }
}

