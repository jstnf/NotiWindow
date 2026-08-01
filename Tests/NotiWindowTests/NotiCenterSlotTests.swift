import SwiftUI
import Testing
@testable import NotiWindow

@Suite("NotiCenter slots")
@MainActor
struct NotiCenterSlotTests {
    private func makeCenter() -> (NotiCenter, ManualSleeper) {
        let sleeper = ManualSleeper()
        return (NotiCenter(sleeper: sleeper), sleeper)
    }

    @Test("Both slots start empty")
    func slotsStartEmpty() {
        let (center, _) = makeCenter()
        #expect(center.presentation(for: .top) == nil)
        #expect(center.presentation(for: .bottom) == nil)
    }

    @Test("Presenting populates the requested slot")
    func presentPopulatesRequestedSlot() {
        let (center, _) = makeCenter()
        let token = center.present(.top) { Text("hello") }

        #expect(center.presentation(for: .top)?.token == token)
        #expect(center.presentation(for: .bottom) == nil)
    }

    @Test("Presenting defaults to the bottom edge")
    func presentDefaultsToBottom() {
        let (center, _) = makeCenter()
        let token = center.present { Text("hello") }

        #expect(center.presentation(for: .bottom)?.token == token)
    }

    @Test("Presenting on the same edge replaces the current occupant")
    func sameEdgePresentReplaces() {
        let (center, _) = makeCenter()
        let first = center.present(.bottom) { Text("first") }
        let second = center.present(.bottom) { Text("second") }

        #expect(first != second)
        #expect(center.presentation(for: .bottom)?.token == second)
    }

    @Test("Top and bottom slots are independent")
    func slotsAreIndependent() {
        let (center, _) = makeCenter()
        let top = center.present(.top) { Text("top") }
        let bottom = center.present(.bottom) { Text("bottom") }

        #expect(center.presentation(for: .top)?.token == top)
        #expect(center.presentation(for: .bottom)?.token == bottom)
    }

    @Test("Dismissing an edge clears only that edge")
    func dismissEdgeClearsOnlyThatEdge() {
        let (center, _) = makeCenter()
        center.present(.top) { Text("top") }
        let bottom = center.present(.bottom) { Text("bottom") }

        center.dismiss(.top)

        #expect(center.presentation(for: .top) == nil)
        #expect(center.presentation(for: .bottom)?.token == bottom)
    }

    @Test("Dismissing all clears both edges")
    func dismissAllClearsBoth() {
        let (center, _) = makeCenter()
        center.present(.top) { Text("top") }
        center.present(.bottom) { Text("bottom") }

        center.dismissAll()

        #expect(center.presentation(for: .top) == nil)
        #expect(center.presentation(for: .bottom) == nil)
    }

    @Test("Dismissing by token clears the slot it occupies")
    func dismissByTokenClearsItsSlot() {
        let (center, _) = makeCenter()
        let token = center.present(.top) { Text("top") }

        center.dismiss(token)

        #expect(center.presentation(for: .top) == nil)
    }

    @Test("Dismissing a replaced token leaves the replacement alone")
    func dismissingReplacedTokenIsNoOp() {
        let (center, _) = makeCenter()
        let first = center.present(.bottom) { Text("first") }
        let second = center.present(.bottom) { Text("second") }

        center.dismiss(first)

        #expect(center.presentation(for: .bottom)?.token == second)
    }

    @Test("Presentation carries the dismissal flags it was given")
    func presentationCarriesDismissalFlags() {
        let (center, _) = makeCenter()
        center.present(.top, dismissOnTap: false, dismissOnSwipe: false) { Text("x") }

        let presentation = center.presentation(for: .top)
        #expect(presentation?.dismissOnTap == false)
        #expect(presentation?.dismissOnSwipe == false)
    }

    @Test("Dismissal flags default to enabled")
    func dismissalFlagsDefaultToEnabled() {
        let (center, _) = makeCenter()
        center.present(.top) { Text("x") }

        let presentation = center.presentation(for: .top)
        #expect(presentation?.dismissOnTap == true)
        #expect(presentation?.dismissOnSwipe == true)
    }

    @Test("A center with nothing on screen reports no content frames")
    func noContentFramesWhenEmpty() {
        let (center, _) = makeCenter()

        #expect(center.contentFrames.isEmpty)
    }

    @Test("A reported frame is kept for its own edge")
    func reportedFrameIsKeptForItsEdge() {
        let (center, _) = makeCenter()
        let token = center.present(.bottom) { Text("bottom") }
        let frame = CGRect(x: 0, y: 800, width: 402, height: 60)

        center.setContentFrame(frame, forToken: token)

        #expect(center.contentFrames[.bottom] == frame)
        #expect(center.contentFrames[.top] == nil)
    }

    @Test("Dismissing an edge forgets that edge's frame and keeps the other")
    func dismissingAnEdgeForgetsOnlyItsFrame() {
        let (center, _) = makeCenter()
        let topToken = center.present(.top) { Text("top") }
        let bottomToken = center.present(.bottom) { Text("bottom") }
        let bottomFrame = CGRect(x: 0, y: 800, width: 402, height: 60)
        center.setContentFrame(CGRect(x: 0, y: 60, width: 402, height: 60), forToken: topToken)
        center.setContentFrame(bottomFrame, forToken: bottomToken)

        center.dismiss(.top)

        #expect(center.contentFrames[.top] == nil)
        #expect(center.contentFrames[.bottom] == bottomFrame)
    }

    @Test("Dismissing by token forgets that toast's frame")
    func dismissingByTokenForgetsItsFrame() {
        let (center, _) = makeCenter()
        let token = center.present(.bottom) { Text("bottom") }
        center.setContentFrame(CGRect(x: 0, y: 800, width: 402, height: 60), forToken: token)

        center.dismiss(token)

        #expect(center.contentFrames[.bottom] == nil)
    }

    @Test("Dismissing everything forgets every frame")
    func dismissAllForgetsEveryFrame() {
        let (center, _) = makeCenter()
        let topToken = center.present(.top) { Text("top") }
        let bottomToken = center.present(.bottom) { Text("bottom") }
        center.setContentFrame(CGRect(x: 0, y: 60, width: 402, height: 60), forToken: topToken)
        center.setContentFrame(CGRect(x: 0, y: 800, width: 402, height: 60), forToken: bottomToken)

        center.dismissAll()

        #expect(center.contentFrames.isEmpty)
    }

    @Test("A frame reported by a dismissed toast is ignored")
    func frameFromDismissedToastIsIgnored() {
        let (center, _) = makeCenter()
        let token = center.present(.bottom) { Text("bottom") }
        center.dismiss(token)

        // What a toast still animating out reports on its way off screen.
        center.setContentFrame(CGRect(x: 0, y: 840, width: 402, height: 60), forToken: token)

        #expect(center.contentFrames[.bottom] == nil)
    }

    @Test("A frame reported by a replaced toast does not overwrite its replacement's")
    func frameFromReplacedToastIsIgnored() {
        let (center, _) = makeCenter()
        let outgoing = center.present(.bottom) { Text("first") }
        let incoming = center.present(.bottom) { Text("second") }
        let incomingFrame = CGRect(x: 0, y: 800, width: 402, height: 60)
        center.setContentFrame(incomingFrame, forToken: incoming)

        center.setContentFrame(CGRect(x: 0, y: 840, width: 402, height: 60), forToken: outgoing)

        #expect(center.contentFrames[.bottom] == incomingFrame)
    }
}
