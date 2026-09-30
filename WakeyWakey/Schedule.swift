import Foundation

/// One recurring block of the weekly schedule: on these weekdays, from start
/// to end (wall-clock time), keep the Mac awake in the given mode.
///
/// Foundation only: no AppKit, no `Settings`. `AppDelegate` asks a
/// `WeeklySchedule` and a `ScheduleDriver` what to do each tick; tests check
/// the rules directly.
struct ScheduleBlock: Identifiable, Equatable, Codable {
    static let minutesPerDay = 24 * 60
    static let minutesPerWeek = 7 * minutesPerDay
    static let minuteStep = 5

    let id: UUID
    var isEnabled: Bool
    /// Calendar weekdays the block starts on (1 = Sunday … 7 = Saturday).
    var weekdays: Set<Int>
    /// Minutes after midnight, a multiple of `minuteStep`.
    var startMinute: Int
    /// Minutes after midnight, a multiple of `minuteStep`. An end at or before
    /// the start runs past midnight into the next day.
    var endMinute: Int
    var mode: KeepAwakeMode

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        weekdays: Set<Int>,
        startMinute: Int,
        endMinute: Int,
        mode: KeepAwakeMode
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.weekdays = weekdays.filter { (1...7).contains($0) }
        self.startMinute = Self.normalized(startMinute)
        self.endMinute = Self.normalized(endMinute)
        self.mode = mode
    }

    // Decoding runs through init so stored values land back on the grid
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            isEnabled: try container.decode(Bool.self, forKey: .isEnabled),
            weekdays: try container.decode(Set<Int>.self, forKey: .weekdays),
            startMinute: try container.decode(Int.self, forKey: .startMinute),
            endMinute: try container.decode(Int.self, forKey: .endMinute),
            mode: try container.decode(KeepAwakeMode.self, forKey: .mode)
        )
    }

    /// Clamps a stored or typed minute onto the day and the 5-minute grid.
    static func normalized(_ minute: Int) -> Int {
        let wrapped = ((minute % minutesPerDay) + minutesPerDay) % minutesPerDay
        return wrapped - wrapped % minuteStep
    }

    /// Length in minutes; an end equal to the start means a full day.
    var durationMinutes: Int {
        let minutes = (endMinute - startMinute + Self.minutesPerDay) % Self.minutesPerDay
        return minutes == 0 ? Self.minutesPerDay : minutes
    }

    /// Whether the block runs past midnight into the next day.
    var crossesMidnight: Bool {
        endMinute <= startMinute
    }

    /// Minute-of-week ranges (Sunday 00:00 = 0) this block covers, one per
    /// weekday. A Saturday-night block may end past `minutesPerWeek`.
    var weekOccurrences: [Range<Int>] {
        weekdays.sorted().map { weekday in
            let start = (weekday - 1) * Self.minutesPerDay + startMinute
            return start..<(start + durationMinutes)
        }
    }

    /// The first block of a new schedule: weekday office hours in Wakey.
    static func starter() -> ScheduleBlock {
        ScheduleBlock(weekdays: [2, 3, 4, 5, 6], startMinute: 9 * 60, endMinute: 17 * 60, mode: .wakey)
    }

    /// Example schedule: weekday work hours in Wakey, then evenings in Lights.
    static let samples: [ScheduleBlock] = [
        ScheduleBlock(weekdays: [2, 3, 4, 5, 6], startMinute: 8 * 60, endMinute: 17 * 60, mode: .wakey),
        ScheduleBlock(weekdays: [2, 3, 4, 5, 6], startMinute: 17 * 60, endMinute: 20 * 60, mode: .lights)
    ]

    /// Weekdays (1…7) on which two enabled blocks claim the same minute.
    static func overlapWeekdays(in blocks: [ScheduleBlock]) -> Set<Int> {
        let enabled = blocks.filter(\.isEnabled)
        var weekdays = Set<Int>()
        for i in enabled.indices {
            for j in enabled.indices where j > i {
                for a in wrapped(enabled[i].weekOccurrences) {
                    for b in wrapped(enabled[j].weekOccurrences) where a.overlaps(b) {
                        weekdays.insert(max(a.lowerBound, b.lowerBound) / minutesPerDay + 1)
                    }
                }
            }
        }
        return weekdays
    }

    /// Splits ranges that run past the end of the week back onto Sunday.
    private static func wrapped(_ ranges: [Range<Int>]) -> [Range<Int>] {
        ranges.flatMap { range -> [Range<Int>] in
            guard range.upperBound > minutesPerWeek else { return [range] }
            return [range.lowerBound..<minutesPerWeek, 0..<(range.upperBound - minutesPerWeek)]
        }
    }
}

extension KeepAwakeMode: Codable {}

extension KeepAwakeMode {
    /// Capitalized name for menus and status lines.
    var displayName: String {
        switch self {
        case .wakey: return "Wakey"
        case .lights: return "Lights"
        }
    }
}

// MARK: - Occurrences

/// One dated run of a block, from its start to its end.
struct ScheduleOccurrence: Equatable, Hashable {
    struct ID: Hashable {
        let blockID: UUID
        let start: Date
    }

    let blockID: UUID
    let start: Date
    let end: Date
    let mode: KeepAwakeMode

    var id: ID { ID(blockID: blockID, start: start) }

    func contains(_ date: Date) -> Bool {
        start <= date && date < end
    }
}

/// The enabled blocks, resolved against the calendar.
struct WeeklySchedule {
    let blocks: [ScheduleBlock]
    let calendar: Calendar

    init(blocks: [ScheduleBlock], calendar: Calendar = .current) {
        self.blocks = blocks.filter(\.isEnabled)
        self.calendar = calendar
    }

