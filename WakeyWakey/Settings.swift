import Foundation
import Combine

/// Centralized settings manager for WakeyWakey preferences.
/// Uses UserDefaults for persistence with type-safe access.
final class Settings: ObservableObject {

    static let shared = Settings()

    // MARK: - Keys

    private enum Key: String {
        case timerDuration1
        case timerDuration2
        case timerDuration3
        case idleThreshold
        case jiggleIntervalMin
        case jiggleIntervalMax
        case mode
        case lightsKeepDisplayOn
        case lightsPreventSystemSleep
        case lightsWakeDisplay
        case restoreAfterRestart
        case scheduleEnabled
        case scheduleBlocks
        case modeBeforeSchedule
    }

    // MARK: - Defaults

    private enum Default {
        static let timerDuration1: TimeInterval = 4200      // 1 hour 10 minutes
        static let timerDuration2: TimeInterval = 15600     // 4 hours 20 minutes
        static let timerDuration3: TimeInterval = 32400     // 9 hours
        static let idleThreshold: TimeInterval = 42
        static let jiggleIntervalMin: TimeInterval = 12
        static let jiggleIntervalMax: TimeInterval = 79
        static let mode: KeepAwakeMode = .wakey
        static let lightsKeepDisplayOn = true       // caffeinate -d
        static let lightsPreventSystemSleep = true  // caffeinate -s
        static let lightsWakeDisplay = true         // caffeinate -u
        static let restoreAfterRestart = true
        // Scratch runs (previews, the Settings scheme) open on the example schedule
        static let scheduleEnabled = ProcessInfo.processInfo.usesScratchPreferences
        static let scheduleBlocks: [ScheduleBlock] = ProcessInfo.processInfo.usesScratchPreferences
            ? ScheduleBlock.samples
            : []
    }

    // MARK: - Storage

    /// Xcode previews and the "WakeyWakey Settings" scheme run under the app's
    /// bundle ID, so they get a scratch domain instead of the real preferences.
    private let defaults: UserDefaults = ProcessInfo.processInfo.usesScratchPreferences
        ? UserDefaults(suiteName: "com.brndnsvr.WakeyWakey.previews") ?? .standard
        : .standard

    // MARK: - Timer Durations

    @Published var timerDuration1: TimeInterval {
        didSet { defaults.set(timerDuration1, forKey: Key.timerDuration1.rawValue) }
    }

    @Published var timerDuration2: TimeInterval {
        didSet { defaults.set(timerDuration2, forKey: Key.timerDuration2.rawValue) }
    }

    @Published var timerDuration3: TimeInterval {
        didSet { defaults.set(timerDuration3, forKey: Key.timerDuration3.rawValue) }
    }

    // MARK: - Jiggle Parameters

    @Published var idleThreshold: TimeInterval {
        didSet { defaults.set(idleThreshold, forKey: Key.idleThreshold.rawValue) }
    }

    @Published var jiggleIntervalMin: TimeInterval {
        didSet {
            // Ensure max >= min
            if jiggleIntervalMax < jiggleIntervalMin {
                jiggleIntervalMax = jiggleIntervalMin
            }
            defaults.set(jiggleIntervalMin, forKey: Key.jiggleIntervalMin.rawValue)
        }
    }

    @Published var jiggleIntervalMax: TimeInterval {
        didSet {
            // Ensure max >= min
            if jiggleIntervalMax < jiggleIntervalMin {
                jiggleIntervalMax = jiggleIntervalMin
            }
            defaults.set(jiggleIntervalMax, forKey: Key.jiggleIntervalMax.rawValue)
        }
    }

    // MARK: - Keep-Awake Mode

    @Published var mode: KeepAwakeMode {
        didSet {
            defaults.set(mode.rawValue, forKey: Key.mode.rawValue)
            // You picked a mode yourself: keep it after the scheduled block
            if !isApplyingScheduledMode {
                modeBeforeSchedule = nil
            }
        }
    }

