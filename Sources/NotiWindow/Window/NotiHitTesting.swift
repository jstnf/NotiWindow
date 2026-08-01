import CoreGraphics

/// The passthrough decision, isolated from `UIWindow` so it can be tested directly.
enum NotiHitTesting {
    /// Whether a touch at `point` should fall through to the app's own window.
    ///
    /// The decision is made against the live toasts' reported frames rather than
    /// against the identity of the hit-test result. SwiftUI draws a toast inside the
    /// hosting view itself rather than in a `UIView` of its own, so `super.hitTest`
    /// answers "the hosting view" for toast content and transparent backdrop alike.
    /// An identity check cannot tell those apart, and so treats every touch as
    /// backdrop — leaving the toast unable to receive a tap, a swipe, or a press on a
    /// button inside it.
    ///
    /// An empty frame list means nothing of ours is on screen, so every touch belongs
    /// to the app. That is also the safe answer when the frames are unknown: failing
    /// open degrades to "the toast is not interactive" rather than "the app stops
    /// responding".
    static func passesThrough(point: CGPoint, contentFrames: [CGRect]) -> Bool {
        !contentFrames.contains { $0.contains(point) }
    }
}
