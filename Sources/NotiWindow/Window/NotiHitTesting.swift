import UIKit

/// The passthrough decision, isolated from `UIWindow` so it can be tested directly.
enum NotiHitTesting {
    /// Whether a hit-test result means "nothing of ours was touched", and the touch
    /// should therefore fall through to the app's own window.
    ///
    /// Identity against the root view is used rather than comparing against toast
    /// frames: frame math gets rounded corners, transforms, and in-flight transition
    /// geometry wrong, whereas "did we hit anything other than the transparent
    /// backdrop" is correct by construction.
    ///
    /// A window with no root view has no content to hit, so it must never absorb
    /// a touch. Failing open degrades to "the toast does not appear" rather than
    /// "the app stops responding".
    static func passesThrough(hitView: UIView?, rootView: UIView?) -> Bool {
        hitView == nil || rootView == nil || hitView === rootView
    }
}
