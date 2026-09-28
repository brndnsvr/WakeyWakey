import XCTest
import IOKit
import IOKit.pwr_mgt

/// Exercises real IOKit assertions for this test process and reads them back
/// with IOPMCopyAssertionsByProcess. Each test holds assertions only briefly
/// and tearDown releases everything.
///
/// The real IOPMAssertionDeclareUserActivity is never called here: it would
/// wake the host's display. The user-activity tests inject fakes instead.
final class PowerAssertionControllerTests: XCTestCase {

    private var controller: PowerAssertionController!

    private let wakeyPlan = PowerPlan.make(
        mode: .wakey,
        keepDisplayOn: true,
        preventSystemSleep: true,
        wakeDisplay: true
    )

    // -disu
    private let lightsAllOnPlan = PowerPlan.make(
        mode: .lights,
        keepDisplayOn: true,
        preventSystemSleep: true,
        wakeDisplay: true
    )

    // -i only
    private let lightsIdleOnlyPlan = PowerPlan.make(
        mode: .lights,
        keepDisplayOn: false,
        preventSystemSleep: false,
        wakeDisplay: false
    )

    override func setUp() {
        super.setUp()
        controller = PowerAssertionController()
        XCTAssertEqual(heldAssertions().count, 0, "WakeyWakey assertions leaked in from an earlier test")
    }

