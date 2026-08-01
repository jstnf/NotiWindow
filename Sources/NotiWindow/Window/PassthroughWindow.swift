import UIKit

/// A window that is invisible to touches except where a toast actually is.
///
/// Sits above the app's own window, so without this override it would swallow every
/// touch in the app. The live toasts' own frames define where "actually is" ends: the
/// window asks the center that renders into it, and hands every touch outside those
/// frames back to the app. Inside them the touch is delivered normally, which is what
/// makes tap-to-dismiss, swipe-to-dismiss, and buttons inside a toast work.
final class PassthroughWindow: UIWindow {
    /// The center whose live toast frames decide what this window absorbs.
    ///
    /// Weak because the center outlives the window; a window must never be the reason
    /// a center stays alive. With no center the window absorbs nothing, which is the
    /// harmless direction to fail in.
    weak var notiCenter: NotiCenter?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let contentFrames = notiCenter.map { Array($0.contentFrames.values) } ?? []

        if NotiHitTesting.passesThrough(point: point, contentFrames: contentFrames) {
            return nil
        }

        return super.hitTest(point, with: event)
    }
}
