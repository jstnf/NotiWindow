import SwiftUI

/// The default handed to views with no `.notiWindow(_:)` above them.
///
/// `EnvironmentKey.defaultValue` is a nonisolated protocol requirement, so an
/// isolated conformance is what lets a main-actor type supply one at all. The value
/// is shared process-wide; `NotiCenter` warns in debug builds when something presents
/// into a center no window is rendering, which is what that sharing would otherwise
/// hide.
private struct NotiCenterKey: @MainActor EnvironmentKey {
    @MainActor static var defaultValue = NotiCenter()
}

public extension EnvironmentValues {
    /// The toast center installed by `.notiWindow(_:)`.
    ///
    /// Views below a `.notiWindow(_:)` find that modifier's center here. Views with no
    /// `.notiWindow(_:)` above them find a shared default that renders nowhere.
    @MainActor var notiCenter: NotiCenter {
        get { self[NotiCenterKey.self] }
        set { self[NotiCenterKey.self] = newValue }
    }
}
