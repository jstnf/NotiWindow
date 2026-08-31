import SwiftUI

public extension View {
    /// Tell the toast window how far this view's own chrome reaches, so toasts rest
    /// above it rather than on top of it.
    ///
    /// The toast window is a second window in the scene. It lays out against its own
    /// safe area — the home indicator, the status bar — and can see nothing of the
    /// app's tab bar, which lives in the app's window. This is how it finds out:
    /// the view measures its own safe area, which *does* include the tab bar, and
    /// publishes it to the window above it.
    ///
    /// Attach it to a tab's root content:
    ///
    /// ```swift
    /// TabView {
    ///     Tab("Home", systemImage: "house") {
    ///         HomeScreen()
    ///             .notiClearance()
    ///     }
    /// }
    /// .notiWindow(center)
    /// ```
    ///
    /// Both edges are measured by default: whichever edge the chrome is inset from is
    /// the edge it is published against, and nothing here asks which device it is on.
    ///
    /// **Attach it outside your `NavigationStack`, not inside it.** A navigation bar
    /// is part of its content's top safe area too, so a `.notiClearance()` inside a
    /// stack publishes the navigation bar as clearance and pushes top toasts below it
    /// — measured at 106pt on an iPhone, where there is no top tab bar at all. Outside
    /// the stack, the only thing between the view and the window edge is the chrome
    /// this is meant to clear. Pass an explicit edge set to opt out of one edge.
    ///
    /// Clearance moves where the edge effectively is; `edgeInset` stays the gap from
    /// that edge. So the default 8pt is the same 8pt of breathing room whether a toast
    /// is resting on a tab bar or on the bottom of the screen, and every inset a caller
    /// passes moves the toast. If you were already passing `edgeInset:` to clear this
    /// chrome by hand, delete it — publishing clearance is what replaces it, and the
    /// two add up.
    ///
    /// A tab that does not call this publishes nothing, and toasts there sit at their
    /// own edge as before.
    ///
    /// ## What this cannot see
    ///
    /// A tab bar iPadOS 26 draws across the *top* of the screen, where the tab content
    /// is a `NavigationStack`. Measured on iPadOS 26.5: a stack extends up under that
    /// bar and does not keep the inset, and it extends its container along with it, so
    /// this modifier reads the window's own 32pt whether it is attached around the
    /// stack, beside it, or behind it — the 96pt is visible only to tab content that
    /// contains no stack. There is no `UITabBar` to fall back to either; that bar is
    /// drawn by SwiftUI.
    ///
    /// So on iPad a `.top` toast still draws over the tab bar, and swallows taps on it
    /// for as long as it is up. The bottom edge there is unobstructed —
    /// `present(.bottom)` is the way to stay clear of it — and `edgeInset:` remains the
    /// manual answer for a toast that has to be at the top.
    func notiClearance(_ edges: Set<NotiEdge> = [.top, .bottom]) -> some View {
        modifier(NotiClearanceModifier(edges: edges))
    }
}

/// Publishes one view's safe area to the toast window for as long as it is on screen.
private struct NotiClearanceModifier: ViewModifier {
    let edges: Set<NotiEdge>

    @Environment(\.notiClearance) private var clearance

    /// Identity for this view's contribution, so it can be replaced as the view
    /// re-measures and withdrawn when it goes away, without disturbing any other
    /// view publishing at the same time.
    @State private var id = NotiClearanceID()

    /// Publishing is gated on being on screen because a `TabView` keeps visited tabs
    /// alive: without this, a tab that opted out of clearance would still be lifted by
    /// the tab it was switched away from.
    @State private var isOnScreen = false

    /// The last measurement, held so that appearing and measuring can arrive in either
    /// order — neither one alone is enough to publish.
    @State private var insets = EdgeInsets()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: EdgeInsets.self) { proxy in
                proxy.safeAreaInsets
            } action: { measured in
                insets = measured
                publish()
            }
            .onAppear {
                isOnScreen = true
                publish()
            }
            .onDisappear {
                isOnScreen = false
                clearance.remove(id)
            }
    }

    private func publish() {
        guard isOnScreen else { return }

        clearance.set(insets, edges: edges, for: id)
    }
}
