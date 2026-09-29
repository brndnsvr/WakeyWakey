import Foundation

/// A stretch of time WakeyWakey is enabled for: open-ended, or ending at a
/// wall-clock time.
///
/// Foundation only: no AppKit, no `Settings`. `AppDelegate` saves the live
/// session on every change so the next launch after a restart, logout,
/// crash, or upgrade can resume it; tests check the resume rules directly.
enum EnabledSession: Equatable {
    case indefinite
    case until(Date)

    /// The session to resume at launch, or `nil` to start disabled.
    ///
    /// A timed session keeps its wall-clock end, so time spent shut down
    /// counts against it, and one that ended while the Mac was off is not
    /// resumed.
    static func resumable(_ saved: EnabledSession?, now: Date) -> EnabledSession? {
        switch saved {
        case .indefinite:
            return .indefinite
        case .until(let end):
            return end > now ? .until(end) : nil
        case nil:
            return nil
        }
    }
}

/// Persists the last enabled session in `UserDefaults`.
struct EnabledSessionStore {

    private enum Key {
        static let enabled = "savedSessionEnabled"
        static let expiresAt = "savedSessionExpiresAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The saved session, or `nil` when WakeyWakey was last disabled.
    func load() -> EnabledSession? {
        guard defaults.bool(forKey: Key.enabled) else { return nil }
        if let end = defaults.object(forKey: Key.expiresAt) as? Date {
            return .until(end)
        }
        return .indefinite
    }

    /// Saves `session`; `nil` clears it.
    func save(_ session: EnabledSession?) {
        switch session {
        case .indefinite:
            defaults.set(true, forKey: Key.enabled)
            defaults.removeObject(forKey: Key.expiresAt)
        case .until(let end):
            defaults.set(true, forKey: Key.enabled)
            defaults.set(end, forKey: Key.expiresAt)
        case nil:
            defaults.removeObject(forKey: Key.enabled)
            defaults.removeObject(forKey: Key.expiresAt)
        }
    }
}