    // MARK: - Lights Options

    /// Lights `-d`: also prevent display idle sleep.
    @Published var lightsKeepDisplayOn: Bool {
        didSet { defaults.set(lightsKeepDisplayOn, forKey: Key.lightsKeepDisplayOn.rawValue) }
    }

    /// Lights `-s`: also prevent system sleep (AC power only).
    @Published var lightsPreventSystemSleep: Bool {
        didSet { defaults.set(lightsPreventSystemSleep, forKey: Key.lightsPreventSystemSleep.rawValue) }
    }

    /// Lights `-u`: declare user activity once on enable (wakes the display).
    @Published var lightsWakeDisplay: Bool {
        didSet { defaults.set(lightsWakeDisplay, forKey: Key.lightsWakeDisplay.rawValue) }
    }

    // MARK: - Restart

    /// Resume the enabled session (and its timer) when WakeyWakey relaunches
    /// after a restart, logout, crash, or upgrade.
    @Published var restoreAfterRestart: Bool {
        didSet { defaults.set(restoreAfterRestart, forKey: Key.restoreAfterRestart.rawValue) }
    }

    // MARK: - Schedule

    /// Follow `scheduleBlocks`: turn on at each block's start, off at its end.
    @Published var scheduleEnabled: Bool {
        didSet { defaults.set(scheduleEnabled, forKey: Key.scheduleEnabled.rawValue) }
    }

    @Published var scheduleBlocks: [ScheduleBlock] {
        didSet {
            if let data = try? JSONEncoder().encode(scheduleBlocks) {
                defaults.set(data, forKey: Key.scheduleBlocks.rawValue)
            }
        }
    }

    /// The mode a scheduled block replaced, put back once no block is running.
    /// Kept on disk so a restart mid-block still restores it.
    private(set) var modeBeforeSchedule: KeepAwakeMode? {
        didSet { defaults.set(modeBeforeSchedule?.rawValue, forKey: Key.modeBeforeSchedule.rawValue) }
    }

    private var isApplyingScheduledMode = false

    /// Switches to a block's mode, remembering the mode it replaces.
    func applyScheduledMode(_ scheduledMode: KeepAwakeMode) {
        if modeBeforeSchedule == nil {
            modeBeforeSchedule = mode
        }
        guard scheduledMode != mode else { return }
        isApplyingScheduledMode = true
        mode = scheduledMode
        isApplyingScheduledMode = false
    }

    /// Puts back the mode the schedule replaced, if you haven't picked one since.
    func restoreModeBeforeSchedule() {
        guard let saved = modeBeforeSchedule else { return }
        isApplyingScheduledMode = true
        mode = saved
        isApplyingScheduledMode = false
        modeBeforeSchedule = nil
    }

    // MARK: - Computed Properties

    /// What the current mode and Lights options hold while enabled
    var powerPlan: PowerPlan {
        PowerPlan.make(
            mode: mode,
            keepDisplayOn: lightsKeepDisplayOn,
            preventSystemSleep: lightsPreventSystemSleep,
            wakeDisplay: lightsWakeDisplay
        )
    }

    /// Returns timer durations as array for menu building
    var timerDurations: [TimeInterval] {
        [timerDuration1, timerDuration2, timerDuration3]
    }

    /// Random jiggle interval within configured range
    var randomJiggleInterval: TimeInterval {
        let min = Int(jiggleIntervalMin)
        let max = Int(jiggleIntervalMax)
        guard min <= max else { return jiggleIntervalMin }
        return TimeInterval(Int.random(in: min...max))
    }

    // MARK: - Init

