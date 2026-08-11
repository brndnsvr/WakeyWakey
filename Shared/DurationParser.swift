import Foundation

enum DurationParser {
    /// Parses durations such as "20m", "4h", and "3.5h" into seconds.
    static func parse(_ input: String) -> TimeInterval? {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2, let unit = normalized.last else { return nil }

        let valueText = normalized.dropLast()
        guard let value = Double(valueText), value.isFinite, value > 0 else { return nil }

        let seconds: TimeInterval
        switch unit {
        case "m":
            seconds = value * 60
        case "h":
            seconds = value * 3600
        default:
            return nil
        }

        return seconds.isFinite ? seconds : nil
    }
}
