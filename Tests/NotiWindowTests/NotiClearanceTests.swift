import CoreGraphics
@testable import NotiWindow
import SwiftUI
import Testing

/// The insets below are real, measured on the simulator rather than invented, so a
/// change in behaviour reads against numbers a device actually produces:
///
/// | Device                    | Chrome           | Content | Toast window |
/// |---------------------------|------------------|---------|--------------|
/// | iPhone 17 Pro, iOS 26.5   | bottom tab bar   | 83      | 34           |
/// | iPad Pro 11-inch, iOS 26.5| top tab bar      | 96      | 32           |
/// | iPhone, inside NavStack   | navigation bar   | 168     | 62           |
@Suite("NotiClearance")
@MainActor
struct NotiClearanceTests {
    // MARK: - Resolution

    @Test("With nothing published, a toast keeps the inset it was presented with")
    func unpublishedEdgeKeepsItsOwnInset() {
        #expect(NotiClearance.resolvedInset(edgeInset: 8, published: 0, windowInset: 34) == 8)
    }

    /// The gap a toast keeps from its own edge is the gap it keeps from the chrome:
    /// 49pt of tab bar (83 measured, less the 34 the window already provides) plus the
    /// 8pt every toast rests at.
    @Test("A toast rests its own inset above the published chrome")
    func toastRestsItsOwnInsetAboveTheChrome() {
        #expect(NotiClearance.resolvedInset(edgeInset: 8, published: 83, windowInset: 34) == 57)
    }

    @Test("An inset the toast window already provides lifts nothing further")
    func insetAlreadyProvidedLiftsNothing() {
        #expect(NotiClearance.resolvedInset(edgeInset: 8, published: 34, windowInset: 34) == 8)
    }

    @Test("A published inset smaller than the window's own never pulls a toast down")
    func smallerPublishedInsetNeverPullsDown() {
        #expect(NotiClearance.resolvedInset(edgeInset: 8, published: 20, windowInset: 34) == 8)
    }

    @Test("A large caller inset is measured from the chrome, not from the window edge")
    func largeCallerInsetIsMeasuredFromTheChrome() {
        #expect(NotiClearance.resolvedInset(edgeInset: 160, published: 83, windowInset: 34) == 209)
    }

    /// The property `max` could not give: every inset a caller passes moves the toast,
    /// including one smaller than the clearance.
    @Test("A caller's inset below the clearance still moves the toast")
    func smallCallerInsetStillMoves() {
        #expect(NotiClearance.resolvedInset(edgeInset: 24, published: 83, windowInset: 34) == 73)
    }

    @Test("A toast asking for no inset of its own rests directly on the chrome")
    func zeroInsetRestsOnTheChrome() {
        #expect(NotiClearance.resolvedInset(edgeInset: 0, published: 83, windowInset: 34) == 49)
    }

    // MARK: - Publishing

    @Test("An edge with no contributions publishes nothing")
    func edgeWithNoContributionsPublishesNothing() {
        let clearance = NotiClearance()

        #expect(clearance.published(for: .bottom) == 0)
        #expect(clearance.published(for: .top) == 0)
    }

    @Test("A contribution publishes the inset it measured")
    func contributionPublishesItsInset() {
        let clearance = NotiClearance()
        clearance.set(insets(bottom: 83), edges: [.top, .bottom], for: NotiClearanceID())

        #expect(clearance.published(for: .bottom) == 83)
    }

    @Test("A top-edge tab bar publishes against the top edge")
    func topChromePublishesAgainstTopEdge() {
        let clearance = NotiClearance()
        clearance.set(insets(top: 96, bottom: 25), edges: [.top, .bottom], for: NotiClearanceID())

        #expect(clearance.published(for: .top) == 96)
        #expect(clearance.published(for: .bottom) == 25)
    }

    @Test("A contribution publishes only the edges it declared")
    func undeclaredEdgesAreNotPublished() {
        let clearance = NotiClearance()
        clearance.set(insets(top: 168, bottom: 83), edges: [.bottom], for: NotiClearanceID())

        #expect(clearance.published(for: .bottom) == 83)
        #expect(clearance.published(for: .top) == 0)
    }

    /// Both tabs are alive for the length of a tab switch, so the larger inset has to
    /// win — otherwise whichever view happens to publish last decides, and a toast
    /// lands on the tab bar for as long as the transition runs.
    @Test("While two contributions are live, the larger one is published")
    func largerOfTwoLiveContributionsWins() {
        let clearance = NotiClearance()
        clearance.set(insets(bottom: 83), edges: [.bottom], for: NotiClearanceID())
        clearance.set(insets(bottom: 34), edges: [.bottom], for: NotiClearanceID())

        #expect(clearance.published(for: .bottom) == 83)
    }

    @Test("Re-measuring a contribution replaces its previous inset rather than adding one")
    func remeasuringReplacesRatherThanAdds() {
        let clearance = NotiClearance()
        let id = NotiClearanceID()
        clearance.set(insets(bottom: 83), edges: [.bottom], for: id)
        clearance.set(insets(bottom: 40), edges: [.bottom], for: id)

        #expect(clearance.published(for: .bottom) == 40)
    }

    @Test("Removing a contribution drops the inset it published")
    func removingDropsItsInset() {
        let clearance = NotiClearance()
        let id = NotiClearanceID()
        clearance.set(insets(bottom: 83), edges: [.bottom], for: id)
        clearance.remove(id)

        #expect(clearance.published(for: .bottom) == 0)
    }

    /// The tab-switch end state: the outgoing tab goes away and the tab that opted
    /// out of clearance is left publishing nothing of its own.
    @Test("Removing one of two contributions leaves the other publishing")
    func removingOneLeavesTheOther() {
        let clearance = NotiClearance()
        let outgoing = NotiClearanceID()
        let staying = NotiClearanceID()
        clearance.set(insets(bottom: 83), edges: [.bottom], for: outgoing)
        clearance.set(insets(bottom: 60), edges: [.bottom], for: staying)

        clearance.remove(outgoing)

        #expect(clearance.published(for: .bottom) == 60)
    }

    @Test("Removing a contribution that was never made is harmless")
    func removingUnknownContributionIsHarmless() {
        let clearance = NotiClearance()
        clearance.set(insets(bottom: 83), edges: [.bottom], for: NotiClearanceID())

        clearance.remove(NotiClearanceID())

        #expect(clearance.published(for: .bottom) == 83)
    }

    // MARK: - Resolution against a store

    @Test("A toast on a cleared edge is lifted clear of the chrome")
    func toastOnClearedEdgeIsLifted() {
        let clearance = NotiClearance()
        clearance.set(insets(bottom: 83), edges: [.bottom], for: NotiClearanceID())

        #expect(clearance.inset(for: .bottom, edgeInset: 8, windowInset: 34) == 57)
    }

    @Test("A toast on an edge nothing published keeps its own inset")
    func toastOnUnclearedEdgeKeepsItsInset() {
        let clearance = NotiClearance()
        clearance.set(insets(bottom: 83), edges: [.bottom], for: NotiClearanceID())

        #expect(clearance.inset(for: .top, edgeInset: 8, windowInset: 62) == 8)
    }

    private func insets(top: CGFloat = 0, bottom: CGFloat = 0) -> EdgeInsets {
        EdgeInsets(top: top, leading: 0, bottom: bottom, trailing: 0)
    }
}
