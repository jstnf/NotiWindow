import UIKit

/// A window that is invisible to touches except where a toast actually is.
///
/// Sits above the app's own window, so without this override it would swallow every
/// touch in the app. The live toasts' own frames define where "actually is" ends: the
/// window asks its own frame store where its toasts landed, and hands every touch
/// outside those frames back to the app. Inside them the touch is delivered normally,
/// which is what makes tap-to-dismiss, swipe-to-dismiss, and buttons inside a toast
/// work.
final class PassthroughWindow: UIWindow {
    /// Where this window's own toasts were last measured.
    let frameStore: NotiFrameStore

    /// The center that says which toasts are still on screen.
    ///
    /// Weak because the center outlives the window; a window must never be the reason
    /// a center stays alive. With no center the window absorbs nothing, which is the
    /// harmless direction to fail in.
    weak var notiCenter: NotiCenter?

    init(windowScene: UIWindowScene, frameStore: NotiFrameStore) {
        self.frameStore = frameStore
        super.init(windowScene: windowScene)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("NotiWindow does not support decoding a PassthroughWindow")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let contentFrames = MainActor.assumeIsolated {
            frameStore.liveFrames(for: notiCenter?.liveTokens ?? [])
        }

        if NotiHitTesting.passesThrough(point: point, contentFrames: contentFrames) {
            return nil
        }

        return super.hitTest(point, with: event)
    }
}
