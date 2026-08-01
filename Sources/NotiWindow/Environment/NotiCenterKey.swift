import SwiftUI

public extension EnvironmentValues {
    /// The toast center installed by `.notiWindow(_:)`, if one is.
    ///
    /// Optional because an `EnvironmentValues` default must be constructible from a
    /// nonisolated context, and `NotiCenter.init()` is main-actor isolated. Views
    /// below a `.notiWindow(_:)` always find a value here.
    @Entry var notiCenter: NotiCenter?
}
