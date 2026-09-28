import Foundation

/// Parses a `mode` argument from the `wakey` CLI into a `KeepAwakeMode`.
///
/// Validation is case-insensitive and pure (Foundation only), so it can run
/// client-side before any IPC and again server-side inside the app.
enum CLIModeArgument {
    static func parse(_ input: String) -> KeepAwakeMode? {
        KeepAwakeMode(rawValue: input.lowercased())
    }
}
