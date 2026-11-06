import Foundation

enum Formatting {
    private static let french = Locale(identifier: "fr_FR")

    static func percent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(french)) + " %"
    }

    static func points(_ value: Double) -> String {
        let text = abs(value).formatted(.number.precision(.fractionLength(0...1)).locale(french))
        return (value >= 0 ? "+" : "−") + text + " pt"
    }

    static func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: french, timeZone: DateParsing.paris))
    }

    static func range(_ start: Date, _ end: Date) -> String {
        "du \(day(start)) au \(day(end))"
    }
}
