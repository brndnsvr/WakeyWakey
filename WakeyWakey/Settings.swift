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
    }

    // MARK: - Storage

    private let defaults = UserDefaults.standard

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
        didSet { defaults.set(mode.rawValue, forKey: Key.mode.rawValue) }
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
    }
}
