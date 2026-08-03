import CoreGraphics
@testable import NotiWindow
import Testing

@Suite("NotiFrameStore")
@MainActor
struct NotiFrameStoreTests {
    private static let container = CGSize(width: 402, height: 874)

    private let rect = CGRect(x: 16, y: 700, width: 370, height: 60)

    private func measured(_ rect: CGRect, in size: CGSize = container) -> NotiMeasuredFrame {
        NotiMeasuredFrame(rect: rect, containerSize: size)
    }

    /// A store already laid out at `container`, which is the ordinary state.
    private func makeStore() -> NotiFrameStore {
        let store = NotiFrameStore()
        store.setContainerSize(Self.container)
        return store
    }

    @Test("A stored frame is reported while its token is live")
    func storedFrameIsReportedWhileLive() {
        let store = makeStore()
        let token = NotiToken()
        store.set(measured(rect), for: token)

        #expect(store.liveFrames(for: [token]) == [rect])
    }

    @Test("A frame whose token is no longer live is not reported")
    func deadTokenIsNotReported() {
        let store = makeStore()
        let token = NotiToken()
        store.set(measured(rect), for: token)

        #expect(store.liveFrames(for: []).isEmpty)
    }

    @Test("A frame whose token is no longer live is pruned rather than kept")
    func deadTokenIsPruned() {
        let store = makeStore()
        let token = NotiToken()
        store.set(measured(rect), for: token)

        _ = store.liveFrames(for: [])

        #expect(store.frames.isEmpty)
    }

    @Test("A frame measured at another container size is not reported")
    func staleSizeIsNotReported() {
        let store = makeStore()
        let token = NotiToken()
        store.set(measured(rect), for: token)

        // What a resize does: the root reports its new size a layout pass before the
        // toasts inside it report where they landed.
        store.setContainerSize(CGSize(width: 320, height: 874))

        #expect(store.liveFrames(for: [token]).isEmpty)
    }

    @Test("An outgoing toast cannot overwrite its replacement's frame")
    func outgoingToastDoesNotOverwriteIncoming() {
        let store = makeStore()
        let outgoing = NotiToken()
        let incoming = NotiToken()
        let incomingRect = CGRect(x: 16, y: 700, width: 370, height: 60)

        store.set(measured(incomingRect), for: incoming)
        // What a toast still animating out reports on its way off screen. It shares
        // an edge with its replacement, so an edge-keyed store would lose the rect.
        store.set(measured(CGRect(x: 16, y: 840, width: 370, height: 60)), for: outgoing)

        #expect(store.liveFrames(for: [incoming]) == [incomingRect])
    }
}
