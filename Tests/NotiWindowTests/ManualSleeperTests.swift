import Testing
@testable import NotiWindow

@Suite("ManualSleeper")
@MainActor
struct ManualSleeperTests {
    @Test("A sleep stays suspended until fired")
    func sleepSuspendsUntilFired() async {
        let sleeper = ManualSleeper()

        let task = Task { try? await sleeper.sleep(for: .seconds(3)) }

        await sleeper.awaitSleepRequest()
        #expect(sleeper.pendingCount == 1)
        #expect(sleeper.requestedDurations == [.seconds(3)])

        sleeper.fireNext()
        await task.value

        #expect(sleeper.pendingCount == 0)
    }

    @Test("Sleeps fire in the order they were requested")
    func sleepsFireInOrder() async {
        let sleeper = ManualSleeper()

        let first = Task { try? await sleeper.sleep(for: .seconds(1)) }
        await sleeper.awaitSleepRequest()

        let second = Task { try? await sleeper.sleep(for: .seconds(2)) }
        await sleeper.awaitSleepRequest(count: 2)

        #expect(sleeper.requestedDurations == [.seconds(1), .seconds(2)])

        // Awaiting `first` here only returns if `fireNext` resumed the OLDEST sleep.
        // Had it resumed the newer one, this would hang rather than pass.
        sleeper.fireNext()
        await first.value
        #expect(sleeper.pendingCount == 1)

        sleeper.fireNext()
        await second.value
        #expect(sleeper.pendingCount == 0)
    }
}
