import XCTest

final class JiggleSchedulerTests: XCTestCase {

    private var scheduler = JiggleScheduler()
    private let threshold: TimeInterval = 42

    // The world the scheduler samples. The user was last active at time 0.
    private var lastMouseMoveEventAt: TimeInterval = 0
    private var lastOtherEventAt: TimeInterval = 0
    private var cursor = CGPoint(x: 500, y: 500)

    /// Repeat intervals handed out in order; the last one repeats.
    private var intervals: [TimeInterval] = [20]

    private func tick(_ time: TimeInterval, animating: Bool = false) -> JiggleScheduler.Action {
        let sample = JiggleScheduler.Sample(
            uptime: time,
            mouseMoveIdle: time - lastMouseMoveEventAt,
            otherInputIdle: time - lastOtherEventAt,
            cursor: cursor,
            isAnimating: animating
        )
        return scheduler.evaluate(sample, idleThreshold: threshold) {
            self.intervals.count > 1 ? self.intervals.removeFirst() : self.intervals[0]
        }
    }

    /// One cursor move posted by the app. With `lands` false the system drops
    /// it, as it does without the Accessibility permission.
    private func postOwnMove(at time: TimeInterval, lands: Bool = true) {
        if lands {
            lastMouseMoveEventAt = time
            cursor.x += 5
        }
        scheduler.noteOwnMove(at: time)
    }

    /// A whole jiggle: four moves over 0.6 seconds.
    private func jiggle(at time: TimeInterval, lands: Bool = true) {
        for step in 1...4 {
            postOwnMove(at: time + 0.15 * Double(step), lands: lands)
        }
    }

    private func userMovesMouse(at time: TimeInterval) {
        lastMouseMoveEventAt = time
        cursor.y += 40
    }

    private func userTypes(at time: TimeInterval) {
        lastOtherEventAt = time
    }

    /// Ticks once a second, jiggling whenever told to. Returns when it jiggled.
    private func run(from start: Int, through end: Int, lands: Bool = true) -> [Int] {
        var jiggledAt: [Int] = []
        for second in start...end where tick(TimeInterval(second)) == .jiggle {
            jiggledAt.append(second)
            jiggle(at: TimeInterval(second), lands: lands)
        }
        return jiggledAt
    }

    // MARK: - First Jiggle

    func testFirstJiggleComesWhenTheIdleThresholdIsReached() {
        XCTAssertEqual(tick(1), .userActive)
        XCTAssertEqual(tick(41), .userActive)
        XCTAssertEqual(tick(42), .jiggle)
    }

    func testTypingRestartsTheIdleWait() {
        userTypes(at: 30)
        XCTAssertEqual(run(from: 1, through: 80), [72])
    }

    // MARK: - Repeats

    func testRepeatsAtTheIntervalNotTheIdleThreshold() {
        intervals = [20]
        XCTAssertEqual(run(from: 1, through: 110), [42, 62, 82, 102])
    }

    func testRepeatIntervalLongerThanTheIdleThreshold() {
        intervals = [79]
        XCTAssertEqual(run(from: 1, through: 205), [42, 121, 200])
    }

    func testEachRepeatUsesAFreshInterval() {
        intervals = [12, 79, 30]
        XCTAssertEqual(run(from: 1, through: 170), [42, 54, 133, 163])
    }

    func testOwnJiggleIsNotUserActivity() {
        XCTAssertEqual(tick(42), .jiggle)
        jiggle(at: 42)

        // The idle clock now reads under a second and the cursor has moved
        XCTAssertEqual(tick(43), .wait)
        XCTAssertEqual(tick(44), .wait)
    }

    func testTickInTheMiddleOfAJiggleWaits() {
        XCTAssertEqual(tick(42), .jiggle)
        postOwnMove(at: 42.7)
        postOwnMove(at: 42.95)
        XCTAssertEqual(tick(43, animating: true), .wait)
        postOwnMove(at: 43.2)
        XCTAssertEqual(tick(44), .wait)
        XCTAssertEqual(tick(45), .wait)
    }

    func testRepeatsWhenItsMovesNeverLand() {
        // No Accessibility: the idle clock and the cursor never change
        intervals = [20]
        XCTAssertEqual(run(from: 1, through: 90, lands: false), [42, 62, 82])
    }

    // MARK: - The User Comes Back

    func testRealMouseMoveAfterAJiggleIsUserActivity() {
        XCTAssertEqual(run(from: 1, through: 50), [42])

        userMovesMouse(at: 50.5)
        XCTAssertEqual(tick(51), .userActive)

        // The full threshold again, counted from the user's move
        XCTAssertEqual(run(from: 52, through: 120), [93, 113])
    }

    func testKeyPressAfterAJiggleIsUserActivity() {
        XCTAssertEqual(run(from: 1, through: 50), [42])

        userTypes(at: 50.5)
        XCTAssertEqual(tick(51), .userActive)
        XCTAssertEqual(run(from: 52, through: 100), [93])
    }

    func testCursorMovedWithoutEventsIsUserActivity() {
        XCTAssertEqual(run(from: 1, through: 50), [42])

        // Universal Control: the cursor moves, no event is registered
        cursor.y += 40
        XCTAssertEqual(tick(51), .userActive)

        // Not a jiggle the moment the cursor stops: the full threshold again
        XCTAssertEqual(tick(52), .userActive)
        XCTAssertEqual(run(from: 53, through: 100), [93])
    }

    func testSmallCursorDriftIsIgnored() {
        XCTAssertEqual(tick(1), .userActive)
        cursor.x += JiggleScheduler.cursorMoveThreshold
        XCTAssertEqual(run(from: 2, through: 50), [42])
    }

    // MARK: - Reset

    func testResetMakesTheNextJiggleImmediate() {
        intervals = [79]
        XCTAssertEqual(run(from: 1, through: 50), [42])

        // Turned off, then on again later with the user still away
        scheduler.reset()
        XCTAssertEqual(tick(60), .jiggle)
    }

    func testCursorMovedWhileOffIsNotSeenAsTheUser() {
        XCTAssertEqual(run(from: 1, through: 50), [42])

        scheduler.reset()
        cursor = CGPoint(x: 100, y: 100)
        XCTAssertEqual(tick(200), .jiggle)
    }
}
