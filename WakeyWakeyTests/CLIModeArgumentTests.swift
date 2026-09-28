import XCTest

final class CLIModeArgumentTests: XCTestCase {

    func testParsesValidLowercaseValues() {
        XCTAssertEqual(CLIModeArgument.parse("wakey"), .wakey)
        XCTAssertEqual(CLIModeArgument.parse("lights"), .lights)
    }

    func testParsesCaseInsensitively() {
        XCTAssertEqual(CLIModeArgument.parse("WAKEY"), .wakey)
        XCTAssertEqual(CLIModeArgument.parse("Lights"), .lights)
        XCTAssertEqual(CLIModeArgument.parse("LiGhTs"), .lights)
    }

    func testRejectsInvalidValues() {
        XCTAssertNil(CLIModeArgument.parse("bogus"))
        XCTAssertNil(CLIModeArgument.parse(""))
        XCTAssertNil(CLIModeArgument.parse("wake"))
    }
}
