import Foundation

enum EnableUntilParser {
    private enum Meridiem {
        case am
        case pm
    }

    private struct ClockTime {
        let hour: Int
        let minute: Int
        let meridiem: Meridiem?
    }

    /// Returns the next occurrence of a 12-hour clock time.
    /// Explicit AM/PM values recur daily; values such as "5:00" recur every 12 hours.
    static func nextDate(
        for input: String,
        after now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard let clockTime = parse(input) else { return nil }

        let baseHour = clockTime.hour % 12
        let candidateHours: [Int]
        switch clockTime.meridiem {
        case .am:
            candidateHours = [baseHour]
        case .pm:
            candidateHours = [baseHour + 12]
        case nil:
            candidateHours = [baseHour, baseHour + 12]
        }

        return candidateHours.compactMap { hour in
            calendar.nextDate(
                after: now,
                matching: DateComponents(hour: hour, minute: clockTime.minute, second: 0),
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            )
        }.min()
    }

    private static func parse(_ input: String) -> ClockTime? {
        var normalized = input.lowercased().filter { !$0.isWhitespace }
        guard !normalized.isEmpty else { return nil }

        let meridiem: Meridiem?
        if normalized.hasSuffix("am") {
            meridiem = .am
            normalized.removeLast(2)
        } else if normalized.hasSuffix("pm") {
            meridiem = .pm
            normalized.removeLast(2)
        } else {
            meridiem = nil
        }

        let components = normalized.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count == 1 || components.count == 2,
              let hour = Int(components[0]),
              (1...12).contains(hour) else {
            return nil
        }

        let minute: Int
        if components.count == 2 {
            guard let parsedMinute = Int(components[1]),
                  components[1].count == 2,
                  (0...59).contains(parsedMinute) else {
                return nil
            }
            minute = parsedMinute
        } else {
            guard meridiem != nil else { return nil }
            minute = 0
        }

        return ClockTime(hour: hour, minute: minute, meridiem: meridiem)
    }
}
