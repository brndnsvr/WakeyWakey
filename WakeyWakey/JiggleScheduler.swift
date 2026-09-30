import Foundation

/// Decides when Wakey jiggles the cursor.
///
/// A jiggle is posted as real input, which is the point: it resets the idle
/// clock that other apps read. It also resets the clock this app reads and
/// moves the cursor this app watches. Taken at face value, every jiggle looks
/// like the user coming back, so the app would wait out the whole idle
/// threshold again and the repeat interval would never apply.
///
/// So the scheduler keeps its own idea of when the user was last active and
/// leaves its own jiggles out of it:
/// - A mouse-moved event as old as the last jiggle is the jiggle itself.
/// - Cursor movement while a jiggle is in flight is the jiggle too.
/// - Keys, clicks, drags and scrolling are never posted here, so they always
///   count as the user.
///
/// Times are on the uptime clock, the one the system idle times run on.
struct JiggleScheduler {

    enum Action: Equatable {
        /// Idle, and the next jiggle is not due yet.
        case wait
        /// The user is around: stop any jiggle in flight.
        case userActive
        /// Jiggle now.
        case jiggle
    }

    /// What one tick can see.
    struct Sample {
        var uptime: TimeInterval
        /// Since the last mouse-moved event, which may be a jiggle.
        var mouseMoveIdle: TimeInterval
        /// Since the last key, click, drag or scroll.
        var otherInputIdle: TimeInterval
        var cursor: CGPoint
        var isAnimating: Bool
    }

    /// How far the cursor must move between ticks to count as the user.
    /// Universal Control moves it without any input event this Mac can see.
    static let cursorMoveThreshold: CGFloat = 0.5

    /// Slack between posting an event and the system accounting for it, both
    /// in the idle clock and in the cursor position.
    static let ownMoveTolerance: TimeInterval = 0.25

    private(set) var nextDueAt: TimeInterval?
    private var lastUserActivityAt: TimeInterval?
    private var lastOwnMoveAt: TimeInterval?
    private var lastCursor: CGPoint?
    private var cursorNeedsBaseline = false

    /// Record that the app just posted a cursor move of its own.
    mutating func noteOwnMove(at uptime: TimeInterval) {
        lastOwnMoveAt = uptime
        cursorNeedsBaseline = true
    }

    /// Forget the pending jiggle, as when Wakey is turned off. The next time
    /// the user is idle past the threshold, the first jiggle is immediate.
    /// Nothing watches the cursor while Wakey is off, so where it was is
    /// forgotten too.
    mutating func reset() {
        nextDueAt = nil
        lastCursor = nil
    }

    mutating func evaluate(
        _ sample: Sample,
        idleThreshold: TimeInterval,
        nextInterval: () -> TimeInterval
    ) -> Action {
        let ownMoveAge = lastOwnMoveAt.map { sample.uptime - $0 }

        // Cursor: a move nobody sent an event for is still the user
        var cursorMoved = false
        let ownMoveInFlight = sample.isAnimating || (ownMoveAge.map { $0 < Self.ownMoveTolerance } ?? false)
        if ownMoveInFlight {
            // The cursor is where the jiggle is putting it
        } else if cursorNeedsBaseline {
            // First look after a jiggle: this is where it left the cursor
            lastCursor = sample.cursor
            cursorNeedsBaseline = false
        } else {
            if let last = lastCursor {
                cursorMoved = abs(sample.cursor.x - last.x) > Self.cursorMoveThreshold
                    || abs(sample.cursor.y - last.y) > Self.cursorMoveThreshold
            }
            lastCursor = sample.cursor
        }

        // Input events: leave out a mouse move that is the jiggle itself
        let mouseMoveIsOwn = ownMoveAge.map { sample.mouseMoveIdle >= $0 - Self.ownMoveTolerance } ?? false
        let inputIdle = mouseMoveIsOwn
            ? sample.otherInputIdle
            : min(sample.otherInputIdle, sample.mouseMoveIdle)

        let seenActivityAt = cursorMoved ? sample.uptime : sample.uptime - inputIdle
        let activityAt = max(lastUserActivityAt ?? seenActivityAt, seenActivityAt)
        lastUserActivityAt = activityAt

        if sample.uptime - activityAt < idleThreshold {
            // Back to waiting for the full threshold, then an immediate jiggle
            nextDueAt = nil
            return .userActive
        }

        if let due = nextDueAt, sample.uptime < due {
            return .wait
        }

        nextDueAt = sample.uptime + nextInterval()
        return .jiggle
    }
}
