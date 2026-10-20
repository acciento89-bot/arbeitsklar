import Foundation

struct ShiftRosterStorage {
    let defaults: UserDefaults
    static let key = "shift_roster_v1"

    func load() -> ShiftRoster {
        if let data = defaults.data(forKey: Self.key) {
            if let roster = try? JSONDecoder().decode(ShiftRoster.self, from: data) { return roster }
            // Retain the original bytes before any subsequent user edit can replace them.
            if defaults.data(forKey: Self.key + "_recovery") == nil {
                defaults.set(data, forKey: Self.key + "_recovery")
            }
        }
        let legacy = defaults.data(forKey: "scheduled_shifts_v1")
            .flatMap { try? JSONDecoder().decode([ScheduledShift].self, from: $0) } ?? []
        return ShiftRoster(shifts: legacy.sorted { $0.startsAt < $1.startsAt }, cycles: [])
    }

    func save(_ roster: ShiftRoster) throws {
        defaults.set(try JSONEncoder().encode(roster), forKey: Self.key)
    }
}
