@testable import NotiWindow
import SwiftUI
import Testing

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

    @Test("A presented token reports itself as on screen")
    func presentedTokenIsPresented() {
        let (center, _) = makeCenter()
        let token = center.present(.top) { Text("hello") }

        #expect(center.isPresented(token))
    }

    @Test("A dismissed token no longer reports itself as on screen")
    func dismissedTokenIsNotPresented() {
        let (center, _) = makeCenter()
        let token = center.present(.top) { Text("hello") }

        center.dismiss(token)

        #expect(!center.isPresented(token))
    }

    @Test("A replaced token stops reporting itself as on screen")
    func replacedTokenIsNotPresented() {
        let (center, _) = makeCenter()
        let outgoing = center.present(.bottom) { Text("first") }
        let incoming = center.present(.bottom) { Text("second") }

        #expect(!center.isPresented(outgoing))
        #expect(center.isPresented(incoming))
    }

    @Test("An edge reports whether anything occupies it")
    func edgeReportsOccupancy() {
        let (center, _) = makeCenter()

        #expect(!center.isPresented(.top))

        center.present(.top) { Text("hello") }

        #expect(center.isPresented(.top))
        #expect(!center.isPresented(.bottom))
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

    @Test("A center with nothing on screen has no live tokens")
    func noLiveTokensWhenEmpty() {
        let (center, _) = makeCenter()

        #expect(center.liveTokens.isEmpty)
    }

    @Test("A presented toast's token is live")
    func presentedTokenIsLive() {
        let (center, _) = makeCenter()
        let token = center.present(.bottom) { Text("bottom") }

        #expect(center.liveTokens == [token])
    }

    @Test("Dismissing an edge drops only that edge's token")
    func dismissingAnEdgeDropsOnlyItsToken() {
        let (center, _) = makeCenter()
        center.present(.top) { Text("top") }
        let bottomToken = center.present(.bottom) { Text("bottom") }

        center.dismiss(.top)

        #expect(center.liveTokens == [bottomToken])
    }

    @Test("Dismissing by token drops that token")
    func dismissingByTokenDropsIt() {
        let (center, _) = makeCenter()
        let token = center.present(.bottom) { Text("bottom") }

        center.dismiss(token)

        #expect(center.liveTokens.isEmpty)
    }

    @Test("Dismissing everything drops every token")
    func dismissAllDropsEveryToken() {
        let (center, _) = makeCenter()
        center.present(.top) { Text("top") }
        center.present(.bottom) { Text("bottom") }

        center.dismissAll()

        #expect(center.liveTokens.isEmpty)
    }

    @Test("Replacing a toast drops the outgoing token and keeps the incoming one")
    func replacementDropsTheOutgoingToken() {
        let (center, _) = makeCenter()
        let outgoing = center.present(.bottom) { Text("first") }
        let incoming = center.present(.bottom) { Text("second") }

        #expect(center.liveTokens == [incoming])
        #expect(!center.liveTokens.contains(outgoing))
    }
}
