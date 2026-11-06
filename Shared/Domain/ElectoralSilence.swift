import Foundation

struct SilencePeriod: Codable, Hashable {
    var start: Date
    var end: Date

    func contains(_ date: Date) -> Bool { date >= start && date < end }
}

/// Aucun sondage ni moyenne ne doit être affiché pendant ces périodes.
enum ElectoralSilence {
    /// Heure de Paris. 1er tour le 18 avril 2027, second tour le 2 mai 2027.
    static let builtIn: [SilencePeriod] = [
        period("2027-04-17T00:00:00+02:00", "2027-04-18T20:00:00+02:00"),
        period("2027-05-01T00:00:00+02:00", "2027-05-02T20:00:00+02:00"),
    ]

    private static func period(_ start: String, _ end: String) -> SilencePeriod {
        let formatter = ISO8601DateFormatter()
        return SilencePeriod(start: formatter.date(from: start)!, end: formatter.date(from: end)!)
    }

    /// Les périodes distantes s'ajoutent aux dates intégrées, sans jamais pouvoir les retirer.
    static func isActive(at date: Date, remote: [SilencePeriod]? = nil) -> Bool {
        (builtIn + (remote ?? [])).contains { $0.contains(date) }
    }
}
