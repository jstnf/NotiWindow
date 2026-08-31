import NotiWindow
import SwiftUI

@main
struct NotiWindowExampleApp: App {
    /// Held here rather than created by the modifier, mirroring how a real app
    /// presents toasts from non-view code.
    @State private var center = NotiCenter()

    var body: some Scene {
        WindowGroup {
            // A plain `TabView` with no `tabViewStyle`, so each platform places the bar
            // where it wants to: the bottom on iPhone, the top on iPad. `.notiClearance()`
            // measures both edges — though only the iPhone bar is measurable, since the
            // iPad one is drawn by SwiftUI above a `NavigationStack` that keeps none of
            // its inset. See the modifier's own documentation.
            TabView {
                // Attached out here, to the tab's root content rather than inside the
                // screen's own `NavigationStack`. Inside the stack it would measure the
                // navigation bar as chrome too and push top toasts below it.
                Tab("Placement", systemImage: "arrow.up.and.down") {
                    PlacementScreen(center: center)
                        .notiClearance()
                }

                Tab("Lifetime", systemImage: "clock") {
                    LifetimeScreen(center: center)
                        .notiClearance()
                }

                Tab("Content", systemImage: "square.stack") {
                    ContentScreen(center: center)
                        .notiClearance()
                }

                // Deliberately without `.notiClearance()`: toasts presented here sit at
                // the true window edge, over the tab bar, so both behaviours are one tap
                // apart.
                Tab("Passthrough", systemImage: "hand.tap") {
                    PassthroughScreen(center: center)
                }
            }
            .notiWindow(center)
        }
    }
}