    override func tearDown() {
        controller.releaseAll()
        controller = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testApplyWakeyPlanHoldsExactlyOneDisplayAssertion() {
        XCTAssertEqual(controller.apply(wakeyPlan), [])

        let held = heldAssertions()
        XCTAssertEqual(held.count, 1)
        XCTAssertEqual(held.first?.type, "PreventUserIdleDisplaySleep")
        XCTAssertEqual(held.first?.name, "WakeyWakey Active")
        XCTAssertTrue(controller.isHolding)
        XCTAssertEqual(controller.heldTypes, ["PreventUserIdleDisplaySleep"])
    }

    func testApplyLightsAllOnReplacesWakeyAssertion() {
        controller.apply(wakeyPlan)
        XCTAssertEqual(controller.apply(lightsAllOnPlan), [])

        let held = heldAssertions()
        XCTAssertEqual(held.count, 3)
        XCTAssertEqual(
            Set(held.map(\.type)),
            ["PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep", "PreventSystemSleep"]
        )
        XCTAssertTrue(held.allSatisfy { $0.name == "WakeyWakey Lights" })
        XCTAssertFalse(held.contains { $0.name == "WakeyWakey Active" }, "Old Wakey assertion still held")
        XCTAssertEqual(
            controller.heldTypes,
            ["PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep", "PreventSystemSleep"]
        )
    }

    func testApplyLightsIdleOnlyDropsDisplayAndSystemSleep() {
        controller.apply(lightsAllOnPlan)
        XCTAssertEqual(controller.apply(lightsIdleOnlyPlan), [])

        let held = heldAssertions()
        XCTAssertEqual(held.count, 1)
        XCTAssertEqual(held.first?.type, "PreventUserIdleSystemSleep")
        XCTAssertEqual(held.first?.name, "WakeyWakey Lights")
        XCTAssertEqual(controller.heldTypes, ["PreventUserIdleSystemSleep"])
    }

    func testReleaseAllLeavesNone() {
        controller.apply(lightsAllOnPlan)
        XCTAssertEqual(heldAssertions().count, 3)

        controller.releaseAll()

        XCTAssertEqual(heldAssertions().count, 0)
        XCTAssertFalse(controller.isHolding)
        XCTAssertEqual(controller.heldTypes, [])
    }

    // MARK: - User activity (-u), with fake IOKit calls

    func testReleaseAllReleasesUserActivityImmediately() {
        let fake = FakeUserActivity()
        let controller = makeController(fake: fake, duration: 0.2)

        XCTAssertTrue(controller.declareUserActivity(name: "WakeyWakey Lights"))
        XCTAssertEqual(fake.released, [])

        controller.releaseAll()
        XCTAssertEqual(fake.released, [101])

        // The pending timed release was cancelled: no second release
        spinMainRunLoop(for: 0.4)
        XCTAssertEqual(fake.released, [101])
    }

    func testUserActivityIsReleasedAfterDuration() {
        let fake = FakeUserActivity()
        let controller = makeController(fake: fake, duration: 0.3)

        XCTAssertTrue(controller.declareUserActivity(name: "WakeyWakey Lights"))
        spinMainRunLoop(for: 0.1)
        XCTAssertEqual(fake.released, [])

        spinMainRunLoop(for: 0.4)
        XCTAssertEqual(fake.released, [101])

        // Once released, the next declaration starts fresh instead of passing back a dead ID
        XCTAssertTrue(controller.declareUserActivity(name: "WakeyWakey Lights"))
        XCTAssertEqual(fake.passedIn, [0, 0])
        controller.releaseAll()
    }

    func testNewDeclarationCancelsPendingRelease() {
        let fake = FakeUserActivity()
        let controller = makeController(fake: fake, duration: 0.5)

        XCTAssertTrue(controller.declareUserActivity(name: "WakeyWakey Lights"))  // t = 0
        spinMainRunLoop(for: 0.3)
        XCTAssertTrue(controller.declareUserActivity(name: "WakeyWakey Lights"))  // t = 0.3
        XCTAssertEqual(fake.passedIn, [0, 101], "Live ID must be passed back")

        // Past the first deadline (0.5): its release must have been cancelled
        spinMainRunLoop(for: 0.35)
        XCTAssertEqual(fake.released, [])

        // Past the second deadline (0.8): released exactly once
        spinMainRunLoop(for: 0.4)
        XCTAssertEqual(fake.released, [101])
    }

    // MARK: - Helpers

    /// Stands in for IOPMAssertionDeclareUserActivity and IOPMAssertionRelease.
    /// Like powerd, it keeps a live ID that is passed back and issues a new
    /// one otherwise.
    private final class FakeUserActivity {
        private var lastIssuedID: IOPMAssertionID = 100
        private(set) var passedIn: [IOPMAssertionID] = []
        private(set) var released: [IOPMAssertionID] = []

        func declare(_ name: String, _ assertionID: inout IOPMAssertionID) -> IOReturn {
            passedIn.append(assertionID)
            if assertionID == 0 {
                lastIssuedID += 1
                assertionID = lastIssuedID
            }
            return kIOReturnSuccess
        }

        func release(_ assertionID: IOPMAssertionID) {
            released.append(assertionID)
        }
    }

    private func makeController(fake: FakeUserActivity, duration: TimeInterval) -> PowerAssertionController {
        PowerAssertionController(
            userActivityDuration: duration,
            declareUserActivity: { name, assertionID in fake.declare(name, &assertionID) },
            releaseUserActivity: { assertionID in fake.release(assertionID) }
        )
    }

    /// Lets main-queue work (the timed release) run while the test waits.
    private func spinMainRunLoop(for seconds: TimeInterval) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
    }

    /// WakeyWakey assertions this process holds, as powerd reports them.
    private func heldAssertions(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> [(type: String, name: String)] {
        var byPID: Unmanaged<CFDictionary>?
        let result = IOPMCopyAssertionsByProcess(&byPID)
        XCTAssertEqual(result, kIOReturnSuccess, "IOPMCopyAssertionsByProcess failed", file: file, line: line)

        guard let dict = byPID?.takeRetainedValue() as NSDictionary?,
              let mine = dict[NSNumber(value: getpid())] as? [[String: Any]] else {
            return []
        }

        return mine.compactMap { assertion in
            guard let type = assertion[kIOPMAssertionTypeKey as String] as? String,
                  let name = assertion[kIOPMAssertionNameKey as String] as? String,
                  name.hasPrefix("WakeyWakey") else {
                return nil
            }
            return (type, name)
        }
    }
}
