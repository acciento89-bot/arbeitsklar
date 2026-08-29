import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct WorkSessionCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    private var text: String

    init(sessions: [WorkSession] = []) {
        text = Self.makeCSV(sessions: sessions)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }

    private static func makeCSV(sessions: [WorkSession]) -> String {
        let header = [
            "start", "end", "work_seconds", "break_seconds", "hourly_rate",
            "currency", "planned_hours", "base_earnings", "overtime_premium",
            "night_premium", "weekend_premium", "total_earnings", "title", "tags", "note"
        ].joined(separator: ",")

        let dateFormatter = ISO8601DateFormatter()
        let rows = sessions.map { session in
            let breakdown = session.earningsBreakdown()
            return [
                dateFormatter.string(from: session.startedAt),
                session.endedAt.map(dateFormatter.string(from:)) ?? "",
                decimal(session.duration()),
                decimal(session.breakDuration()),
                decimal(session.hourlyRate),
                session.currencyCode,
                decimal(session.plannedHours),
                decimal(breakdown.baseEarnings),
                decimal(breakdown.overtimePremium),
                decimal(breakdown.nightPremium),
                decimal(breakdown.weekendPremium),
                decimal(breakdown.totalEarnings),
                session.title,
                session.tags.joined(separator: " | "),
                session.note
            ]
            .map(escape)
            .joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
