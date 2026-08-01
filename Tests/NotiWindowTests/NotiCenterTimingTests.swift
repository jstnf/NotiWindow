@testable import NotiWindow
import SwiftUI
import Testing

@Suite("NotiCenter timing")
@MainActor
struct NotiCenterTimingTests {
    @Test("A toast dismisses itself when its duration elapses")
    func toastDismissesWhenDurationElapses() async {
        let sleeper = ManualSleeper()
        let center = NotiCenter(sleeper: sleeper)

        center.present(.bottom, duration: .seconds(3)) { Text("hello") }
        let expiry = center.expiryTask(for: .bottom)

        await sleeper.awaitSleepRequest()
        #expect(center.presentation(for: .bottom) != nil)
        #expect(sleeper.requestedDurations == [.seconds(3)])

        sleeper.fireNext()
        await expiry?.value

        #expect(center.presentation(for: .bottom) == nil)
    }

    @Test("An indefinite toast schedules no expiry at all")
    func indefiniteToastSchedulesNoExpiry() {
        let sleeper = ManualSleeper()
        let center = NotiCenter(sleeper: sleeper)

        center.present(.top, duration: .indefinite) { Text("syncing") }

        #expect(center.expiryTask(for: .top) == nil)
        #expect(sleeper.requestedDurations.isEmpty)
        #expect(center.presentation(for: .top) != nil)
    }

    @Test("An indefinite toast dismisses only by token")
    func indefiniteToastDismissesByToken() {
        let sleeper = ManualSleeper()
        let center = NotiCenter(sleeper: sleeper)

        let token = center.present(.top, duration: .indefinite) { Text("syncing") }
        #expect(center.presentation(for: .top) != nil)

        center.dismiss(token)
        #expect(center.presentation(for: .top) == nil)
    }

    @Test("A replacing toast is granted a fresh full duration")
    func replacementGetsFreshDuration() async {
        let sleeper = ManualSleeper()
        let center = NotiCenter(sleeper: sleeper)

        center.present(.bottom, duration: .seconds(3)) { Text("first") }
        await sleeper.awaitSleepRequest()

        center.present(.bottom, duration: .seconds(5)) { Text("second") }
        await sleeper.awaitSleepRequest(count: 2)

        #expect(sleeper.requestedDurations == [.seconds(3), .seconds(5)])
    }

    @Test("A replaced toast's expiry does not dismiss its replacement")
    func staleExpiryDoesNotDismissReplacement() async {
        let sleeper = ManualSleeper()
        let center = NotiCenter(sleeper: sleeper)

        center.present(.bottom, duration: .seconds(3)) { Text("first") }
        await sleeper.awaitSleepRequest()
        let staleExpiry = center.expiryTask(for: .bottom)

        let second = center.present(.bottom, duration: .seconds(3)) { Text("second") }
        await sleeper.awaitSleepRequest(count: 2)

        // Fire the FIRST toast's timer. It must find its token gone and do nothing.
        sleeper.fireNext()
        await staleExpiry?.value

        #expect(center.presentation(for: .bottom)?.token == second)
    }

    @Test("Expiry on one edge leaves the other edge alone")
    func expiryIsPerEdge() async {
        let sleeper = ManualSleeper()
        let center = NotiCenter(sleeper: sleeper)

        center.present(.top, duration: .seconds(3)) { Text("top") }
        await sleeper.awaitSleepRequest()
        let topExpiry = center.expiryTask(for: .top)

        let bottom = center.present(.bottom, duration: .seconds(3)) { Text("bottom") }
        await sleeper.awaitSleepRequest(count: 2)

        sleeper.fireNext()
        await topExpiry?.value

        #expect(center.presentation(for: .top) == nil)
        #expect(center.presentation(for: .bottom)?.token == bottom)
    }
}
