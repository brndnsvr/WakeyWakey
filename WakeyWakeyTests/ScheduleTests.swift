import XCTest

final class ScheduleTests: XCTestCase {

    private var calendar = Calendar(identifier: .gregorian)

    /// Mon–Fri 8:00–17:00 Wakey, then 17:00–20:00 Lights.
    private let workday = ScheduleBlock(weekdays: [2, 3, 4, 5, 6], startMinute: 8 * 60, endMinute: 17 * 60, mode: .wakey)
    private let evening = ScheduleBlock(weekdays: [2, 3, 4, 5, 6], startMinute: 17 * 60, endMinute: 20 * 60, mode: .lights)
    /// Mon–Fri 12:00–13:00 Lights, nested inside `workday`.
    private let lunch = ScheduleBlock(weekdays: [2, 3, 4, 5, 6], startMinute: 12 * 60, endMinute: 13 * 60, mode: .lights)

    override func setUpWithError() throws {
        try super.setUpWithError()
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
    }

    /// 2026-09-28 is a Monday; 2026-10-03 a Saturday.
    private func date(month: Int = 9, _ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)))
    }

    private func schedule(_ blocks: [ScheduleBlock]) -> WeeklySchedule {
        WeeklySchedule(blocks: blocks, calendar: calendar)
    }

    // MARK: - Which Block Is In Charge

    func testBlockRunsOnlyOnItsWeekdays() throws {
        let week = schedule([workday])
        XCTAssertEqual(week.current(at: try date(28, 9))?.mode, .wakey)
        XCTAssertNil(week.current(at: try date(month: 10, 3, 9)))
    }

    func testEndIsExclusiveAndNextBlockTakesOver() throws {
        let week = schedule([workday, evening])
        XCTAssertNil(week.current(at: try date(28, 7, 55)))
        XCTAssertEqual(week.current(at: try date(28, 16, 59))?.mode, .wakey)
        XCTAssertEqual(week.current(at: try date(28, 17))?.mode, .lights)
        XCTAssertNil(week.current(at: try date(28, 20)))
    }

    func testLaterStartWinsInsideALongerBlock() throws {
        // List order doesn't matter: lunch starts later, so it wins
        let week = schedule([lunch, workday])
        XCTAssertEqual(week.current(at: try date(28, 11, 55))?.mode, .wakey)
        XCTAssertEqual(week.current(at: try date(28, 12, 30))?.mode, .lights)
        XCTAssertEqual(week.current(at: try date(28, 13))?.mode, .wakey)
    }

    func testSameStartGoesToTheBlockFurtherDownTheList() throws {
        let other = ScheduleBlock(weekdays: [2], startMinute: 8 * 60, endMinute: 10 * 60, mode: .lights)
        XCTAssertEqual(schedule([workday, other]).current(at: try date(28, 9))?.mode, .lights)
        XCTAssertEqual(schedule([other, workday]).current(at: try date(28, 9))?.mode, .wakey)
    }

    func testDisabledBlocksAreIgnored() throws {
        var off = workday
        off.isEnabled = false
        XCTAssertNil(schedule([off]).current(at: try date(28, 9)))
    }

    // MARK: - Midnight and Clock Changes

    func testOvernightBlockRunsPastMidnight() throws {
        let night = ScheduleBlock(weekdays: [6], startMinute: 22 * 60, endMinute: 6 * 60, mode: .lights)
        let week = schedule([night])

        let running = try XCTUnwrap(week.current(at: try date(month: 10, 3, 3)))
        XCTAssertEqual(running.start, try date(month: 10, 2, 22))
        XCTAssertEqual(running.end, try date(month: 10, 3, 6))
        XCTAssertNil(week.current(at: try date(month: 10, 3, 6)))
    }

    func testSaturdayNightRunsIntoSunday() throws {
        let night = ScheduleBlock(weekdays: [7], startMinute: 22 * 60, endMinute: 2 * 60, mode: .wakey)
        XCTAssertEqual(schedule([night]).current(at: try date(month: 10, 4, 1))?.mode, .wakey)
    }

    func testEndStaysOnTheWallClockAcrossDaylightSavingChange() throws {
        // US clocks fall back at 2:00 on Sunday 2026-11-01
        let night = ScheduleBlock(weekdays: [7], startMinute: 22 * 60, endMinute: 6 * 60, mode: .lights)
        let running = try XCTUnwrap(schedule([night]).current(at: try date(month: 11, 1, 5, 30)))
        XCTAssertEqual(running.end, try date(month: 11, 1, 6))
    }

    func testStartEqualToEndMeansAFullDay() {
        let allDay = ScheduleBlock(weekdays: [2], startMinute: 9 * 60, endMinute: 9 * 60, mode: .wakey)
        XCTAssertEqual(allDay.durationMinutes, ScheduleBlock.minutesPerDay)
    }

    // MARK: - What Comes Next

    func testNextStartLooksAcrossTheWeekend() throws {
        let next = try XCTUnwrap(schedule([workday, evening]).nextStart(after: try date(month: 10, 2, 20)))
        XCTAssertEqual(next.start, try date(month: 10, 5, 8))
        XCTAssertEqual(next.mode, .wakey)
    }

    func testNextChangeStopsAtANestedStart() throws {
        let week = schedule([workday, lunch, evening])
        let now = try date(28, 10)
        let running = try XCTUnwrap(week.current(at: now))
        XCTAssertEqual(week.nextChange(after: now, from: running), try date(28, 12))

        let afternoon = try date(28, 15)
        let later = try XCTUnwrap(week.current(at: afternoon))
        XCTAssertEqual(week.nextChange(after: afternoon, from: later), try date(28, 17))
    }

    // MARK: - Storage

    func testRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode([workday, evening])
        XCTAssertEqual(try JSONDecoder().decode([ScheduleBlock].self, from: data), [workday, evening])
    }

    func testDecodingSnapsOddValuesOntoTheGrid() throws {
        let json = """
        {"id":"\(UUID().uuidString)","isEnabled":true,"weekdays":[0,2,9],"startMinute":487,"endMinute":1500,"mode":"lights"}
        """
        let block = try JSONDecoder().decode(ScheduleBlock.self, from: Data(json.utf8))
        XCTAssertEqual(block.weekdays, [2])
        XCTAssertEqual(block.startMinute, 485)
        XCTAssertEqual(block.endMinute, 60)
    }

    func testOverlapWeekdays() {
        XCTAssertEqual(ScheduleBlock.overlapWeekdays(in: [workday, lunch]), [2, 3, 4, 5, 6])
        XCTAssertEqual(ScheduleBlock.overlapWeekdays(in: [workday, evening]), [])
    }

    // MARK: - Driver

    func testTurnsOnAtBlockStart() throws {
        var driver = ScheduleDriver()
        let action = driver.evaluate(schedule: schedule([workday]), now: try date(28, 8), isEnabled: false, enabledBySchedule: false)
        XCTAssertEqual(action, .enable(.wakey))
    }

    func testSwitchesModeOnceBetweenBlocksThenTurnsOff() throws {
        var driver = ScheduleDriver()
        let week = schedule([workday, evening])
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 8), isEnabled: false, enabledBySchedule: false), .enable(.wakey))
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 16, 59), isEnabled: true, enabledBySchedule: true), .none)
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 17), isEnabled: true, enabledBySchedule: true), .switchMode(.lights))
        // A mode you pick mid-block isn't switched back
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 17, 1), isEnabled: true, enabledBySchedule: true), .none)
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 20), isEnabled: true, enabledBySchedule: true), .disable)
    }

    func testLeavesASessionYouStartedAlone() throws {
        var driver = ScheduleDriver()
        let week = schedule([workday])
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 9), isEnabled: true, enabledBySchedule: false), .none)
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 18), isEnabled: true, enabledBySchedule: false), .none)
    }

    func testManualOffSkipsTheRestOfTheBlock() throws {
        var driver = ScheduleDriver()
        let week = schedule([workday, evening])
        _ = driver.evaluate(schedule: week, now: try date(28, 8), isEnabled: false, enabledBySchedule: false)

        driver.skipRunning(in: week, at: try date(28, 10))
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 10), isEnabled: false, enabledBySchedule: false), .none)
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 16, 59), isEnabled: false, enabledBySchedule: false), .none)
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 17), isEnabled: false, enabledBySchedule: false), .enable(.lights))
        XCTAssertTrue(driver.skipped.isEmpty, "a skip is dropped once its block ends")
    }

    func testManualOffInANestedBlockSkipsTheOuterBlockToo() throws {
        var driver = ScheduleDriver()
        let week = schedule([workday, lunch, evening])
        driver.skipRunning(in: week, at: try date(28, 12, 30))
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 13), isEnabled: false, enabledBySchedule: false), .none)
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 17), isEnabled: false, enabledBySchedule: false), .enable(.lights))
    }

    func testYourTimerEndingInsideABlockHandsBackToTheSchedule() throws {
        var driver = ScheduleDriver()
        let week = schedule([workday])
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 9), isEnabled: true, enabledBySchedule: false), .none)
        XCTAssertEqual(driver.evaluate(schedule: week, now: try date(28, 10), isEnabled: false, enabledBySchedule: false), .enable(.wakey))
    }

    func testTurningTheScheduleOffEndsWhatItStarted() throws {
        var driver = ScheduleDriver()
        _ = driver.evaluate(schedule: schedule([workday]), now: try date(28, 8), isEnabled: false, enabledBySchedule: false)
        XCTAssertEqual(driver.evaluate(schedule: nil, now: try date(28, 9), isEnabled: true, enabledBySchedule: true), .disable)
    }
}
