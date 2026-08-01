import Testing
@testable import NotiWindow

@Suite("NotiEdge")
struct NotiEdgeTests {
    @Test("Enumerates exactly the two anchor positions")
    func enumeratesBothAnchors() {
        #expect(NotiEdge.allCases == [.top, .bottom])
    }
}
