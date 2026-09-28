import Foundation

/// How WakeyWakey keeps the Mac awake.
/// - `wakey`: the original behavior. Holds one display-sleep assertion and
///   jiggles the cursor after the user goes idle.
/// - `lights`: holds the power assertions of `caffeinate -disu` and posts
///   no simulated input.
enum KeepAwakeMode: String, CaseIterable {
    case wakey
    case lights
}

/// A pure description of what a mode holds while enabled.
///
/// Foundation only: no IOKit, no `Settings`. The power engine turns this
/// into real IOKit assertions; tests check the mapping directly.
struct PowerPlan: Equatable {

    /// Raw IOKit assertion type strings, always in this relative order:
    /// "PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep",
    /// "PreventSystemSleep". Raw strings are used because the SDK constant
    /// for "PreventSystemSleep" is deprecated, although `caffeinate -s`
    /// still creates it.
    let assertionTypes: [String]

    /// Name shown for the assertions in `pmset -g assertions`.
    let assertionName: String

    /// Whether to call `IOPMAssertionDeclareUserActivity` once on enable (`-u`).
    let declaresUserActivity: Bool

    /// Whether the idle-triggered cursor jiggle runs.
    let simulatesInput: Bool

    /// Whether the mode needs the Accessibility permission (to post CGEvents).
    let needsAccessibility: Bool

    /// The equivalent `caffeinate` command line, or `nil` when there is none.
    let caffeinateEquivalent: String?

    // MARK: - Assertion type strings

    static let preventUserIdleSystemSleep = "PreventUserIdleSystemSleep"
    static let preventUserIdleDisplaySleep = "PreventUserIdleDisplaySleep"
    static let preventSystemSleep = "PreventSystemSleep"

    // MARK: - Assertion names

    static let wakeyAssertionName = "WakeyWakey Active"
    static let lightsAssertionName = "WakeyWakey Lights"

    // MARK: - Factory

    /// Builds the plan for a mode. The Lights options are ignored in Wakey.
    /// - Parameters:
    ///   - keepDisplayOn: Lights `-d`: also hold PreventUserIdleDisplaySleep.
    ///   - preventSystemSleep: Lights `-s`: also hold PreventSystemSleep (AC power only).
    ///   - wakeDisplay: Lights `-u`: declare user activity once on enable.
    static func make(
        mode: KeepAwakeMode,
        keepDisplayOn: Bool,
        preventSystemSleep: Bool,
        wakeDisplay: Bool
    ) -> PowerPlan {
        switch mode {
        case .wakey:
            // Must match the pre-Lights behavior exactly.
            return PowerPlan(
                assertionTypes: [Self.preventUserIdleDisplaySleep],
                assertionName: Self.wakeyAssertionName,
                declaresUserActivity: false,
                simulatesInput: true,
                needsAccessibility: true,
                caffeinateEquivalent: nil
            )

        case .lights:
            var types = [Self.preventUserIdleSystemSleep]
            if keepDisplayOn { types.append(Self.preventUserIdleDisplaySleep) }
            if preventSystemSleep { types.append(Self.preventSystemSleep) }

            // caffeinate flag letters in order: d? i s? u?
            var flags = ""
            if keepDisplayOn { flags += "d" }
            flags += "i"
            if preventSystemSleep { flags += "s" }
            if wakeDisplay { flags += "u" }

            return PowerPlan(
                assertionTypes: types,
                assertionName: Self.lightsAssertionName,
                declaresUserActivity: wakeDisplay,
                simulatesInput: false,
                needsAccessibility: false,
                caffeinateEquivalent: "caffeinate -" + flags
            )
        }
    }
}
