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
    static func passesThrough(hitView: UIView?, rootView: UIView?) -> Bool {
        hitView == nil || hitView === rootView
    }
}
