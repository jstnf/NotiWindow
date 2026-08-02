import SwiftUI
import UIKit

public extension View {
    /// Install a toast window for this view's scene, driven by `center`.
    ///
    /// Attach once at the app root. The center is supplied rather than created so
    /// non-view code can hold the same reference and present from anywhere.
    ///
    /// The window's lifetime tracks this view, so each scene in a multi-window app
    /// gets its own window and none leak. The same center may drive several scenes at
    /// once: each window keeps its own `NotiFrameStore`, so their toast rects never
    /// overwrite one another. `center` must stay the same instance for the lifetime
    /// of the view it is attached to, though — swapping which center this modifier is
    /// given does not move the hosted window to the new center; see
    /// `NotiWindowInstaller`.
    func notiWindow(_ center: NotiCenter) -> some View {
        background(NotiWindowInstaller(center: center).frame(width: 0, height: 0))
            .environment(\.notiCenter, center)
    }

    /// Install a toast window with a center this modifier owns.
    ///
    /// Convenient when every caller reaches the center through
    /// `@Environment(\.notiCenter)`. Apps that present from non-view code should use
    /// `notiWindow(_:)` and hold the center themselves.
    func notiWindow() -> some View {
        modifier(OwnedNotiWindowModifier())
    }
}

/// Holds a center for the no-argument `notiWindow()` overload.
private struct OwnedNotiWindowModifier: ViewModifier {
    @State private var center = NotiCenter()

    func body(content: Content) -> some View {
        content.notiWindow(center)
    }
}

/// Resolves the scene from the view hierarchy and installs the window into it.
///
/// Reading `window?.windowScene` from a view that is actually in the hierarchy gives
/// the exact scene, avoiding a `UIApplication.connectedScenes` guess that would pick
/// the wrong window in a multi-scene app.
private struct NotiWindowInstaller: UIViewRepresentable {
    let center: NotiCenter

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        let coordinator = context.coordinator
        let center = center

        // `didMoveToWindow` is the reliable signal — `updateUIView` is not guaranteed
        // to fire again once the view reaches a window.
        view.onMoveToWindow = { scene in
            guard coordinator.host == nil, let scene else { return }
            coordinator.host = NotiWindowHost(scene: scene, center: center)
        }

        return view
    }

    // Intentionally empty: `center` is captured once, at `makeUIView`, into the
    // `host` this installs. Re-rendering `.notiWindow(_:)` with a different
    // `NotiCenter` instance does not move the already-hosted window onto it — the
    // center passed to this modifier must stay the same instance for the lifetime
    // of the view it is attached to.
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    static func dismantleUIView(_ uiView: InstallerView, coordinator: Coordinator) {
        MainActor.assumeIsolated {
            coordinator.host?.tearDown()
            coordinator.host = nil
        }
    }

    @MainActor
    final class Coordinator {
        var host: NotiWindowHost?
    }
}

/// Zero-size view whose only job is to report the scene it lands in.
private final class InstallerView: UIView {
    var onMoveToWindow: ((UIWindowScene?) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onMoveToWindow?(window?.windowScene)
    }
}
