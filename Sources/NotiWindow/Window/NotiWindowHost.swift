import SwiftUI
import UIKit

/// Owns the toast window for one scene.
///
/// This is the seam the `.notiWindow(_:)` modifier is a thin wrapper over: it can be
/// constructed directly against a scene, which is what makes the window's
/// configuration testable without driving a SwiftUI hierarchy.
///
/// Teardown deliberately touches no `NotiCenter` state. The center outlives the
/// window, so a rebuilt scene re-renders whatever is still live rather than
/// inheriting a cleared or frozen slot.
@MainActor
final class NotiWindowHost {
    let window: PassthroughWindow

    /// This window's own toast rects. Owned here so the root view that writes them
    /// and the window that reads them are looking at the same store, and so a second
    /// scene driven by the same center gets a second, independent one.
    let frameStore = NotiFrameStore()

    init(scene: UIWindowScene, center: NotiCenter) {
        let store = frameStore
        let controller = UIHostingController(rootView: NotiRootView(center: center, frameStore: store))
        controller.view.backgroundColor = .clear

        window = PassthroughWindow(windowScene: scene, frameStore: store)
        window.notiCenter = center
        window.rootViewController = controller
        window.backgroundColor = .clear
        // Above sheets and above system alerts — the reason this library exists.
        window.windowLevel = .alert + 1
        // Visible without ever becoming key, so the app keeps first responder and
        // text fields elsewhere are unaffected.
        window.isHidden = false
    }

    func tearDown() {
        window.isHidden = true
        window.rootViewController = nil
    }
}
