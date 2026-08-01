@testable import NotiWindow
import SwiftUI
import Testing

@Suite("Presentation values")
struct NotiPresentationTests {
    @Test("Standard duration is three seconds")
    func standardDurationIsThreeSeconds() {
        #expect(NotiDuration.standard == .seconds(3))
    }

    @Test("Each token is distinct")
    func tokensAreDistinct() {
        #expect(NotiToken() != NotiToken())
    }

    @Test("A token equals itself")
    func tokenEqualsItself() {
        let token = NotiToken()
        #expect(token == token)
    }

    @MainActor
    @Test("A presentation retains the values it was built with")
    func presentationRetainsItsValues() {
        let token = NotiToken()
        let presentation = NotiPresentation(
            token: token,
            edge: .top,
            content: AnyView(Text("hello")),
            duration: .indefinite,
            dismissOnTap: false,
            dismissOnSwipe: true
        )

        #expect(presentation.token == token)
        #expect(presentation.edge == .top)
        #expect(presentation.duration == .indefinite)
        #expect(presentation.dismissOnTap == false)
        #expect(presentation.dismissOnSwipe == true)
    }
}
