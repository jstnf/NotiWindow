@testable import NotiWindow
import Testing

@Suite("NotiEdge")
struct NotiEdgeTests {
    @Test("Enumerates exactly the two anchor positions")
    func enumeratesBothAnchors() {
        #expect(NotiEdge.allCases == [.top, .bottom])
    }
}
