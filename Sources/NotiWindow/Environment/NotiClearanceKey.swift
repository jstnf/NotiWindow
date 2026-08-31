import SwiftUI

/// The default handed to views with no `.notiWindow(_:)` above them.
///
/// Shared process-wide, exactly like the default center: a `.notiClearance(_:)` with
/// no toast window above it publishes into a store nothing renders from, which is
/// inert rather than wrong.
private struct NotiClearanceKey: @MainActor EnvironmentKey {
    @MainActor static var defaultValue = NotiClearance()
}

extension EnvironmentValues {
    /// The clearance store belonging to the toast window installed by `.notiWindow(_:)`.
    ///
    /// Not public: apps publish through `.notiClearance(_:)` rather than by reaching
    /// for the store, so there is nothing here a caller needs to name.
    @MainActor var notiClearance: NotiClearance {
        get { self[NotiClearanceKey.self] }
        set { self[NotiClearanceKey.self] = newValue }
    }
}
