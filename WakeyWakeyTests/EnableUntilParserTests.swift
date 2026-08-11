import XCTest

final class EnableUntilParserTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testExplicitPMUsesTodayWhenStillAhead() {
        let now = date(day: 11, hour: 16, minute: 15)
        XCTAssertEqual(
            EnableUntilParser.nextDate(for: "5pm", after: now, calendar: calendar),
            date(day: 11, hour: 17)
        )
    }

    func testExplicitPMUsesTomorrowWhenAlreadyPassed() {
        let now = date(day: 11, hour: 18)
        XCTAssertEqual(
            EnableUntilParser.nextDate(for: "5:00 PM", after: now, calendar: calendar),
            date(day: 12, hour: 17)
        )
    }

    func testAmbiguousTimeUsesNextTwelveHourOccurrence() {
        XCTAssertEqual(
            EnableUntilParser.nextDate(
                for: "5:00",
                after: date(day: 11, hour: 16, minute: 15),
                calendar: calendar
            ),
            date(day: 11, hour: 17)
        )
        XCTAssertEqual(
            EnableUntilParser.nextDate(
                for: "5:00",
                after: date(day: 11, hour: 18),
                calendar: calendar
            ),
            date(day: 12, hour: 5)
        )
    }

    func testMidnightAndNoon() {
        XCTAssertEqual(
            EnableUntilParser.nextDate(
                for: "12pm",
                after: date(day: 11, hour: 11, minute: 50),
                calendar: calendar
            ),
            date(day: 11, hour: 12)
        )
        XCTAssertEqual(
            EnableUntilParser.nextDate(
                for: "12am",
                after: date(day: 11, hour: 23, minute: 50),
                calendar: calendar
            ),
            date(day: 12, hour: 0)
        )
    }

    func testRejectsDurationsAndInvalidClockTimes() {
        for input in ["", "5", "20m", "3.5h", "0:30", "13:00", "5:60", "5:0"] {
            XCTAssertNil(EnableUntilParser.nextDate(for: input, calendar: calendar))
        }
    }

    private func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: day,
            hour: hour,
            minute: minute,
            second: 0
        ))!
    }
}