    private init() {
        // Load persisted values or use defaults
        self.timerDuration1 = defaults.object(forKey: Key.timerDuration1.rawValue) as? TimeInterval
            ?? Default.timerDuration1
        self.timerDuration2 = defaults.object(forKey: Key.timerDuration2.rawValue) as? TimeInterval
            ?? Default.timerDuration2
        self.timerDuration3 = defaults.object(forKey: Key.timerDuration3.rawValue) as? TimeInterval
            ?? Default.timerDuration3
        self.idleThreshold = defaults.object(forKey: Key.idleThreshold.rawValue) as? TimeInterval
            ?? Default.idleThreshold
        self.jiggleIntervalMin = defaults.object(forKey: Key.jiggleIntervalMin.rawValue) as? TimeInterval
            ?? Default.jiggleIntervalMin
        self.jiggleIntervalMax = defaults.object(forKey: Key.jiggleIntervalMax.rawValue) as? TimeInterval
            ?? Default.jiggleIntervalMax
        // Unknown or missing stored mode falls back to the default
        self.mode = defaults.string(forKey: Key.mode.rawValue).flatMap(KeepAwakeMode.init(rawValue:))
            ?? Default.mode
        self.lightsKeepDisplayOn = defaults.object(forKey: Key.lightsKeepDisplayOn.rawValue) as? Bool
            ?? Default.lightsKeepDisplayOn
        self.lightsPreventSystemSleep = defaults.object(forKey: Key.lightsPreventSystemSleep.rawValue) as? Bool
            ?? Default.lightsPreventSystemSleep
        self.lightsWakeDisplay = defaults.object(forKey: Key.lightsWakeDisplay.rawValue) as? Bool
            ?? Default.lightsWakeDisplay
        self.restoreAfterRestart = defaults.object(forKey: Key.restoreAfterRestart.rawValue) as? Bool
            ?? Default.restoreAfterRestart
        self.scheduleEnabled = defaults.object(forKey: Key.scheduleEnabled.rawValue) as? Bool
            ?? Default.scheduleEnabled
        // Unreadable stored blocks fall back to the default
        self.scheduleBlocks = defaults.data(forKey: Key.scheduleBlocks.rawValue)
            .flatMap { try? JSONDecoder().decode([ScheduleBlock].self, from: $0) }
            ?? Default.scheduleBlocks
        self.modeBeforeSchedule = defaults.string(forKey: Key.modeBeforeSchedule.rawValue)
            .flatMap(KeepAwakeMode.init(rawValue:))
    }

    // MARK: - Helpers

    /// Formats duration for menu display (e.g., "1 hour", "4 hours", "1 hr 30 min")
    func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if minutes == 0 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else if hours == 0 {
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        } else {
            let h = hours == 1 ? "1 hr" : "\(hours) hrs"
            let m = minutes == 1 ? "1 min" : "\(minutes) min"
            return "\(h) \(m)"
        }
    }

    /// Resets all settings to defaults
    func resetToDefaults() {
        timerDuration1 = Default.timerDuration1
        timerDuration2 = Default.timerDuration2
        timerDuration3 = Default.timerDuration3
        idleThreshold = Default.idleThreshold
        jiggleIntervalMin = Default.jiggleIntervalMin
        jiggleIntervalMax = Default.jiggleIntervalMax
        mode = Default.mode
        lightsKeepDisplayOn = Default.lightsKeepDisplayOn
        lightsPreventSystemSleep = Default.lightsPreventSystemSleep
        lightsWakeDisplay = Default.lightsWakeDisplay
        restoreAfterRestart = Default.restoreAfterRestart
        // Turn the schedule off but keep its blocks: they take real effort to
        // set up, and checking the box brings them straight back
        scheduleEnabled = Default.scheduleEnabled
    }
}

extension ProcessInfo {
    /// True inside an Xcode canvas preview.
    var isRunningForXcodePreviews: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// True when launched by the "WakeyWakey Settings" scheme.
    var isSettingsOnlyRun: Bool {
        environment["WAKEY_SETTINGS_ONLY"] == "1"
    }

    var usesScratchPreferences: Bool {
        isRunningForXcodePreviews || isSettingsOnlyRun
    }
}
