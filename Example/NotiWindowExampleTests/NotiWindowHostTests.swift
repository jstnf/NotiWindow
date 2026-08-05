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

    @Test("A toast never spills past its container's width")
    func toastFitsItsContainer() throws {
        let center = NotiCenter()
        let host = NotiWindowHost(scene: try activeScene(), center: center)
        defer { host.tearDown() }

        center.present(.bottom, duration: .indefinite) {
            Text("A toast with a reasonably long line of copy in it that has to wrap")
        }
        host.window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        host.window.layoutIfNeeded()

        let rect = try #require(host.frameStore.liveFrames(for: center.liveTokens).first)

        #expect(rect.width <= host.frameStore.containerSize.width)
        #expect(rect.minX >= 0)
    }

    /// Both halves of lifting a toast clear of chrome it would otherwise sit over: it
    /// is hit-tested where it draws, and the space it left behind still belongs to the
    /// app.
    ///
    /// The failure this rules out is silent and total. Positioning a toast from inside
    /// its own content — `.offset` and every other render-only transform — moves what
    /// is drawn without moving the frame the content reports, so the window keeps
    /// absorbing the resting position: every tap on the toast falls through to the app,
    /// and every tap on the chrome underneath is swallowed instead. `edgeInset` is
    /// applied outside that measurement, so the absorbed rect travels with the toast.
    @Test("A toast inset from its edge is hit-tested where it draws")
    func insetToastIsHitTestedWhereItDraws() throws {
        let center = NotiCenter()
        let host = NotiWindowHost(scene: try activeScene(), center: center)
        defer { host.tearDown() }
        let lift: CGFloat = 100

        center.present(.bottom, duration: .indefinite) { Text("toast").padding() }
        settle(host)
        let resting = try #require(host.frameStore.liveFrames(for: center.liveTokens).first)

        center.present(.bottom, duration: .indefinite, edgeInset: 8 + lift) { Text("toast").padding() }
        settle(host)
        let lifted = try #require(host.frameStore.liveFrames(for: center.liveTokens).first)

        // The inset moved the toast, rather than growing it into the space below.
        #expect(abs(lifted.minY - (resting.minY - lift)) < 1)
        #expect(lifted.size == resting.size)

        #expect(host.window.hitTest(CGPoint(x: lifted.midX, y: lifted.midY), with: nil) != nil)
        #expect(host.window.hitTest(CGPoint(x: resting.midX, y: resting.midY), with: nil) == nil)
    }

    /// Lets SwiftUI lay out and report, which takes a run of the main loop rather than
    /// a layout pass alone: the frames arrive from `onGeometryChange`, an action that
    /// runs after the layout it observed.
    private func settle(_ host: NotiWindowHost) {
        host.window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        host.window.layoutIfNeeded()
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
        // Deliberately not `first.window.bounds.size`: the container size must be the
        // SwiftUI root view's size, and the root sits inside the safe area, so the two
        // differ. See the comment in `touchOutsideEveryToastFallsThrough`.
        let size = CGSize(width: 320, height: 480)

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

    @Test("A center with no window attached reports none")
    func centerStartsUnattached() {
        #expect(NotiCenter().attachedWindowCount == 0)
    }

    @Test("A host attaches on init and detaches on teardown")
    func hostAttachesAndDetaches() throws {
        let center = NotiCenter()
        let host = NotiWindowHost(scene: try activeScene(), center: center)

        #expect(center.attachedWindowCount == 1)

        host.tearDown()

        #expect(center.attachedWindowCount == 0)
    }

    @Test("Two hosts sharing a center report two attachments")
    func twoHostsReportTwoAttachments() throws {
        let center = NotiCenter()
        let first = NotiWindowHost(scene: try activeScene(), center: center)
        defer { first.tearDown() }
        let second = NotiWindowHost(scene: try activeScene(), center: center)
        defer { second.tearDown() }

        #expect(center.attachedWindowCount == 2)
    }
}

@Suite("NotiWindow scene resizing")
@MainActor
struct NotiWindowResizeTests {
    private func activeScene() throws -> UIWindowScene {
        try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    }

    /// A window created for a scene keeps the frame it was handed. UIKit resizes the
    /// scene's own window, not extra ones an app installs alongside it, so without an
    /// explicit sync the toast window stays whatever size it was born at.
    @Test("The window re-syncs its frame to the scene it belongs to")
    func windowSyncsItsFrameToTheScene() throws {
        let scene = try activeScene()
        let host = NotiWindowHost(scene: scene, center: NotiCenter())
        defer { host.tearDown() }

        // What a scene resize leaves behind: the scene is one size, the window another.
        host.window.frame = CGRect(x: 0, y: 0, width: 200, height: 200)

        host.syncFrameToScene()

        #expect(host.window.frame == scene.coordinateSpace.bounds)
    }

    /// The symptom the sync exists to prevent: a bottom toast anchored to an edge the
    /// window no longer has, which puts it partway up the screen instead of at the
    /// bottom of it.
    @Test("A bottom toast re-anchors to the window's bottom after a resize")
    func bottomToastFollowsTheWindowsBottomEdge() throws {
        let scene = try activeScene()
        let center = NotiCenter()
        let host = NotiWindowHost(scene: scene, center: center)
        defer { host.tearDown() }

        center.present(.bottom, duration: .indefinite) { Text("toast") }
        host.window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        host.window.layoutIfNeeded()

        let tallWindowRect = try #require(host.frameStore.liveFrames(for: center.liveTokens).first)

        // Shrink the window as a scene resize would, then let the sync correct it back.
        let shortened = host.window.frame.height - 300
        host.window.frame = CGRect(
            x: host.window.frame.minX,
            y: host.window.frame.minY,
            width: host.window.frame.width,
            height: shortened
        )
        host.window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        let shortWindowRect = try #require(host.frameStore.liveFrames(for: center.liveTokens).first)
        // The toast tracked the shorter window rather than staying where it was.
        #expect(shortWindowRect.minY < tallWindowRect.minY - 200)

        host.syncFrameToScene()
        host.window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        let restored = try #require(host.frameStore.liveFrames(for: center.liveTokens).first)
        // And back to the scene's own bottom edge once the frame is resynced.
        #expect(abs(restored.minY - tallWindowRect.minY) < 1)
    }
}
