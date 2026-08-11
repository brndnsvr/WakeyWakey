import XCTest

final class DurationParserTests: XCTestCase {
    func testParsesMinuteAndHourDurations() {
        XCTAssertEqual(DurationParser.parse("20m"), 1_200)
        XCTAssertEqual(DurationParser.parse("4h"), 14_400)
        XCTAssertEqual(DurationParser.parse("3.5h"), 12_600)
    }

    func testParsingIsCaseInsensitiveAndTrimsWhitespace() {
        XCTAssertEqual(DurationParser.parse("  1.5H\n"), 5_400)
    }

    func testRejectsInvalidOrNonPositiveDurations() {
        for input in ["", "20", "minutes", "0m", "-1h", "1d", "infinityh", "1e308h"] {
            XCTAssertNil(DurationParser.parse(input), "Expected \(input) to be rejected")
        }
    }
}
