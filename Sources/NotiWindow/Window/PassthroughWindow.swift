import UIKit

/// A window that is invisible to touches except where a toast actually is.
///
/// Sits above the app's own window, so without this override it would swallow every
/// touch in the app. Controls inside a toast keep working normally, because a hit on
/// them resolves to a descendant rather than the backdrop.
final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)

        if NotiHitTesting.passesThrough(hitView: hitView, rootView: rootViewController?.view) {
            return nil
        }

        return hitView
    }
}
