import XCTest

final class PowerPlanTests: XCTestCase {

    // MARK: - Wakey

    func testWakeyPlanMatchesOriginalBehavior() {
        let plan = PowerPlan.make(
            mode: .wakey,
            keepDisplayOn: true,
            preventSystemSleep: true,
            wakeDisplay: true
        )
        XCTAssertEqual(plan.assertionTypes, ["PreventUserIdleDisplaySleep"])
        XCTAssertEqual(plan.assertionName, "WakeyWakey Active")
        XCTAssertFalse(plan.declaresUserActivity)
        XCTAssertTrue(plan.simulatesInput)
        XCTAssertTrue(plan.needsAccessibility)
        XCTAssertNil(plan.caffeinateEquivalent)
    }

    func testWakeyPlanIgnoresLightsOptions() {
        let expected = PowerPlan.make(
            mode: .wakey,
            keepDisplayOn: true,
            preventSystemSleep: true,
            wakeDisplay: true
        )
        for d in [false, true] {
            for s in [false, true] {
                for u in [false, true] {
                    XCTAssertEqual(
                        PowerPlan.make(mode: .wakey, keepDisplayOn: d, preventSystemSleep: s, wakeDisplay: u),
                        expected,
                        "Wakey plan changed with d=\(d) s=\(s) u=\(u)"
                    )
                }
            }
        }
    }

    // MARK: - Lights

    func testLightsAllOptionsOnMatchesCaffeinateDisu() {
        let plan = PowerPlan.make(
            mode: .lights,
            keepDisplayOn: true,
            preventSystemSleep: true,
            wakeDisplay: true
        )
        XCTAssertEqual(
            plan.assertionTypes,
            ["PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep", "PreventSystemSleep"]
        )
        XCTAssertEqual(plan.assertionName, "WakeyWakey Lights")
        XCTAssertTrue(plan.declaresUserActivity)
        XCTAssertFalse(plan.simulatesInput)
        XCTAssertFalse(plan.needsAccessibility)
        XCTAssertEqual(plan.caffeinateEquivalent, "caffeinate -disu")
    }

    func testLightsAllOptionsOffHoldsOnlyIdleSystemSleep() {
        let plan = PowerPlan.make(
            mode: .lights,
            keepDisplayOn: false,
            preventSystemSleep: false,
            wakeDisplay: false
        )
        XCTAssertEqual(plan.assertionTypes, ["PreventUserIdleSystemSleep"])
        XCTAssertEqual(plan.assertionName, "WakeyWakey Lights")
        XCTAssertFalse(plan.declaresUserActivity)
        XCTAssertFalse(plan.simulatesInput)
        XCTAssertFalse(plan.needsAccessibility)
        XCTAssertEqual(plan.caffeinateEquivalent, "caffeinate -i")
    }

    func testLightsKeepDisplayOnOnly() {
        let plan = PowerPlan.make(
            mode: .lights,
            keepDisplayOn: true,
            preventSystemSleep: false,
            wakeDisplay: false
        )
        XCTAssertEqual(plan.assertionTypes, ["PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep"])
        XCTAssertEqual(plan.assertionName, "WakeyWakey Lights")
        XCTAssertFalse(plan.declaresUserActivity)
        XCTAssertFalse(plan.simulatesInput)
        XCTAssertFalse(plan.needsAccessibility)
        XCTAssertEqual(plan.caffeinateEquivalent, "caffeinate -di")
    }

    func testLightsPreventSystemSleepOnly() {
        let plan = PowerPlan.make(
            mode: .lights,
            keepDisplayOn: false,
            preventSystemSleep: true,
            wakeDisplay: false
        )
        XCTAssertEqual(plan.assertionTypes, ["PreventUserIdleSystemSleep", "PreventSystemSleep"])
        XCTAssertEqual(plan.assertionName, "WakeyWakey Lights")
        XCTAssertFalse(plan.declaresUserActivity)
        XCTAssertFalse(plan.simulatesInput)
        XCTAssertFalse(plan.needsAccessibility)
        XCTAssertEqual(plan.caffeinateEquivalent, "caffeinate -is")
    }

    func testLightsWakeDisplayOnly() {
        let plan = PowerPlan.make(
            mode: .lights,
            keepDisplayOn: false,
            preventSystemSleep: false,
            wakeDisplay: true
        )
        XCTAssertEqual(plan.assertionTypes, ["PreventUserIdleSystemSleep"])
        XCTAssertEqual(plan.assertionName, "WakeyWakey Lights")
        XCTAssertTrue(plan.declaresUserActivity)
        XCTAssertFalse(plan.simulatesInput)
        XCTAssertFalse(plan.needsAccessibility)
        XCTAssertEqual(plan.caffeinateEquivalent, "caffeinate -iu")
    }

    func testLightsAssertionOrderIsStableAcrossAllCombinations() {
        let canonical = ["PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep", "PreventSystemSleep"]
        for d in [false, true] {
            for s in [false, true] {
                for u in [false, true] {
                    let plan = PowerPlan.make(mode: .lights, keepDisplayOn: d, preventSystemSleep: s, wakeDisplay: u)
                    XCTAssertEqual(plan.assertionTypes.first, "PreventUserIdleSystemSleep")
                    XCTAssertEqual(
                        plan.assertionTypes,
                        canonical.filter { plan.assertionTypes.contains($0) },
                        "Out of order with d=\(d) s=\(s) u=\(u)"
                    )
                    XCTAssertEqual(plan.assertionTypes.contains("PreventUserIdleDisplaySleep"), d)
                    XCTAssertEqual(plan.assertionTypes.contains("PreventSystemSleep"), s)
                    XCTAssertEqual(plan.declaresUserActivity, u)
                }
            }
        }
    }

    // MARK: - Mode

    func testKeepAwakeModeRawValues() {
        XCTAssertEqual(KeepAwakeMode.allCases, [.wakey, .lights])
        XCTAssertEqual(KeepAwakeMode.wakey.rawValue, "wakey")
        XCTAssertEqual(KeepAwakeMode.lights.rawValue, "lights")
        XCTAssertNil(KeepAwakeMode(rawValue: "bogus"))
    }
}
