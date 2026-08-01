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
}