    /// The block's run that starts on `day`, if the block runs that weekday.
    private func occurrence(of block: ScheduleBlock, startingOn day: Date) -> ScheduleOccurrence? {
        let weekday = calendar.component(.weekday, from: day)
        guard block.weekdays.contains(weekday),
              let start = wallClock(block.startMinute, on: day) else { return nil }

        let endDay = block.crossesMidnight ? calendar.date(byAdding: .day, value: 1, to: day) : day
        guard let endDay, let end = wallClock(block.endMinute, on: endDay), end > start else { return nil }
        return ScheduleOccurrence(blockID: block.id, start: start, end: end, mode: block.mode)
    }

    private func wallClock(_ minute: Int, on day: Date) -> Date? {
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
    }

    /// Every run that covers `date`: today's, or last night's past midnight.
    func occurrences(containing date: Date) -> [(index: Int, occurrence: ScheduleOccurrence)] {
        let today = calendar.startOfDay(for: date)
        var result: [(index: Int, occurrence: ScheduleOccurrence)] = []
        for (index, block) in blocks.enumerated() {
            for offset in [-1, 0] {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                      let occurrence = occurrence(of: block, startingOn: day),
                      occurrence.contains(date) else { continue }
                result.append((index, occurrence))
            }
        }
        return result
    }

    /// The run in charge at `date`. When runs overlap, the one that started
    /// latest wins, so a short block nested in a long one takes over for its
    /// length; on a tie, the block further down the list wins.
    func current(at date: Date) -> ScheduleOccurrence? {
        occurrences(containing: date)
            .max { a, b in
                a.occurrence.start != b.occurrence.start
                    ? a.occurrence.start < b.occurrence.start
                    : a.index < b.index
            }?
            .occurrence
    }

    /// The first run to start strictly after `date`, looking a week ahead.
    func nextStart(after date: Date) -> ScheduleOccurrence? {
        let today = calendar.startOfDay(for: date)
        var soonest: ScheduleOccurrence?
        for block in blocks {
            for offset in 0...7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                      let occurrence = occurrence(of: block, startingOn: day),
                      occurrence.start > date else { continue }
                if let current = soonest, current.start <= occurrence.start { continue }
                soonest = occurrence
            }
        }
        return soonest
    }

    /// When `current` stops being in charge: at its end, or sooner if another
    /// run starts first (a later start always takes over).
    func nextChange(after date: Date, from current: ScheduleOccurrence) -> Date {
        guard let next = nextStart(after: date), next.start < current.end else { return current.end }
        return next.start
    }
}

// MARK: - Driver

/// Decides what the schedule does each tick, given who turned WakeyWakey on.
///
/// - The schedule turns on at a block's start and off at its end, but only
///   what it turned on itself. A session you started is left alone.
/// - Turning WakeyWakey off yourself skips the rest of every block running
///   at that moment; it stays off until the next block starts.
/// - At a switch between blocks, the new block's mode applies once. Picking
///   another mode mid-block sticks until the next switch.
struct ScheduleDriver {

    enum Action: Equatable {
        case none
        case enable(KeepAwakeMode)
        case switchMode(KeepAwakeMode)
        case disable
    }

    /// Runs a manual off skipped; dropped once they end.
    private(set) var skipped: Set<ScheduleOccurrence.ID> = []
    /// The run whose mode was last applied, so it applies once.
    private var applied: ScheduleOccurrence.ID?

    /// The run in charge now, unless a manual off skipped it.
    func effective(in schedule: WeeklySchedule?, at now: Date) -> ScheduleOccurrence? {
        guard let current = schedule?.current(at: now), !skipped.contains(current.id) else { return nil }
        return current
    }

    mutating func evaluate(
        schedule: WeeklySchedule?,
        now: Date,
        isEnabled: Bool,
        enabledBySchedule: Bool
    ) -> Action {
        if let schedule {
            let running = Set(schedule.occurrences(containing: now).map(\.occurrence.id))
            skipped.formIntersection(running)
        } else {
            skipped.removeAll()
        }

        let target = effective(in: schedule, at: now)

        if isEnabled && !enabledBySchedule {
            applied = nil
            return .none
        }

        guard let target else {
            applied = nil
            return isEnabled ? .disable : .none
        }

        defer { applied = target.id }
        if !isEnabled {
            return .enable(target.mode)
        }
        return applied == target.id ? .none : .switchMode(target.mode)
    }

    /// A manual off: skip every run covering `now`, including a long block
    /// under a nested one, so nothing comes back on until a new block starts.
    mutating func skipRunning(in schedule: WeeklySchedule?, at now: Date) {
        guard let schedule else { return }
        skipped.formUnion(schedule.occurrences(containing: now).map(\.occurrence.id))
        applied = nil
    }
}

// MARK: - Text

enum ScheduleText {

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// "today at 5:00 PM", "tomorrow at 8:00 AM", "Monday at 8:00 AM".
    static func dayAndTime(_ date: Date, calendar: Calendar = .current) -> String {
        let day: String
        if calendar.isDateInToday(date) {
            day = "today"
        } else if calendar.isDateInTomorrow(date) {
            day = "tomorrow"
        } else {
            day = weekdayFormatter.string(from: date)
        }
        return "\(day) at \(time(date))"
    }

    /// What the schedule is doing, for the menu and `wakey status`:
    /// "Wakey until 5:00 PM" or "next Lights today at 5:00 PM".
    static func summary(
        schedule: WeeklySchedule,
        running: ScheduleOccurrence?,
        now: Date
    ) -> String {
        if let running {
            let until = schedule.nextChange(after: now, from: running)
            return "\(running.mode.displayName) until \(time(until))"
        }
        if let next = schedule.nextStart(after: now) {
            return "next \(next.mode.displayName) \(dayAndTime(next.start))"
        }
        return "no blocks on"
    }
}
