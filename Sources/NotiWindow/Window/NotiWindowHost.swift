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

    private let center: NotiCenter

    /// `clearance` is handed in rather than made here, unlike the frame store beside
    /// it. The app publishes into it through the environment, which has to hold it
    /// from the first render — before this host exists at all. It is still one store
    /// per window; the modifier that installs this owns it. See
    /// `NotiWindowInstallerModifier`.
    init(scene: UIWindowScene, center: NotiCenter, clearance: NotiClearance) {
        self.center = center
        let store = frameStore
        let controller = UIHostingController(
            rootView: NotiRootView(center: center, frameStore: store, clearance: clearance)
        )
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
        center.attach()
    }

    /// Match the toast window to the size of the scene it belongs to.
    ///
    /// A window created for a scene keeps the frame it was handed at init. UIKit
    /// resizes the scene's *own* window, not extra ones installed alongside it, so
    /// nothing corrects this on our behalf when the scene resizes — dragging an iPad
    /// window's corner, entering Split View, Stage Manager.
    ///
    /// Left alone the toast window stays whatever size it was born at, and its root
    /// view lays out to those stale bounds: a bottom toast anchors to an edge the
    /// window no longer has, and lands partway up the screen. The rects it reports go
    /// stale the same way, so the window ends up absorbing touches over the wrong band
    /// as well.
    func syncFrameToScene() {
        guard let bounds = window.windowScene?.coordinateSpace.bounds, window.frame != bounds else { return }

        window.frame = bounds
    }

    func tearDown() {
        window.isHidden = true
        window.rootViewController = nil
        center.detach()
    }
}
