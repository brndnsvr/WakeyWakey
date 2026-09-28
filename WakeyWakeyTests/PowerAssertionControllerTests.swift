import XCTest
import IOKit
import IOKit.pwr_mgt

/// Exercises real IOKit assertions for this test process and reads them back
/// with IOPMCopyAssertionsByProcess. Each test holds assertions only briefly
/// and tearDown releases everything.
///
/// declareUserActivity is deliberately not called here: it would wake the
/// host's display.
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

    // MARK: - Helpers

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
