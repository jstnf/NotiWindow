@testable import NotiWindow
import SwiftUI
import Testing
import UIKit

/// Window-configuration tests, hosted by the example app.
///
/// These live here rather than in the package's own test bundle because that bundle
/// runs as the bare `xctest` tool, where `UIApplication.shared.connectedScenes` is
/// empty. An app-hosted test target has a real `UIWindowScene`, which is what
/// `NotiWindowHost` requires.
@Suite("NotiWindowHost")
@MainActor
struct NotiWindowHostTests {
    /// The runner app's window scene. A nil scene is a genuine failure here — the
    /// whole point of hosting these tests in the app is that one exists.
    private func activeScene() throws -> UIWindowScene {
        try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
    }

    @Test("The window sits above sheets")
    func windowSitsAboveAlerts() throws {
        let host = NotiWindowHost(scene: try activeScene(), center: NotiCenter())
        defer { host.tearDown() }

        #expect(host.window.windowLevel == .alert + 1)
    }

    @Test("The window never becomes key")
    func windowNeverBecomesKey() throws {
        let host = NotiWindowHost(scene: try activeScene(), center: NotiCenter())
        defer { host.tearDown() }

        #expect(host.window.isKeyWindow == false)
    }

    @Test("The window is visible")
    func windowIsVisible() throws {
        let host = NotiWindowHost(scene: try activeScene(), center: NotiCenter())
        defer { host.tearDown() }

        #expect(host.window.isHidden == false)
    }

    @Test("Window and root view backgrounds are clear")
    func backgroundsAreClear() throws {
        let host = NotiWindowHost(scene: try activeScene(), center: NotiCenter())
        defer { host.tearDown() }

        #expect(host.window.backgroundColor == .clear)
        #expect(host.window.rootViewController?.view.backgroundColor == .clear)
    }

    @Test("Tearing down hides the window and releases its content")
    func tearDownHidesWindow() throws {
        let host = NotiWindowHost(scene: try activeScene(), center: NotiCenter())

        host.tearDown()

        #expect(host.window.isHidden == true)
        #expect(host.window.rootViewController == nil)
    }

    @Test("A touch where no toast is falls through to the app")
    func touchOutsideEveryToastFallsThrough() throws {
        let center = NotiCenter()
        let host = NotiWindowHost(scene: try activeScene(), center: center)
        defer { host.tearDown() }
        let bounds = host.window.bounds
        let token = center.present(.bottom, duration: .indefinite) { Text("toast") }
        let toastFrame = CGRect(x: 0, y: bounds.maxY - 80, width: bounds.width, height: 60)
        // Deliberately not `bounds.size`: that is exactly the value the container
        // size must never be compared against (see `NotiFrameStore.containerSize`),
        // and using it here — even just as a stand-in — would coincidentally match
        // whatever the real root view reports if SwiftUI ever laid this window out
        // before the assertion below runs, hiding a bug behind test-order luck.
        let containerSize = CGSize(width: 320, height: 480)
        host.frameStore.setContainerSize(containerSize)
        host.frameStore.set(
            NotiMeasuredFrame(rect: toastFrame, containerSize: containerSize),
            for: token
        )

        #expect(host.window.hitTest(CGPoint(x: bounds.midX, y: bounds.midY), with: nil) == nil)
    }

    @Test("A touch on a toast is absorbed rather than passed through")
    func touchOnAToastIsAbsorbed() throws {
        let center = NotiCenter()
        let host = NotiWindowHost(scene: try activeScene(), center: center)
        defer { host.tearDown() }
        let bounds = host.window.bounds
        let token = center.present(.bottom, duration: .indefinite) { Text("toast") }
        let toastFrame = CGRect(x: 0, y: bounds.maxY - 80, width: bounds.width, height: 60)
        // See the comment in `touchOutsideEveryToastFallsThrough`: an arbitrary size,
        // not the window's own bounds.
        let containerSize = CGSize(width: 320, height: 480)
        host.frameStore.setContainerSize(containerSize)
        host.frameStore.set(
            NotiMeasuredFrame(rect: toastFrame, containerSize: containerSize),
            for: token
        )

        #expect(host.window.hitTest(CGPoint(x: toastFrame.midX, y: toastFrame.midY), with: nil) != nil)
    }

    @Test("With nothing on screen the window absorbs nothing")
    func emptyWindowAbsorbsNothing() throws {
        let host = NotiWindowHost(scene: try activeScene(), center: NotiCenter())
        defer { host.tearDown() }
        let bounds = host.window.bounds

        #expect(host.window.hitTest(CGPoint(x: bounds.midX, y: bounds.midY), with: nil) == nil)
    }

