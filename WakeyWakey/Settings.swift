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
    }

    // MARK: - Defaults

    private enum Default {
        static let timerDuration1: TimeInterval = 3600      // 1 hour
        static let timerDuration2: TimeInterval = 14400     // 4 hours
        static let timerDuration3: TimeInterval = 32400     // 9 hours
        static let idleThreshold: TimeInterval = 42
        static let jiggleIntervalMin: TimeInterval = 42
        static let jiggleIntervalMax: TimeInterval = 79
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

    // MARK: - Computed Properties

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
    }
}
