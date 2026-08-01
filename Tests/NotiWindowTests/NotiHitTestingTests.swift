import UIKit
import Testing
@testable import NotiWindow

@Suite("NotiHitTesting")
@MainActor
struct NotiHitTestingTests {
    @Test("A miss passes through")
    func missPassesThrough() {
        let root = UIView()
        #expect(NotiHitTesting.passesThrough(hitView: nil, rootView: root))
    }

    @Test("Hitting the transparent backdrop passes through")
    func backdropPassesThrough() {
        let root = UIView()
        #expect(NotiHitTesting.passesThrough(hitView: root, rootView: root))
    }

    @Test("Hitting toast content does not pass through")
    func contentDoesNotPassThrough() {
        let root = UIView()
        let toast = UIView()
        root.addSubview(toast)

        #expect(NotiHitTesting.passesThrough(hitView: toast, rootView: root) == false)
    }

    @Test("A hit with no root view passes through rather than swallowing the touch")
    func hitWithoutRootPassesThrough() {
        let toast = UIView()
        #expect(NotiHitTesting.passesThrough(hitView: toast, rootView: nil))
    }

    @Test("A miss with no root view passes through")
    func missWithoutRootPassesThrough() {
        #expect(NotiHitTesting.passesThrough(hitView: nil, rootView: nil))
    }
}