    @Test("Teardown leaves live toasts in the center untouched")
    func tearDownPreservesCenterState() throws {
        let center = NotiCenter()
        let host = NotiWindowHost(scene: try activeScene(), center: center)
        let token = center.present(.top, duration: .indefinite) { Text("live") }

        host.tearDown()

        #expect(center.presentation(for: .top)?.token == token)
    }
}

@Suite("NotiWindow real layout")
@MainActor
struct NotiRealLayoutTests {
    private func activeScene() throws -> UIWindowScene {
        try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    }

    /// End-to-end: a toast laid out by SwiftUI is hit-testable through the window.
    ///
    /// Every other test in this file writes frames into the store by hand, so none of
    /// them exercise the sizes SwiftUI actually reports. That gap hides a real defect:
    /// the root view is laid out inside the safe area, so its size is smaller than the
    /// window's bounds, and checking a frame's container size against `window.bounds`
    /// marks every toast stale forever — leaving toasts permanently non-interactive
    /// while every hand-written test still passes.
    @Test("A toast laid out by SwiftUI absorbs a touch on itself")
    func swiftUILaidOutToastAbsorbsItsOwnTouch() throws {
        let center = NotiCenter()
        let host = NotiWindowHost(scene: try activeScene(), center: center)
        defer { host.tearDown() }

        center.present(.bottom, duration: .indefinite) { Text("toast") }
        host.window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        host.window.layoutIfNeeded()

        let rect = try #require(host.frameStore.liveFrames(for: center.liveTokens).first)
        let inside = CGPoint(x: rect.midX, y: rect.midY)

        #expect(host.window.hitTest(inside, with: nil) != nil)
        // And a point well away from it still belongs to the app.
        #expect(host.window.hitTest(CGPoint(x: rect.midX, y: rect.minY - 200), with: nil) == nil)
    }

    /// The core behavior this whole branch delivers: a window mid-resize hands
    /// touches back to the app rather than absorbing them over geometry that no
    /// longer exists.
    ///
    /// `NotiFrameStoreTests.staleSizeIsNotReported` covers this at the store level in
    /// isolation; this drives it through `PassthroughWindow.hitTest` itself, which is
    /// what actually decides whether a touch reaches the app.
    @Test("A stale container size makes the window pass touches through")
    func staleContainerSizeMakesTheWindowPassTouchesThrough() throws {
        let center = NotiCenter()
        let host = NotiWindowHost(scene: try activeScene(), center: center)
        defer { host.tearDown() }
        let bounds = host.window.bounds
        let token = center.present(.bottom, duration: .indefinite) { Text("toast") }
        let toastFrame = CGRect(x: 0, y: bounds.maxY - 80, width: bounds.width, height: 60)
        let containerSize = CGSize(width: 320, height: 480)

        host.frameStore.setContainerSize(containerSize)
        host.frameStore.set(
            NotiMeasuredFrame(rect: toastFrame, containerSize: containerSize),
            for: token
        )
        let point = CGPoint(x: toastFrame.midX, y: toastFrame.midY)

        #expect(host.window.hitTest(point, with: nil) != nil)

        // The window has resized, but the toast has not re-reported at the new size
        // yet — its stored frame is now for a container size that no longer exists.
        host.frameStore.setContainerSize(CGSize(width: containerSize.width, height: containerSize.height + 100))

        #expect(host.window.hitTest(point, with: nil) == nil)
    }

    @Test("Two hosts sharing one center keep independent frames")
    func twoHostsSharingACenterKeepIndependentFrames() throws {
        // The multi-window case in miniature: one center, two windows. Frames are
        // per-window because a rect in window coordinates means nothing to another
        // window — which is what the old center-owned storage got wrong, and why
        // sharing a center across scenes used to be unsupported.
        let center = NotiCenter()
        let first = NotiWindowHost(scene: try activeScene(), center: center)
        defer { first.tearDown() }
        let second = NotiWindowHost(scene: try activeScene(), center: center)
        defer { second.tearDown() }

        let token = center.present(.bottom, duration: .indefinite) { Text("toast") }
        let firstRect = CGRect(x: 0, y: 700, width: 402, height: 60)
        let secondRect = CGRect(x: 0, y: 300, width: 320, height: 60)
        let size = first.window.bounds.size

        first.frameStore.setContainerSize(size)
        second.frameStore.setContainerSize(size)
        first.frameStore.set(NotiMeasuredFrame(rect: firstRect, containerSize: size), for: token)
        second.frameStore.set(NotiMeasuredFrame(rect: secondRect, containerSize: size), for: token)

        #expect(first.frameStore.liveFrames(for: [token]) == [firstRect])
        #expect(second.frameStore.liveFrames(for: [token]) == [secondRect])

        // And each window hit-tests against its own rect, not the other's.
        #expect(first.window.hitTest(CGPoint(x: 200, y: 730), with: nil) != nil)
        #expect(first.window.hitTest(CGPoint(x: 200, y: 330), with: nil) == nil)
    }
}
