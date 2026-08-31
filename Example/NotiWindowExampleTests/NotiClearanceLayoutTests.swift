@testable import NotiWindow
import SwiftUI
import Testing
import UIKit

/// Clearance, driven through a real SwiftUI layout in a real window.
///
/// App-hosted for the same reason as `NotiWindowHostTests`: `NotiWindowHost` needs a
/// live `UIWindowScene`, which the package's own bare `xctest` bundle does not have.
@Suite("NotiClearance layout")
@MainActor
struct NotiClearanceLayoutTests {
    private func activeScene() throws -> UIWindowScene {
        try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    }

    /// The whole clearance chain, end to end: a published inset reaches the root view,
    /// has the window's own safe area taken back off it, and moves the frame the
    /// window absorbs touches against.
    ///
    /// Written against a real layout because the subtraction is the part that can only
    /// be wrong here. Both numbers come from SwiftUI — the app's measurement of its own
    /// chrome, and this window's measurement of its own safe area — and a unit test
    /// supplying both can only prove the arithmetic, never that the second one is
    /// actually the inset this window was laid out with.
    @Test("A published clearance lifts a toast by the part the window does not already provide")
    func publishedClearanceLiftsToast() throws {
        let center = NotiCenter()
        let clearance = NotiClearance()
        let host = NotiWindowHost(scene: try activeScene(), center: center, clearance: clearance)
        defer { host.tearDown() }
        // An iPhone tab bar, as measured on the simulator: the bar itself plus the home
        // indicator this window is already clear of.
        let published: CGFloat = 83

        center.present(.bottom, duration: .indefinite) { Text("toast").padding() }
        settle(host)
        let resting = try #require(host.frameStore.liveFrames(for: center.liveTokens).first)

        clearance.set(
            EdgeInsets(top: 0, leading: 0, bottom: published, trailing: 0),
            edges: [.bottom],
            for: NotiClearanceID()
        )
        settle(host)
        let lifted = try #require(host.frameStore.liveFrames(for: center.liveTokens).first)

        // Only the chrome above the window's own safe area counts. The toast keeps the
        // 8pt inset it already had, so that part cancels out of the movement.
        let expectedLift = max(0, published - host.window.safeAreaInsets.bottom)

        #expect(expectedLift > 0, "the test host has no bottom inset to lift clear of")
        #expect(abs(lifted.minY - (resting.minY - expectedLift)) < 1)
        #expect(lifted.size == resting.size)

        // And it is still hit-tested where it now draws, not where it used to.
        #expect(host.window.hitTest(CGPoint(x: lifted.midX, y: lifted.midY), with: nil) != nil)
    }

    @Test("Clearance published for one edge leaves the other edge's toast alone")
    func clearanceOnOneEdgeLeavesTheOtherAlone() throws {
        let center = NotiCenter()
        let clearance = NotiClearance()
        let host = NotiWindowHost(scene: try activeScene(), center: center, clearance: clearance)
        defer { host.tearDown() }

        let token = center.present(.top, duration: .indefinite) { Text("toast").padding() }
        settle(host)
        let resting = try #require(host.frameStore.liveFrames(for: [token]).first)

        clearance.set(
            EdgeInsets(top: 0, leading: 0, bottom: 83, trailing: 0),
            edges: [.bottom],
            for: NotiClearanceID()
        )
        settle(host)
        let after = try #require(host.frameStore.liveFrames(for: [token]).first)

        #expect(after == resting)
    }

    /// Lets SwiftUI lay out and report, which takes a run of the main loop rather than
    /// a layout pass alone: the frames arrive from `onGeometryChange`, an action that
    /// runs after the layout it observed.
    private func settle(_ host: NotiWindowHost) {
        host.window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        host.window.layoutIfNeeded()
    }
}
