import Foundation
import IOKit
import IOKit.pwr_mgt

/// Holds the IOKit power assertions a `PowerPlan` describes.
///
/// Knows nothing about modes or `Settings`: it creates, swaps, and releases
/// the assertion set it is given. Call it from the main thread.
final class PowerAssertionController {

    /// IDs held right now, one per successfully created assertion.
    private var heldIDs: [IOPMAssertionID] = []

    /// Assertion types held right now, in the order they were created.
    private(set) var heldTypes: [String] = []

    /// ID from the last `IOPMAssertionDeclareUserActivity` call, passed back on
    /// the next call as IOPMLib.h asks. 0 (kIOPMNullAssertionID) means none yet.
    /// Never released here: the system times the user-activity assertion out.
    private var userActivityID: IOPMAssertionID = 0

    /// Whether any assertion is held.
    var isHolding: Bool { !heldIDs.isEmpty }

    deinit {
        releaseAll()
    }

    /// Holds exactly the assertions in `plan`.
    ///
    /// Creates every new assertion first and only then releases the previously
    /// held ones, so the Mac is never left without an assertion mid-swap.
    ///
    /// - Returns: The assertion types that could not be created (empty on success).
    @discardableResult
    func apply(_ plan: PowerPlan) -> [String] {
        var newIDs: [IOPMAssertionID] = []
        var newTypes: [String] = []
        var failedTypes: [String] = []

        for type in plan.assertionTypes {
            var assertionID: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                plan.assertionName as CFString,
                &assertionID
            )
            if result == kIOReturnSuccess {
                newIDs.append(assertionID)
                newTypes.append(type)
            } else {
                print("WakeyWakey: Failed to create power assertion \(type) (error: \(result))")
                failedTypes.append(type)
            }
        }

        // New set is in place; now drop the old one
        let oldIDs = heldIDs
        heldIDs = newIDs
        heldTypes = newTypes
        for assertionID in oldIDs {
            IOPMAssertionRelease(assertionID)
        }

        return failedTypes
    }

    /// Releases every held assertion.
    func releaseAll() {
        let oldIDs = heldIDs
        heldIDs = []
        heldTypes = []
        for assertionID in oldIDs {
            IOPMAssertionRelease(assertionID)
        }
    }

    /// Declares the local user active once (`caffeinate -u`), which powers the
    /// display on and postpones display sleep up to the Energy Saver setting.
    ///
    /// - Returns: `true` when the declaration succeeded.
    @discardableResult
    func declareUserActivity(name: String) -> Bool {
        var assertionID = userActivityID
        let result = IOPMAssertionDeclareUserActivity(
            name as CFString,
            kIOPMUserActiveLocal,
            &assertionID
        )
        guard result == kIOReturnSuccess else {
            print("WakeyWakey: Failed to declare user activity (error: \(result))")
            return false
        }
        userActivityID = assertionID
        return true
    }
}
