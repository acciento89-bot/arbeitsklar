import Foundation

/// A reusable local-calendar work/rest pattern. Nil slots are days off.
/// Template values are snapshots, so deleting a template never loses a plan.
struct ShiftCycle: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var anchorDate: Date
    var endDate: Date
    var timeZoneIdentifier: String
    var dayTemplates: [ShiftTemplate?]

    init(
        id: UUID = UUID(), name: String, anchorDate: Date, endDate: Date,
        timeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier,
        dayTemplates: [ShiftTemplate?]
    ) {
        self.id = id
        self.name = name
        self.anchorDate = anchorDate
        self.endDate = endDate
        self.timeZoneIdentifier = timeZoneIdentifier
        self.dayTemplates = dayTemplates
    }
}
