import CoreGraphics
@testable import NotiWindow
import Testing

@Suite("NotiHitTesting")
struct NotiHitTestingTests {
    private let toast = CGRect(x: 16, y: 700, width: 370, height: 60)

    @Test("A point inside a toast does not pass through")
    func insideAToastDoesNotPassThrough() {
        #expect(NotiHitTesting.passesThrough(point: CGPoint(x: 200, y: 730), contentFrames: [toast]) == false)
    }

    @Test("A point outside every toast passes through")
    func outsideEveryToastPassesThrough() {
        #expect(NotiHitTesting.passesThrough(point: CGPoint(x: 200, y: 400), contentFrames: [toast]))
    }

    @Test("With no toasts on screen every point passes through")
    func noToastsPassEverythingThrough() {
        #expect(NotiHitTesting.passesThrough(point: CGPoint(x: 200, y: 730), contentFrames: []))
    }

    @Test("A point inside the second of two toasts does not pass through")
    func insideTheSecondToastDoesNotPassThrough() {
        let other = CGRect(x: 16, y: 60, width: 370, height: 60)

        #expect(NotiHitTesting.passesThrough(point: CGPoint(x: 200, y: 90), contentFrames: [toast, other]) == false)
    }

    @Test("A point between two toasts passes through")
    func betweenTwoToastsPassesThrough() {
        let other = CGRect(x: 16, y: 60, width: 370, height: 60)

        #expect(NotiHitTesting.passesThrough(point: CGPoint(x: 200, y: 400), contentFrames: [toast, other]))
    }
}
