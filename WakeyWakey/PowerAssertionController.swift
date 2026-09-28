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

    /// Default lifetime of a user-activity declaration: `caffeinate -u`'s 5 s
    /// default timeout.
    static let defaultUserActivityDuration: TimeInterval = 5

    /// ID of the live user-activity assertion, passed back on the next
    /// declaration as IOPMLib.h asks. 0 (kIOPMNullAssertionID) means none live.
    private var userActivityID: IOPMAssertionID = 0

    /// Pending release of `userActivityID`. The system timeout follows the
    /// display-sleep setting (never, when it is 0), so release it ourselves.
    private var pendingUserActivityRelease: DispatchWorkItem?

    private let userActivityDuration: TimeInterval
    private let declareUserActivityCall: (String, inout IOPMAssertionID) -> IOReturn
    private let releaseUserActivityCall: (IOPMAssertionID) -> Void

    /// Whether any assertion is held.
    var isHolding: Bool { !heldIDs.isEmpty }

    /// The parameters exist so tests can avoid waking the host display;
    /// the app uses the IOKit defaults.
    init(
        userActivityDuration: TimeInterval = PowerAssertionController.defaultUserActivityDuration,
        declareUserActivity: @escaping (String, inout IOPMAssertionID) -> IOReturn = { name, assertionID in
            IOPMAssertionDeclareUserActivity(name as CFString, kIOPMUserActiveLocal, &assertionID)
        },
        releaseUserActivity: @escaping (IOPMAssertionID) -> Void = { assertionID in
            _ = IOPMAssertionRelease(assertionID)
        }
    ) {
        self.userActivityDuration = userActivityDuration
        self.declareUserActivityCall = declareUserActivity
        self.releaseUserActivityCall = releaseUserActivity
    }

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

    /// Releases every held assertion, including a live user-activity one.
    func releaseAll() {
        let oldIDs = heldIDs
        heldIDs = []
        heldTypes = []
        for assertionID in oldIDs {
            IOPMAssertionRelease(assertionID)
        }
        releaseUserActivity()
    }

    /// Declares the local user active (`caffeinate -u`), which powers the
    /// display on. The declaration is released after `userActivityDuration`
    /// (5 s, like `caffeinate -u`), or sooner by `releaseAll()`.
    ///
    /// - Returns: `true` when the declaration succeeded.
    @discardableResult
    func declareUserActivity(name: String) -> Bool {
        var assertionID = userActivityID
        let result = declareUserActivityCall(name, &assertionID)
        guard result == kIOReturnSuccess else {
            print("WakeyWakey: Failed to declare user activity (error: \(result))")
            return false
        }
        userActivityID = assertionID

        // A new declaration restarts the clock: drop any earlier pending release
        pendingUserActivityRelease?.cancel()
        let release = DispatchWorkItem { [weak self] in
            self?.releaseUserActivity()
        }
        pendingUserActivityRelease = release
        DispatchQueue.main.asyncAfter(deadline: .now() + userActivityDuration, execute: release)
        return true
    }

    /// Releases the live user-activity assertion, if any, and cancels its timer.
    private func releaseUserActivity() {
        pendingUserActivityRelease?.cancel()
        pendingUserActivityRelease = nil
        guard userActivityID != 0 else { return }
        releaseUserActivityCall(userActivityID)
        userActivityID = 0
    }
}
