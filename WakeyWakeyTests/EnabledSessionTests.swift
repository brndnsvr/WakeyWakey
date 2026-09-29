import XCTest

final class EnabledSessionTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Resume Rules

    func testNothingSavedStaysDisabled() {
        XCTAssertNil(EnabledSession.resumable(nil, now: now))
    }

    func testIndefiniteSessionResumes() {
        XCTAssertEqual(EnabledSession.resumable(.indefinite, now: now), .indefinite)
    }

    func testTimedSessionResumesWithSameEnd() {
        let end = now.addingTimeInterval(2 * 3600)
        XCTAssertEqual(EnabledSession.resumable(.until(end), now: now), .until(end))
    }

    func testTimedSessionThatEndedWhileOffStaysDisabled() {
        let end = now.addingTimeInterval(-60)
        XCTAssertNil(EnabledSession.resumable(.until(end), now: now))
    }

    func testTimedSessionEndingExactlyNowStaysDisabled() {
        // Matches tick(), which disables once Date() >= timerExpiresAt
        XCTAssertNil(EnabledSession.resumable(.until(now), now: now))
    }

    // MARK: - Store

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "EnabledSessionTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testEmptyStoreLoadsNil() {
        XCTAssertNil(EnabledSessionStore(defaults: defaults).load())
    }

    func testStoreRoundTripsEachSession() {
        let store = EnabledSessionStore(defaults: defaults)
        let end = now.addingTimeInterval(3600)

        store.save(.indefinite)
        XCTAssertEqual(store.load(), .indefinite)

        store.save(.until(end))
        XCTAssertEqual(store.load(), .until(end))

        store.save(nil)
        XCTAssertNil(store.load())
    }

    func testIndefiniteAfterTimedDropsTheOldEnd() {
        let store = EnabledSessionStore(defaults: defaults)
        store.save(.until(now.addingTimeInterval(3600)))
        store.save(.indefinite)
        XCTAssertEqual(store.load(), .indefinite)
    }

    func testClearingLeavesNoStaleEndBehind() {
        let store = EnabledSessionStore(defaults: defaults)
        store.save(.until(now.addingTimeInterval(3600)))
        store.save(nil)
        store.save(.indefinite)
        XCTAssertEqual(store.load(), .indefinite)
    }

    func testStoreSurvivesANewInstance() {
        // A relaunch reads through a fresh store over the same defaults
        let end = now.addingTimeInterval(1800)
        EnabledSessionStore(defaults: defaults).save(.until(end))
        XCTAssertEqual(EnabledSessionStore(defaults: defaults).load(), .until(end))
    }
}
