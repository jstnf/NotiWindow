import NotiWindow
import SwiftUI

@main
struct NotiWindowExampleApp: App {
    /// Held here rather than created by the modifier, mirroring how a real app
    /// presents toasts from non-view code.
    @State private var center = NotiCenter()

    var body: some Scene {
        WindowGroup {
            DemoScreen(center: center)
                .notiWindow(center)
        }
    }
}
