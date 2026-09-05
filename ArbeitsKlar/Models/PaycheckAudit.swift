import Foundation

struct PaycheckAudit: Codable, Hashable, Identifiable {
    let id: UUID
    let month: Date
    var actualGross: Double
    var currencyCode: String
    var note: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        month: Date,
        actualGross: Double,
        currencyCode: String,
        note: String = "",
        updatedAt: Date = .now
    ) {
        self.id = id
        self.month = month
        self.actualGross = actualGross
        self.currencyCode = currencyCode
        self.note = note
        self.updatedAt = updatedAt
    }
}
