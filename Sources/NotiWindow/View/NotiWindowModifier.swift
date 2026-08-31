import SwiftUI
import UIKit

public extension View {
    /// Install a toast window for this view's scene, driven by `center`.
    ///
    /// Attach once at the app root. The center is supplied rather than created so
    /// non-view code can hold the same reference and present from anywhere.
    ///
    /// The window's lifetime tracks this view, so each scene in a multi-window app
    /// gets its own window and none leak. One center may drive several scenes at
    /// once: each window keeps its own record of where its toasts are.
    ///
    /// This is also what scopes `.notiClearance(_:)`. The chrome a view publishes goes
    /// to the window installed here, so a `.notiClearance(_:)` must be *below* this
    /// modifier to reach anything — one attached above it publishes into a default
    /// nothing renders from, and its toasts sit at their own edge as though it were
    /// not there.
    ///
    /// `center` must stay the same instance for the lifetime of the view it is
    /// attached to — swapping which center this modifier is given does not move the
    /// hosted window to the new center; see `NotiWindowInstaller`.
    func notiWindow(_ center: NotiCenter) -> some View {
        modifier(NotiWindowInstallerModifier(center: center))
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

/// Installs the window, and keeps it the size of the scene it lives in.
///
/// The size is observed here, on the app's own content, because that is what reliably
/// re-lays out when the scene resizes. The toast window is a second window in the same
/// scene and UIKit does not resize it for us, so a change here is the signal to go and
/// correct it — see `NotiWindowHost.syncFrameToScene`.
private struct NotiWindowInstallerModifier: ViewModifier {
    let center: NotiCenter

    @State private var sceneSize: CGSize = .zero

    /// This window's clearance store — where `.notiClearance(_:)` publishes the app's
    /// chrome to. One per installed window, like the frame store, because chrome
    /// measured in one scene means nothing in another.
    ///
    /// Owned here rather than by `NotiWindowHost` because it has to be in the
    /// environment from the first render, and the host is not created until the
    /// installer reaches a window.
    @State private var clearance = NotiClearance()

    func body(content: Content) -> some View {
        content
            // Zero-size so it can never become a touch target of its own: it exists
            // only to resolve the scene and to carry `sceneSize` into `updateUIView`.
            .background(
                NotiWindowInstaller(center: center, clearance: clearance, sceneSize: sceneSize)
                    .frame(width: 0, height: 0)
            )
            .environment(\.notiCenter, center)
            .environment(\.notiClearance, clearance)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                sceneSize = size
            }
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

    /// Handed to the window this installs, so the root view reads the same store the
    /// app's `.notiClearance(_:)` modifiers publish into.
    let clearance: NotiClearance

    /// The app content's current size. Not read directly — it is here so that a scene
    /// resize changes this view's inputs, which is what gets `updateUIView` called.
    let sceneSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        let coordinator = context.coordinator
        let center = center
        let clearance = clearance

        // `didMoveToWindow` is the reliable signal — `updateUIView` is not guaranteed
        // to fire again once the view reaches a window.
        view.onMoveToWindow = { scene in
            guard coordinator.host == nil, let scene else { return }
            coordinator.host = NotiWindowHost(scene: scene, center: center, clearance: clearance)
        }

        return view
    }

    /// Re-sizes the toast window to the scene, which is the only thing this does.
    ///
    /// `center` is deliberately *not* re-read: it is captured once, at `makeUIView`,
    /// into the `host` this installs. Re-rendering `.notiWindow(_:)` with a different
    /// `NotiCenter` instance does not move the already-hosted window onto it — the
    /// center passed to this modifier must stay the same instance for the lifetime of
    /// the view it is attached to.
    func updateUIView(_ uiView: InstallerView, context: Context) {
        context.coordinator.host?.syncFrameToScene()
    }

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
