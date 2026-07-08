import Foundation

/// Parses/formats the timestamptz strings Postgres returns, which may or may not
/// carry fractional seconds (e.g. `2024-01-01T12:00:00.123456+00:00`). The stock
/// `.iso8601` strategy rejects fractional seconds, so we handle both forms.
enum ISO8601 {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let noFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return withFraction.date(from: string) ?? noFraction.date(from: string)
    }

    static func string(from date: Date?) -> String? {
        guard let date else { return nil }
        return withFraction.string(from: date)
    }

    /// Date-only (Postgres `date`) — used for `played_on`.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func day(from string: String?) -> Date? {
        guard let string else { return nil }
        return dayFormatter.date(from: String(string.prefix(10)))
    }

    static func dayString(from date: Date) -> String {
        dayFormatter.string(from: date)
    }
}
